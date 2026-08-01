"use client";

import Link from "next/link";
import { useState } from "react";
import useSWR from "swr";
import { FleetFilters } from "@/components/FleetFilters";
import { PhaseBadge } from "@/components/PhaseBadge";
import { Button, ErrorNote, Panel, Stat, StatGrid } from "@/components/ui";
import { api, clockTime, fetcher, filterQuery, num, seconds } from "@/lib/api";
import type { FleetFilter, FleetListResponse } from "@/lib/types";

const PAGE = 50;

/**
 * The session listing.
 *
 * Polls at 2s: every row's phase can change without anyone touching it — a silenced
 * session flips to `expired` when its lease runs out — so a static table would be
 * quietly wrong most of the time.
 *
 * Paged server-side. At the 2,000-per-create ceiling, rendering every row would put
 * tens of thousands of DOM nodes on the page to show information nobody can read.
 */
export default function FleetPage() {
  const [filter, setFilter] = useState<FleetFilter>({});
  const [offset, setOffset] = useState(0);
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);

  const qs = filterQuery(filter);
  const { data, mutate } = useSWR<FleetListResponse>(
    `/api/fleet/sessions?offset=${offset}&limit=${PAGE}&${qs}`,
    fetcher,
    { refreshInterval: 2000, keepPreviousData: true },
  );

  const sessions = data?.sessions ?? [];
  const total = data?.total ?? 0;
  const stats = data?.stats;

  async function clearEnded() {
    setBusy(true);
    setError(null);
    try {
      await api.fleetClearEnded();
      setOffset(0);
      await mutate();
    } catch (e) {
      setError(e);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="grid gap-4">
      <Panel title="fleet">
        <StatGrid>
          <Stat
            label="active"
            value={num(stats?.active)}
            tone={stats?.active ? "live" : "muted"}
          />
          <Stat label="paused" value={num(stats?.paused)} />
          <Stat label="background" value={num(stats?.backgrounded)} />
          <Stat
            label="expired"
            value={num(stats?.expired)}
            tone={stats?.expired ? "bad" : "muted"}
          />
          <Stat label="ended" value={num(stats?.ended)} tone="muted" />
          <Stat label="total" value={num(stats?.total)} />
          <Stat label="events sent" value={num(stats?.events_sent)} />
        </StatGrid>

        <div className="mt-4 flex flex-wrap items-center gap-2">
          <Link href="/fleet/new/">
            <Button variant="primary">Create sessions</Button>
          </Link>
          <Button
            onClick={clearEnded}
            disabled={busy || !stats?.ended}
            title="Removes ended sessions from this list. Events already in ClickHouse are untouched."
          >
            Clear {num(stats?.ended)} ended
          </Button>
          <Link
            href="/live/"
            className="font-mono text-xs text-accent hover:underline"
          >
            live graph →
          </Link>
        </div>
        <ErrorNote error={error} />
      </Panel>

      <Panel title="filter">
        <FleetFilters
          value={filter}
          onChange={(next) => {
            setFilter(next);
            // Reset paging: page 3 of the old filter is rarely page 3 of the new
            // one, and landing past the end shows an empty table that looks broken.
            setOffset(0);
          }}
        />
      </Panel>

      <Panel title={`sessions — ${num(total)} matching`}>
        {sessions.length === 0 ? (
          <p className="font-mono text-xs text-ink-3">
            {total === 0
              ? "no sessions yet — create some."
              : "no sessions on this page."}
          </p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-[0.8125rem]">
              <thead>
                <tr className="border-b border-line text-left">
                  <Th>phase</Th>
                  <Th>session</Th>
                  <Th>content</Th>
                  <Th>platform</Th>
                  <Th right>events</Th>
                  <Th right>active</Th>
                  <Th right>lease expires</Th>
                </tr>
              </thead>
              <tbody>
                {sessions.map((s) => (
                  <tr
                    key={s.video_session_id}
                    className="border-b border-line-soft last:border-b-0 hover:bg-sunken"
                  >
                    <Td>
                      <PhaseBadge phase={s.phase} />
                    </Td>
                    <Td>
                      <Link
                        href={`/fleet/session/?id=${s.video_session_id}`}
                        className="font-mono text-xs text-accent hover:underline"
                      >
                        {s.video_session_id.slice(0, 12)}…
                      </Link>
                      {!s.heartbeating && !s.ended && (
                        <span
                          className="ml-2 font-mono text-[0.625rem] text-bad"
                          title="Heartbeats stopped. The pipeline only notices when the lease expires."
                        >
                          silenced
                        </span>
                      )}
                    </Td>
                    <Td>
                      <span className="text-ink-2">
                        {s.content_title || "(untitled)"}
                      </span>
                      <span className="ml-1.5 font-mono text-[0.6875rem] text-ink-3">
                        {s.content_id}
                      </span>
                    </Td>
                    <Td>
                      <span className="font-mono text-[0.6875rem] text-ink-3">
                        {s.platform} · {s.country}
                      </span>
                    </Td>
                    <Td right mono>
                      {num(s.events_sent)}
                    </Td>
                    <Td right mono>
                      {seconds(s.active_ms)}
                    </Td>
                    <Td right mono>
                      {clockTime(s.lease_expires)}
                    </Td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {total > PAGE && (
          <div className="mt-3 flex items-center gap-2 font-mono text-xs">
            <Button
              onClick={() => setOffset(Math.max(0, offset - PAGE))}
              disabled={offset === 0}
            >
              ← prev
            </Button>
            <span className="text-ink-3">
              {num(offset + 1)}–{num(Math.min(offset + PAGE, total))} of{" "}
              {num(total)}
            </span>
            <Button
              onClick={() => setOffset(offset + PAGE)}
              disabled={offset + PAGE >= total}
            >
              next →
            </Button>
          </div>
        )}
      </Panel>
    </div>
  );
}

function Th({
  children,
  right,
}: {
  children: React.ReactNode;
  right?: boolean;
}) {
  return (
    <th
      className={`eyebrow pb-2 font-normal text-ink-3 ${right ? "text-right" : ""}`}
    >
      {children}
    </th>
  );
}

function Td({
  children,
  right,
  mono,
}: {
  children: React.ReactNode;
  right?: boolean;
  mono?: boolean;
}) {
  return (
    <td
      className={`py-1.5 ${right ? "text-right" : ""} ${mono ? "tnum font-mono text-xs text-ink-2" : ""}`}
    >
      {children}
    </td>
  );
}
