"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";
import { ConcurrencyLine, RankedBar } from "@/components/Charts";
import { ErrorNote, Panel, Stat, StatGrid } from "@/components/ui";
import { fetcher } from "@/lib/api";

/**
 * The ClickStack dashboards, served from this box.
 *
 * WHY REPRODUCE THEM. ClickStack is queries over ClickHouse, and this app already
 * talks to the same ClickHouse through the Go service. Linking out costs a login,
 * and managed ClickStack has no stable deep link — the documented route is
 * console -> service -> ClickStack -> Launch, which redirects through an
 * authenticated handoff. A demo tab that lands on a login page is not a demo tab.
 *
 * Every panel here reads the same serving-layer views the ClickStack tiles read,
 * so a number on this page and a number on that one come from one definition.
 * Cross-checked against the sibling pipeline's own published figures: this page
 * reports ANDROID_PHONE peaking at 1,461 at 10:55, which is what
 * docs/TABLE-CONTRACT.md section 5.6 reports from an independent query path.
 */

type PanelResponse = {
  panel: string;
  title: string;
  unit: string;
  database: string;
  from: string;
  to: string;
  columns: string[];
  rows: unknown[][];
  error?: string;
};

type Window = {
  key: string;
  label: string;
  from: string;
  to: string;
  rel_minutes?: number;
};

type Database = {
  name: string;
  label: string;
  note: string;
  windows: Window[];
};

type Meta = { databases: Database[]; default: string };

/*
 * Databases and their windows come from the server, not from here.
 *
 * The list is hardcoded — in Go, in analytics.go, where it is also the security
 * boundary: the chosen name is interpolated into panel SQL as a schema identifier,
 * which cannot be a bound parameter, so only an allowlist makes it safe. Restating
 * the options in the browser would be a second copy of a security-relevant list,
 * and the copy that drifts is the one nobody can see from the server.
 *
 * Windows are per-database for a reason worth keeping: they are not cosmetic. The
 * extract's interesting hour is 26 July; the unseen day's is 31 July. Carrying one
 * shared window list across a database switch would leave the chart empty and read
 * as broken, when in fact the data is simply somewhere else on the timeline.
 */
function windowParams(w: Window): string {
  if (w.rel_minutes) {
    const to = new Date();
    const from = new Date(to.getTime() - w.rel_minutes * 60_000);
    const fmt = (d: Date) => d.toISOString().slice(0, 19).replace("T", " ");
    return `from=${encodeURIComponent(fmt(from))}&to=${encodeURIComponent(fmt(to))}`;
  }
  return `from=${encodeURIComponent(w.from)}&to=${encodeURIComponent(w.to)}`;
}

/** Column index by name, so a reordered SELECT cannot silently mis-plot a series. */
function col(r: PanelResponse, name: string): number {
  const i = r.columns.indexOf(name);
  if (i < 0) throw new Error(`panel ${r.panel} has no column ${name}`);
  return i;
}
const num = (v: unknown) => (typeof v === "number" ? v : Number(v) || 0);
const str = (v: unknown) => (v == null ? "" : String(v));

/** One panel's fetch + its loading/error/empty states, so no chart renders a lie. */
function usePanel(name: string, db: string | null, params: string | null, cap = 500) {
  // Null key holds the request until the database and window are known. Fetching
  // without a db would render the server's default and then swap under the reader
  // — briefly showing one dataset's numbers under another's label.
  const key = db && params ? `/api/analytics/${name}?db=${db}&${params}&cap=${cap}` : null;
  const { data, error, isLoading } = useSWR<PanelResponse>(key, fetcher, {
    keepPreviousData: true,
    revalidateOnFocus: false,
  });
  return {
    data,
    // Two failure modes, kept apart: the request failed (no data at all) versus the
    // query failed (data with an error field). The second still carries the panel's
    // title and window, so the card can say which panel broke.
    transport: error ? String(error) : undefined,
    query: data?.error,
    isLoading,
  };
}

