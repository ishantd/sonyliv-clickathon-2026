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
  from: string;
  to: string;
  columns: string[];
  rows: unknown[][];
  error?: string;
};

/*
 * Windows.
 *
 * "Hot hour" is a fixed date, and that is the point: it is the hour the extract
 * is about, the hour every published figure in this repo is measured over, and it
 * is what makes this page checkable against them. The live windows are relative
 * and show generator traffic.
 *
 * The default is deliberately the hot hour rather than "last hour". A dashboard
 * whose first render is empty because nothing happened in the last sixty minutes
 * reads as broken, and on a frozen extract that is the normal case.
 */
const WINDOWS = [
  { key: "hot", label: "Hot hour (26 Jul)", from: "2026-07-26 10:00:00", to: "2026-07-26 11:00:00" },
  { key: "extract", label: "Whole extract", from: "2026-07-14 00:00:00", to: "2026-07-27 00:00:00" },
  { key: "1h", label: "Last hour", relMinutes: 60 },
  { key: "6h", label: "Last 6 hours", relMinutes: 360 },
] as const;

function windowParams(w: (typeof WINDOWS)[number]): string {
  if ("relMinutes" in w) {
    const to = new Date();
    const from = new Date(to.getTime() - w.relMinutes * 60_000);
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
function usePanel(name: string, params: string, cap = 500) {
  const { data, error, isLoading } = useSWR<PanelResponse>(
    `/api/analytics/${name}?${params}&cap=${cap}`,
    fetcher,
    { keepPreviousData: true, revalidateOnFocus: false },
  );
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
  const [win, setWin] = useState<(typeof WINDOWS)[number]>(WINDOWS[0]);
  // Recomputed only when the window changes, so a relative window does not produce
  // a new URL on every render and re-fetch forever.
  const params = useMemo(() => windowParams(win), [win]);

  const curve = usePanel("concurrency", params, 5000);
  const platform = usePanel("platform_peak", params, 12);
  const vtype = usePanel("video_type_hours", params, 8);
  const category = usePanel("category_hours", params, 12);
  const titles = usePanel("top_titles", params, 15);
  const fresh = usePanel("freshness", params, 8);

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

      <div className="mb-5 flex flex-wrap gap-1.5">
        {WINDOWS.map((w) => (
          <button
            key={w.key}
            onClick={() => setWin(w)}
            aria-current={w.key === win.key ? "true" : undefined}
            className={`rounded border px-2.5 py-1 text-[0.8125rem] transition-colors ${
              w.key === win.key
                ? "border-accent-dim bg-accent-wash text-accent"
                : "border-line text-ink-2 hover:text-ink"
            }`}
          >
            {w.label}
          </button>
        ))}
      </div>

      {headline ? (
        <StatGrid>
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
