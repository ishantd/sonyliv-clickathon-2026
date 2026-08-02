"use client";

import type { ReactNode } from "react";
import { QueryStats } from "./QueryStats";
import { SqlPeek } from "./SqlPeek";
import { ErrorNote } from "./ui";
import type { PanelResponse } from "@/lib/analytics";
import { panelUrl } from "@/lib/analytics";

/**
 * One panel: its title, its result, what the query cost, and the query.
 *
 * WHY EVERY PANEL IS THE SAME OBJECT. Six charts that each decide for themselves
 * how to say "loading", "nothing here" and "that failed" is six chances for two
 * of them to disagree, and a reader learns the interface once rather than once
 * per card. The three states below are kept genuinely distinct because on a
 * serving layer they mean genuinely different things: a transport failure is the
 * service being unreachable, a query error is an object being missing, and an
 * empty window is usually the minute tier not having published yet — which is
 * not an error at all and must not be dressed as one.
 */

/**
 * A skeleton, not a spinner.
 *
 * A spinner in the middle of a panel destroys the layout on every refetch and
 * tells the reader nothing about what is arriving. These bars hold the panel's
 * height so nothing below it moves, which matters when six panels resolve at
 * different times. The pulse is suppressed under prefers-reduced-motion by the
 * global rule in globals.css.
 */
function Skeleton({ height }: { height: number }) {
  return (
    <div
      className="flex animate-pulse flex-col justify-end gap-2 py-2"
      style={{ height }}
      aria-hidden
    >
      {[62, 84, 48, 96, 70, 100].map((w, i) => (
        <div
          key={i}
          className="rounded-sm bg-raised"
          style={{ width: `${w}%`, height: 8 }}
        />
      ))}
    </div>
  );
}

export function PanelFrame({
  title,
  panel,
  query,
  children,
  empty,
  isLoading,
  isValidating,
  transport,
  queryError,
  aside,
  note,
  height = 280,
  className = "",
}: {
  title: string;
  /** The server's response, which carries the stats, the note and the SQL. */
  panel?: PanelResponse;
  /** The query string this panel was fetched with, so the API URL can be shown. */
  query?: string | null;
  children: ReactNode;
  empty: boolean;
  isLoading: boolean;
  isValidating?: boolean;
  transport?: string;
  queryError?: string;
  /** Rendered on the title row, right-aligned: a readout, a control, a count. */
  aside?: ReactNode;
  /** Overrides the server's own note. Rarely wanted — the server's is the one
      that cannot drift from the query. */
  note?: ReactNode;
  height?: number;
  className?: string;
}) {
  const failed = transport ?? queryError;

  return (
    <section
      // min-w-0 is required, not defensive. Panels are grid items, and a grid
      // item's default min-width:auto refuses to shrink below its content's
      // min-content width — which puts the whole page into horizontal scroll on a
      // narrow viewport. Allowing the panel to shrink hands the overflow to the
      // wrappers built to scroll it.
      className={`flex min-w-0 flex-col rounded-lg border border-line bg-panel p-4 ${className}`}
    >
      <div className="mb-3 flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
        <h2 className="eyebrow text-ink-3">{title}</h2>
        {aside}
      </div>

      <div className="min-w-0 flex-1">
        {failed ? (
          <ErrorNote error={failed} />
        ) : isLoading ? (
          <Skeleton height={height} />
        ) : empty ? (
          // Not an error, and said so. On the serving layer an empty window
          // usually means the minute tier has not published it yet, which is a
          // different fact from "no viewers" and the two must not look alike.
          <div
            className="flex flex-col items-center justify-center gap-1 text-center"
            style={{ minHeight: Math.min(height, 160) }}
          >
            <p className="text-[0.8125rem] text-ink-2">
              No published rows in this window.
            </p>
            <p className="max-w-[28rem] text-[0.6875rem] leading-relaxed text-ink-3">
              Either the filter selects traffic that did not occur here, or the
              minute tier has not published these minutes yet. Widen the window,
              or clear a filter.
            </p>
          </div>
        ) : (
          children
        )}
      </div>

      {note ?? (panel?.note && !failed ? (
        <p className="mt-3 max-w-[68ch] text-[0.6875rem] leading-relaxed text-ink-3">
          {panel.note}
        </p>
      ) : null)}

      {panel?.stats ? (
        <QueryStats
          stats={panel.stats}
          validating={isValidating}
          className="mt-3 border-t border-line-soft pt-2.5"
        />
      ) : null}

      {panel?.sql ? (
        <SqlPeek
          sql={panel.sql}
          params={panel.params}
          url={query ? panelUrl(panel.panel, query) : undefined}
          grouping={panel.stats?.grouping}
        />
      ) : null}
    </section>
  );
}