function PanelCard({
  title,
  children,
  transport,
  query,
  isLoading,
  empty,
  note,
}: {
  title: string;
  children: React.ReactNode;
  transport?: string;
  query?: string;
  isLoading: boolean;
  empty: boolean;
  note?: string;
}) {
  return (
    <Panel title={title}>
      {transport ? (
        <ErrorNote error={transport} />
      ) : query ? (
        <ErrorNote error={query} />
      ) : isLoading ? (
        <p className="py-8 text-center text-[0.8125rem] text-ink-3">loading…</p>
      ) : empty ? (
        // Not an error, and said so. On the serving layer an empty window usually
        // means the minute layer has not published it yet, which is a different
        // fact from "no viewers" and the two must not look alike.
        <p className="py-8 text-center text-[0.8125rem] text-ink-3">
          No published rows in this window.
        </p>
      ) : (
        children
      )}
      {note && !transport && !query ? (
        <p className="mt-2 text-[0.6875rem] leading-relaxed text-ink-3">{note}</p>
      ) : null}
    </Panel>
  );
}

export default function AnalyticsPage() {
  const { data: meta, error: metaError } = useSWR<Meta>("/api/analytics", fetcher, {
    revalidateOnFocus: false,
  });

  // Both selections are stored as KEYS, not objects, and resolved against the
  // server's list on every render. Storing the object would pin a stale window
  // across a database switch — the one bug this selector must not have.
  const [dbName, setDbName] = useState<string | null>(null);
  const [winKey, setWinKey] = useState<string | null>(null);

  const db =
    meta?.databases.find((d) => d.name === dbName) ??
    meta?.databases.find((d) => d.name === meta.default) ??
    meta?.databases[0] ??
    null;

  // Falls back to the database's FIRST window rather than to a shared default, so
  // switching to a dataset whose data lives elsewhere on the timeline still lands
  // on something populated.
  const win = db?.windows.find((w) => w.key === winKey) ?? db?.windows[0] ?? null;

  // Recomputed only when the window changes, so a relative window does not produce
  // a new URL on every render and re-fetch forever.
  const params = useMemo(() => (win ? windowParams(win) : null), [win]);
  const dbKey = db?.name ?? null;

  const curve = usePanel("concurrency", dbKey, params, 5000);
  const platform = usePanel("platform_peak", dbKey, params, 12);
  const vtype = usePanel("video_type_hours", dbKey, params, 8);
  const category = usePanel("category_hours", dbKey, params, 12);
  const titles = usePanel("top_titles", dbKey, params, 15);
  const fresh = usePanel("freshness", dbKey, params, 8);

  const curveData = useMemo(() => {
    const d = curve.data;
    if (!d || d.error || !d.rows.length) return null;
    const iM = col(d, "minute"), iP = col(d, "peak"), iA = col(d, "average");
    return {
      // Time only: the date is in the window selector and repeating it on every
      // tick leaves no room for the ticks themselves.
      labels: d.rows.map((r) => str(r[iM]).slice(11, 16)),
      peak: d.rows.map((r) => num(r[iP])),
      average: d.rows.map((r) => num(r[iA])),
    };
  }, [curve.data]);

  const headline = useMemo(() => {
    if (!curveData) return null;
    const peak = Math.max(...curveData.peak);
    // Mean of the per-minute time-weighted averages, which for equal-length
    // minutes IS the window's time-weighted average. Not a mean of peaks, which
    // would be meaningless.
    const avg = curveData.average.reduce((a, b) => a + b, 0) / curveData.average.length;
    return { peak, avg, minutes: curveData.peak.length };
  }, [curveData]);

  return (
    <main className="mx-auto w-full max-w-[80rem] px-5 py-6">
      <header className="mb-5">
        <h1 className="text-[1.0625rem] text-ink">Concurrency analytics</h1>
        <p className="mt-1 max-w-[62rem] text-[0.8125rem] leading-relaxed text-ink-2">
          The ClickStack dashboards, served from this box against the same
          serving-layer views. Peaks are read from the mask that carries the
          dimension — never summed across slices, because two platforms peak at
          different instants.
        </p>
      </header>

      <ErrorNote error={metaError} />

      {meta && db ? (
        <div className="mb-5 flex flex-col gap-3">
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-[0.6875rem] tracking-wide text-ink-3 uppercase">
              Dataset
            </span>
            {meta.databases.map((d) => (
              <button
                key={d.name}
                onClick={() => {
                  setDbName(d.name);
                  // Clearing the window is the point: the next render resolves it
                  // against the NEW database's list and lands on its first entry.
                  setWinKey(null);
                }}
                aria-current={d.name === db.name ? "true" : undefined}
                title={d.note}
                className={`rounded border px-2.5 py-1 text-[0.8125rem] transition-colors ${
                  d.name === db.name
                    ? "border-accent-dim bg-accent-wash text-accent"
                    : "border-line text-ink-2 hover:text-ink"
                }`}
              >
                {d.label}
                <span className="ml-1.5 font-mono text-[0.6875rem] text-ink-3">
                  {d.name}
                </span>
              </button>
            ))}
          </div>

          <p className="max-w-[62rem] text-[0.75rem] leading-relaxed text-ink-3">
            {db.note}
          </p>

          <div className="flex flex-wrap items-center gap-2">
            <span className="text-[0.6875rem] tracking-wide text-ink-3 uppercase">
              Window
            </span>
            {db.windows.map((w) => (
              <button
                key={w.key}
                onClick={() => setWinKey(w.key)}
                aria-current={w.key === win?.key ? "true" : undefined}
                className={`rounded border px-2.5 py-1 text-[0.8125rem] transition-colors ${
                  w.key === win?.key
                    ? "border-accent-dim bg-accent-wash text-accent"
                    : "border-line text-ink-2 hover:text-ink"
                }`}
              >
                {w.label}
              </button>
            ))}
          </div>
        </div>
      ) : null}

      {headline ? (
        <StatGrid>
          {/* Sourced from the RESPONSE, not from the selector. If the two ever
              disagree the numbers on screen came from somewhere the reader did not
              choose, and a chart that cannot be attributed is worse than no chart. */}
          <Stat
            label="Dataset"
            value={<span className="font-mono text-[0.8125rem]">{curve.data?.database ?? "—"}</span>}
            tone="muted"
          />
          <Stat label="Exact peak concurrency" value={headline.peak.toLocaleString()} tone="live" />
          <Stat
            label="Time-weighted average"
            value={headline.avg.toFixed(3)}
          />
          <Stat label="Minutes published" value={headline.minutes.toLocaleString()} tone="muted" />
        </StatGrid>
      ) : null}

      <div className="mt-5 grid gap-4">
        <PanelCard
          title="Concurrency over time"
          transport={curve.transport}
          query={curve.query}
          isLoading={curve.isLoading}
          empty={!curveData}
          note="Peak is the exact maximum inside each minute; the dashed series is the time-weighted average. They differ by roughly 2.7× over the hot hour, which is why both are drawn."
        >
          {curveData ? (
            <ConcurrencyLine
              labels={curveData.labels}
              peak={curveData.peak}
              average={curveData.average}
            />
          ) : null}
        </PanelCard>

        <div className="grid gap-4 lg:grid-cols-2">
          <PanelCard
            title="Exact peak by platform"
            transport={platform.transport}
            query={platform.query}
            isLoading={platform.isLoading}
            empty={!platform.data?.rows.length}
            note="Read from the platform-grain mask, so each bar is exact. These bars must not be added: the platforms peak at different instants, and their sum exceeds the true total."
          >
            {platform.data?.rows.length ? (
              <RankedBar
                label="peak"
                labels={platform.data.rows.map((r) => str(r[col(platform.data!, "platform")]))}
                values={platform.data.rows.map((r) => num(r[col(platform.data!, "peak")]))}
              />
            ) : null}
          </PanelCard>

          <PanelCard
            title="Viewer-hours by content type"
            transport={vtype.transport}
            query={vtype.query}
            isLoading={vtype.isLoading}
            empty={!vtype.data?.rows.length}
            note="'unknown' is a real catalogue value carried by 1,089 titles, not a missing one, so it is charted rather than dropped."
          >
            {vtype.data?.rows.length ? (
              <RankedBar
                cool
                label="viewer-hours"
                labels={vtype.data.rows.map((r) => str(r[col(vtype.data!, "video_type")]))}
                values={vtype.data.rows.map((r) => num(r[col(vtype.data!, "viewer_hours")]))}
              />
            ) : null}
          </PanelCard>
        </div>

        <PanelCard
          title="Viewer-hours by category"
          transport={category.transport}
          query={category.query}
          isLoading={category.isLoading}
          empty={!category.data?.rows.length}
          note="Viewer-hours is sum(active_ms), which is additive across every dimension — so unlike the peak panels, these bars do total correctly."
        >
          {category.data?.rows.length ? (
            <RankedBar
              cool
              label="viewer-hours"
              labels={category.data.rows.map((r) => str(r[col(category.data!, "category")]))}
              values={category.data.rows.map((r) => num(r[col(category.data!, "viewer_hours")]))}
              height={300}
            />
          ) : null}
        </PanelCard>

        <PanelCard
          title="Top titles by viewer-hours"
          transport={titles.transport}
          query={titles.query}
          isLoading={titles.isLoading}
          empty={!titles.data?.rows.length}
          note="Ranked by viewer-hours, not peak: ranking by peak rewards a brief spike over a long watch, and peaks cannot be totalled."
        >
          {titles.data?.rows.length ? (
            <div className="overflow-x-auto">
              <table className="w-full text-[0.8125rem]">
                <thead>
                  <tr className="border-b border-line text-left text-ink-3">
                    {titles.data.columns.map((c) => (
                      <th key={c} className="px-2 py-1.5 font-normal whitespace-nowrap">
                        {c.replace(/_/g, " ")}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {titles.data.rows.map((r, i) => (
                    <tr key={i} className="border-b border-line-soft last:border-0">
                      {r.map((v, j) => (
                        <td
                          key={j}
                          className={`px-2 py-1.5 whitespace-nowrap ${
                            typeof v === "number" ? "font-mono text-ink" : "text-ink-2"
                          }`}
                        >
                          {typeof v === "number" ? v.toLocaleString() : str(v)}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : null}
        </PanelCard>

        <PanelCard
          title="Serving layer freshness"
          transport={fresh.transport}
          query={fresh.query}
          isLoading={fresh.isLoading}
          empty={!fresh.data?.rows.length}
          note="Read this before treating any recent dip as a drop. The minute layer publishes on a deliberate lag, so unpublished minutes are absent rather than zero — a stalled pipeline and an outage have the same shape on a chart."
        >
          {fresh.data?.rows.length ? (
            <StatGrid>
              {fresh.data.rows.map((r, i) => {
                const lag = num(r[col(fresh.data!, "data_lag_s")]);
                return (
                  <Stat
                    key={i}
                    label={`${str(r[col(fresh.data!, "layer")])} lag`}
                    value={`${lag.toLocaleString()}s`}
                    // 900s is the same threshold the drop-detector staleness alert
                    // fires on, so the page and the alert agree on "stale".
                    tone={lag > 900 ? "bad" : "plain"}
                  />
                );
              })}
            </StatGrid>
          ) : null}
        </PanelCard>
      </div>
    </main>
  );
}
