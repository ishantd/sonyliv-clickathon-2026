"use client";

import { useMemo } from "react";
import useSWR from "swr";
import { API_BASE, fetcher } from "./api";

/**
 * The analytics surface, typed once.
 *
 * Every shape here is what the Go service actually returns — see
 * ingest/internal/mock/analytics.go. Nothing in this file restates a list the
 * server owns: the datasets, the filterable dimensions, the panel catalogue and
 * the materialised rollup table are all fetched, because a second copy in the
 * browser is a copy that drifts and the one that drifts is the one you cannot
 * see from the server.
 */

export type Window = {
  key: string;
  label: string;
  from: string;
  to: string;
  rel_minutes?: number;
};

export type Database = {
  name: string;
  label: string;
  note: string;
  writable: boolean;
  windows: Window[];
};

export type Dimension = {
  key: string;
  label: string;
  column: string;
  grouping: string;
  /** The raw event column this filter ultimately comes from. */
  source: string;
};

export type PanelInfo = {
  name: string;
  title: string;
  unit: string;
  note: string;
  breakdown?: string;
};

export type Meta = {
  panels: PanelInfo[];
  databases: Database[];
  default: string;
  dimensions: Dimension[];
  /** Dimension-set (sorted, "|"-joined) -> the grouping that answers it exactly. */
  rollups: Record<string, string>;
};

export type QueryStats = {
  elapsed_ms: number;
  server_ms: number;
  rows_read: number;
  bytes_read: number;
  result_rows: number;
  grouping: string;
  exact_peak: boolean;
  mask_reason: string;
  filter: string;
};

export type Mask = { grouping: string; exact_peak: boolean; why: string };

export type PanelResponse = {
  panel: string;
  title: string;
  unit: string;
  note: string;
  database: string;
  from: string;
  to: string;
  columns: string[];
  rows: unknown[][];
  sql: string;
  params: Record<string, string>;
  mask: Mask;
  stats: QueryStats;
  error?: string;
};

export type DimensionValues = {
  database: string;
  values: Record<string, string[]>;
  capped_at: number;
  error?: string;
};

/** The reader's selection: dimension key -> pinned value. */
export type Filter = Record<string, string>;

/**
 * Resolves a window to the `from`/`to` the API takes.
 *
 * Relative windows are resolved in the browser rather than on the server so they
 * follow the viewer's clock, which is what makes "last hour" mean the same thing
 * on a laptop in a different timezone from the box.
 */
export function windowParams(w: Window): { from: string; to: string } {
  if (w.rel_minutes) {
    const to = new Date();
    const from = new Date(to.getTime() - w.rel_minutes * 60_000);
    const fmt = (d: Date) => d.toISOString().slice(0, 19).replace("T", " ");
    return { from: fmt(from), to: fmt(to) };
  }
  return { from: w.from, to: w.to };
}

/**
 * Builds a panel's query string.
 *
 * Filter keys are sorted so an identical selection always produces an identical
 * URL — which is what lets SWR dedupe six panels' worth of requests and keep a
 * previous render on screen while the next one loads.
 */
export function panelQuery(opts: {
  db: string;
  from: string;
  to: string;
  cap: number;
  filter: Filter;
}): string {
  const qs = new URLSearchParams({
    db: opts.db,
    from: opts.from,
    to: opts.to,
    cap: String(opts.cap),
  });
  for (const k of Object.keys(opts.filter).sort()) {
    const v = opts.filter[k];
    if (v) qs.set(k, v);
  }
  return qs.toString();
}

/**
 * The rollup a selection resolves to, computed in the browser for the CONTROL
 * that has not been submitted yet.
 *
 * The server is still the authority — every rendered panel reports the grouping
 * it actually read. This exists only so the filter bar can warn before a request
 * is made, which is the difference between "your peak disappeared" and "this
 * combination cannot carry an exact peak".
 */
export function resolveRollup(
  rollups: Record<string, string> | undefined,
  keys: string[],
): { grouping: string; exact: boolean } {
  const key = [...new Set(keys)].sort().join("|");
  const g = rollups?.[key];
  if (g) return { grouping: g, exact: true };
  return { grouping: "all dimensions", exact: false };
}

/** One panel's fetch, with its loading / query-error / transport-error states kept apart. */
export function usePanel(
  name: string,
  query: string | null,
  opts: { refreshInterval?: number } = {},
) {
  // A null key HOLDS the request until the dataset and window are known. Fetching
  // without them would render the server's defaults and then swap under the
  // reader — briefly showing one dataset's numbers under another's label.
  const key = query ? `/api/analytics/${name}?${query}` : null;
  const { data, error, isLoading, isValidating } = useSWR<PanelResponse>(
    key,
    fetcher,
    {
      keepPreviousData: true,
      revalidateOnFocus: false,
      refreshInterval: opts.refreshInterval,
    },
  );
  return {
    data,
    // Two failure modes, kept apart: the request failed (no data at all) versus
    // the query failed (data with an error field). The second still carries the
    // panel's title, window and statement, so the card can say which panel broke
    // and show the SQL that broke it.
    transport: error ? String(error) : undefined,
    query: data?.error,
    isLoading,
    isValidating,
  };
}

/** The filter values available in the current dataset and window. */
export function useDimensionValues(query: string | null) {
  const { data, error } = useSWR<DimensionValues>(
    query ? `/api/analytics/dimensions?${query}` : null,
    fetcher,
    { revalidateOnFocus: false, keepPreviousData: true },
  );
  return { values: data?.values, error: error ? String(error) : data?.error };
}

/** Column index by name, so a reordered SELECT cannot silently mis-plot a series. */
export function col(r: PanelResponse, name: string): number {
  const i = r.columns.indexOf(name);
  if (i < 0) throw new Error(`panel ${r.panel} has no column ${name}`);
  return i;
}

export const asNum = (v: unknown): number | null =>
  v == null ? null : typeof v === "number" ? v : Number(v);
export const asStr = (v: unknown): string => (v == null ? "" : String(v));

/**
 * A runnable copy of a panel's statement.
 *
 * The served SQL is full of {name:Type} placeholders, which is correct — that is
 * how the values are bound — but it means the text on screen cannot be pasted
 * into a client and run. Substituting the reported parameters produces something
 * that can be, which is the difference between showing a query and showing the
 * query that ran.
 *
 * Values are single-quoted with quotes doubled. They came from the server's own
 * echo of what it bound, so this is presentation rather than a trust boundary —
 * the boundary is that the real statement never had these substituted into it.
 */
export function inlineParams(
  sql: string,
  params: Record<string, string>,
): string {
  return sql.replace(/\{(\w+):(\w+(?:\(\d+\))?)\}/g, (whole, name: string, type: string) => {
    const v = params[name];
    if (v == null) return whole;
    return /Int|Float|Decimal/.test(type) ? v : `'${v.replace(/'/g, "''")}'`;
  });
}

/** Absolute URL of a panel request, so the API call itself can be shown and shared. */
export function panelUrl(name: string, query: string): string {
  const base = API_BASE || (typeof window !== "undefined" ? window.location.origin : "");
  return `${base}/api/analytics/${name}?${query}`;
}

/** Memoised active-filter list, in the dimension order the server declared. */
export function useActiveFilters(dimensions: Dimension[] | undefined, filter: Filter) {
  return useMemo(
    () =>
      (dimensions ?? [])
        .filter((d) => filter[d.key])
        .map((d) => ({ dimension: d, value: filter[d.key] })),
    [dimensions, filter],
  );
}
