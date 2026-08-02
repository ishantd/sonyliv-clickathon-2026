"use client";

import Link from "next/link";
import { useState } from "react";
import useSWR from "swr";
import { useDataset } from "@/lib/dataset";
import { DualCurveChart } from "@/components/DualCurveChart";
import { FleetFilters } from "@/components/FleetFilters";
import { Caveat, ErrorNote, Panel, Stat, StatGrid } from "@/components/ui";
import { clockTime, fetcher, filterQuery, num } from "@/lib/api";
import type { FleetCurveResponse, FleetFilter } from "@/lib/types";

const WINDOWS = [15, 30, 60, 180];

/**
 * Active sessions over time: what the fleet recorded, against what the pipeline
 * infers from the events the fleet wrote.
 *
 * Both lines are narrowed by the same filter, and deliberately so — the Go handler
 * derives the ClickHouse query's scope from the session ids the filter selects, so
 * there is one implementation of "which sessions" rather than two that could
 * disagree and make the gap unreadable.
 */
export default function LivePage() {
  const [filter, setFilter] = useState<FleetFilter>({});
  const [minutes, setMinutes] = useState(30);

  // The served metric by default. `exact` re-runs the state machine over every
  // event, scoped to the fleet's own sessions — slower and narrower, and the only
  // one that is an independent oracle, so it stays one click away.
  const [exact, setExact] = useState(false);

  // Only the ClickHouse series follows the dataset picker. The generator series is
  // in-process fleet state and belongs to this box, not to a database — so on a
  // read-only dataset the two lines answer different questions, and the page says
  // so rather than letting the gap read as pipeline lag.
  //
  // The two controls are independent: `exact` chooses which derivation answers,
  // `dataset` chooses which database it reads, and every combination is valid.
  const dataset = useDataset();

  const { data, error } = useSWR<FleetCurveResponse>(
    `/api/fleet/curve?minutes=${minutes}${exact ? "&exact=1" : ""}&${filterQuery(filter)}${dataset ? `&db=${dataset}` : ""}`,
    fetcher,
    { refreshInterval: 5000, keepPreviousData: true },
  );

  const gen = data?.generator ?? [];
  const ch = data?.clickhouse ?? [];

  const lastGen = gen.length ? gen[gen.length - 1].sessions : 0;
  const lastCH = ch.length ? ch[ch.length - 1].sessions : undefined;

  // Average concurrency over the window, from the conserved measure rather than by
  // averaging the per-minute counts — the counts are any-overlap, so averaging them
  // overstates a window in which sessions came and went.
  const totalMS = gen.reduce((a, p) => a + p.active_ms, 0);
  const avgConcurrency = gen.length ? totalMS / 60000 / gen.length : 0;
  const peak = gen.reduce((a, p) => Math.max(a, p.sessions), 0);

  return (
    <div className="grid gap-4">
      <Panel title="active sessions per minute" accent="live">
        <div className="mb-3 flex flex-wrap items-center gap-2">
          <div className="flex gap-1" role="group" aria-label="Time window">
            {WINDOWS.map((m) => (
              <button
                key={m}
                onClick={() => setMinutes(m)}
                aria-pressed={minutes === m}
                className={`rounded px-2 py-1 font-mono text-[0.6875rem] transition-colors ${
                  minutes === m
                    ? "bg-accent-wash text-accent"
                    : "text-ink-3 hover:text-ink"
                }`}
              >
                {m}m
              </button>
            ))}
          </div>
          <button
            type="button"
            onClick={() => setExact(!exact)}
            aria-pressed={exact}
            title="Re-derive from raw events, scoped to the fleet's own sessions. Slower, and the only independent check on the served metric."
            className={`rounded px-2 py-1 font-mono text-[0.6875rem] transition-colors ${
              exact ? "bg-accent-wash text-accent" : "text-ink-3 hover:text-ink"
            }`}
          >
            exact
          </button>
          <span className="ml-auto font-mono text-[0.6875rem] text-ink-3">
            {num(data?.scoped_sessions)} sessions in scope
          </span>
        </div>

        <DualCurveChart generator={gen} clickhouse={ch} />

        <div className="mt-4">
          <StatGrid>
            <Stat
              label="fleet now"
              value={num(lastGen)}
              tone={lastGen ? "live" : "muted"}
            />
            <Stat
              label="pipeline now"
              value={lastCH === undefined ? "—" : num(lastCH)}
            />
            <Stat label="peak" value={num(peak)} />
            <Stat label="avg concurrent" value={avgConcurrency.toFixed(1)} />
          </StatGrid>
        </div>

        {data?.clickhouse_error && (
          <p className="mt-3 rounded border border-bad/40 bg-bad-wash px-2.5 py-2 font-mono text-xs whitespace-pre-wrap text-bad">
            pipeline line unavailable: {data.clickhouse_error}
          </p>
        )}

        <Caveat>
          {data?.source === "exact" ? (
            <>
              <span className="text-ink-2">Exact.</span> The full state machine over
              every event of the fleet&apos;s own sessions. This is the oracle — a
              metric cannot validate itself — and it runs to the current minute.
            </>
          ) : (
            <>
              <span className="text-ink-2">Served</span> from{" "}
              <code>concurrency_minute</code>, complete through{" "}
              <span className="text-ink-2">
                {data?.sealed_through
                  ? clockTime(data.sealed_through).slice(0, 5)
                  : "—"}{" "}
                UTC
              </span>
              . The newest couple of minutes are not sealed yet, so the dashed line
              stops short of the solid one — that distance is the pipeline&apos;s
              lag, shown rather than hidden. The metric covers all traffic, not just
              the fleet, so an unfiltered read can sit above the fleet line if
              anything else is writing.
            </>
          )}
        </Caveat>

        <ErrorNote error={error} />
      </Panel>

      <Panel title="filter">
        <FleetFilters value={filter} onChange={setFilter} showPhase={false} />
        <Caveat>
          Phase is not a filter here on purpose: it is the session&apos;s state{" "}
          <em>now</em>, so filtering a time series by it would drop the history of
          every session that has since changed state — which reads as data loss
          rather than as a filter.
        </Caveat>
      </Panel>

      <Panel title="how to read the gap">
        <ul className="grid gap-2 text-[0.8125rem] leading-relaxed text-ink-2">
          <li>
            <span className="text-accent">Solid</span> is the fleet&apos;s own
            record. It did not infer activity — it decided the state and wrote the
            interval down at the moment of each transition, so it is exact by
            construction.
          </li>
          <li>
            <span className="text-accent">Dashed</span> is ClickHouse running the
            real five-term predicate over the events the fleet wrote. Not the{" "}
            <Link href="/" className="text-accent hover:underline">
              load simulator&apos;s
            </Link>{" "}
            heartbeat-lease estimate, which peaks 37% high and would show a gap
            that says nothing about the pipeline.
          </li>
          <li>
            A gap means one of three things: the pipeline is wrong, events were
            lost on the way in, or reordering broke something. It is the one
            measurement here that can fail.
          </li>
          <li>
            The dashed line lags briefly by design — events are batched about once
            a second and inserted asynchronously, so the newest minute is often
            still filling.
          </li>
        </ul>
      </Panel>
    </div>
  );
}
