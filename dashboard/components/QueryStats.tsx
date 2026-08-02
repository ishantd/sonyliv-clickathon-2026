"use client";

import type { QueryStats as Stats } from "@/lib/analytics";
import { bytes, count, ms } from "@/lib/format";

/**
 * What a panel's query cost, printed beside the panel.
 *
 * WHY EVERY CHART CARRIES ONE. The claim this project makes is that a
 * pre-aggregated serving tier answers in milliseconds, reading thousands of
 * rows, what costs hundreds of milliseconds and fourteen million rows to
 * recompute from the event stream. A dashboard that asserts that in prose is
 * making a claim. One that prints rows_read under every chart is showing its
 * working, and the reader can check it against system.query_log.
 *
 * The figures are the driver's own progress counters, not a stopwatch around a
 * fetch: `server_ms` and `rows_read` are what ClickHouse reported doing.
 * `elapsed_ms` is the round trip this browser's request took, which is a
 * different and also honest number — showing only the fast one would be the
 * cheat this strip exists to avoid.
 */

function Cell({
  value,
  unit,
  title,
  tone = "plain",
}: {
  value: string;
  unit: string;
  title: string;
  tone?: "plain" | "muted";
}) {
  return (
    <span className="flex items-baseline gap-1 whitespace-nowrap" title={title}>
      <span
        className={`tnum font-mono ${tone === "muted" ? "text-ink-3" : "text-ink-2"}`}
      >
        {value}
      </span>
      <span className="text-ink-3">{unit}</span>
    </span>
  );
}

export function QueryStats({
  stats,
  validating = false,
  className = "",
}: {
  stats: Stats | undefined;
  /** True while SWR is refetching, so a stale strip does not read as a live one. */
  validating?: boolean;
  className?: string;
}) {
  if (!stats) return null;

  return (
    <div
      className={`flex flex-wrap items-baseline gap-x-3 gap-y-1 text-[0.6875rem] transition-opacity duration-150 ${
        validating ? "opacity-50" : "opacity-100"
      } ${className}`}
    >
      <Cell
        value={ms(stats.server_ms)}
        unit="in ClickHouse"
        title={`ClickHouse reported ${ms(stats.server_ms)} of execution. The browser waited ${ms(stats.elapsed_ms)} in total, which includes the network hop and row decoding.`}
      />
      <span aria-hidden className="text-line">
        ·
      </span>
      <Cell
        value={count(stats.rows_read)}
        unit="rows read"
        title={`${count(stats.rows_read)} rows read from storage to return ${count(stats.result_rows)}. Recomputing the same answer from the event stream reads millions.`}
      />
      <span aria-hidden className="text-line">
        ·
      </span>
      <Cell
        value={bytes(stats.bytes_read)}
        unit="scanned"
        title={`${bytes(stats.bytes_read)} decompressed off disk.`}
        tone="muted"
      />
      {stats.grouping ? (
        <>
          <span aria-hidden className="text-line">
            ·
          </span>
          <RollupBadge grouping={stats.grouping} exact={stats.exact_peak} why={stats.mask_reason} />
        </>
      ) : null}
    </div>
  );
}

/**
 * Which rollup answered, and whether it could carry an exact peak.
 *
 * State lands on the text rather than on a coloured chip: an amber pill on six
 * panels at once would read as six warnings, when the ordinary case — an exact
 * rollup — is not a warning at all. Only the inexact case takes the signal
 * colour, because only it changes what the reader may conclude.
 */
export function RollupBadge({
  grouping,
  exact,
  why,
}: {
  grouping: string;
  exact: boolean;
  why: string;
}) {
  return (
    <span
      className="flex items-baseline gap-1 whitespace-nowrap"
      title={why}
    >
      <span className="text-ink-3">rollup</span>
      <span className={`font-mono ${exact ? "text-ink-2" : "text-accent"}`}>
        {grouping}
      </span>
      {!exact ? (
        <span className="text-accent" aria-label="peak withheld">
          · peak withheld
        </span>
      ) : null}
    </span>
  );
}
