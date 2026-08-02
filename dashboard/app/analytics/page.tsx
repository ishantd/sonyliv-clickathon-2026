"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";
import { ChartLegend, ConcurrencyLine, RankedBar } from "@/components/Charts";
import { FilterBar } from "@/components/FilterBar";
import { PanelFrame } from "@/components/PanelFrame";
import { ErrorNote } from "@/components/ui";
import {
  asNum,
  asStr,
  col,
  panelQuery,
  useDimensionValues,
  usePanel,
  windowParams,
  type Filter,
  type Meta,
  type PanelResponse,
} from "@/lib/analytics";
import { fetcher } from "@/lib/api";
import { useDataset } from "@/lib/dataset";
import { clock, count, decimal, stamp } from "@/lib/format";

/**
 * Concurrency analytics: the answer, its slices, and its working.
 *
 * WHAT THIS PAGE IS FOR. The track's brief asks for a concurrency curve computed
 * from the dataset, filters over the dataset's own dimensions applied to that
 * curve and to every other view, and the ClickHouse queries behind them. All
 * three are here, in that order of prominence, because that is their order of
 * importance: the curve is the answer, the filters are how you interrogate it,
 * and the SQL under each panel is why you should believe it.
 *
 * WHY THE PANELS ARE NOT ALL THE SAME SIZE. The curve is not one of six equal
 * cards — it is the thing the page is about, so it gets the full width, twice the
 * height and the headline readout in its own header. The breakdowns beneath it
 * are peers of each other and are laid out as peers. A grid of identically-sized
 * cards would say all seven answers matter equally, which is not true.
 *
 * Every panel reads the same serving-layer views the ClickStack tiles read, so a
 * number on this page and a number on that one come from one definition.
 */

/** One measurement in the hero's readout row. */
function Readout({
  label,
  value,
  hint,
  tone = "plain",
}: {
  label: string;
  value: string;
  hint?: string;
  tone?: "plain" | "accent" | "muted";
}) {
  const color = {
    plain: "text-ink",
    accent: "text-accent",
    muted: "text-ink-3",
  }[tone];
  return (
    <div className="min-w-0" title={hint}>
      <div className="eyebrow text-ink-3">{label}</div>
      <div className={`tnum mt-0.5 font-mono text-lg leading-none ${color}`}>
        {value}
      </div>
    </div>
  );
}

export default function AnalyticsPage() {
  const { data: meta, error: metaError } = useSWR<Meta>(
    "/api/analytics",
    fetcher,
    { revalidateOnFocus: false },
  );

  // The dataset is chosen in the nav and shared by every page, so this one reads
  // it rather than owning it. The window and the filter stay local: they are
  // meaningful only here.
  //
  // All three are resolved against the server's lists on every render rather than
  // stored as objects, so a dataset switch cannot leave a window pinned to the
  // previous one — the single bug this feature must not have.
  const dbName = useDataset();
  const [winKey, setWinKey] = useState<string | null>(null);
  const [filter, setFilter] = useState<Filter>({});

  const db =
    meta?.databases.find((d) => d.name === dbName) ??
    meta?.databases.find((d) => d.name === meta.default) ??
    meta?.databases[0] ??
    null;

  // Falls back to the database's FIRST window rather than to a shared default, so
  // switching to a dataset whose data lives elsewhere on the timeline still lands
  // on something populated.
  const win = db?.windows.find((w) => w.key === winKey) ?? db?.windows[0] ?? null;

  // Clearing on a dataset change is what makes the fallback above land on the NEW
  // dataset's first window, and what stops a filter selected on one dataset from
  // silently narrowing another. Keyed on the name rather than run in an effect, so
  // it happens during render and no frame is painted with the previous dataset's
  // selection.
  const [seenDb, setSeenDb] = useState<string | null>(null);
  if (db && db.name !== seenDb) {
    setSeenDb(db.name);
    if (winKey !== null) setWinKey(null);
    if (Object.keys(filter).length) setFilter({});
  }

  // Recomputed only when the window or the filter changes, so a relative window
  // does not produce a new URL on every render and re-fetch forever.
  const bounds = useMemo(() => (win ? windowParams(win) : null), [win]);
  const q = useMemo(() => {
    if (!db || !bounds) return null;
    return (cap: number) =>
      panelQuery({ db: db.name, from: bounds.from, to: bounds.to, cap, filter });
  }, [db, bounds, filter]);

  // The filter's own options follow the window, so a filter never offers a value
  // that would produce an empty chart. Unfiltered, deliberately: the values are
  // what you could narrow TO, and narrowing them by the current selection would
  // make a filter impossible to change once set.
  const dimQuery = useMemo(
    () =>
      db && bounds
        ? panelQuery({ db: db.name, from: bounds.from, to: bounds.to, cap: 200, filter: {} })
        : null,
    [db, bounds],
  );
  const { values: dimValues } = useDimensionValues(dimQuery);

  const curveQ = q ? q(5000) : null;
  const barQ = q ? q(12) : null;
  const titleQ = q ? q(15) : null;

  const curve = usePanel("concurrency", curveQ);
  const platform = usePanel("platform_peak", barQ);
  const vtype = usePanel("video_type_hours", barQ);
  const category = usePanel("category_hours", barQ);
  const country = usePanel("country_hours", barQ);
  const appver = usePanel("app_version_peak", barQ);
  const titles = usePanel("top_titles", titleQ);
  const fresh = usePanel("freshness", barQ);

  const curveData = useMemo(() => {
    const d = curve.data;
    if (!d || d.error || !d.rows.length) return null;
    const iM = col(d, "minute");
    const iP = col(d, "peak");
    const iA = col(d, "average");
    return {
      // Time only on the axis: the date is in the window selector, and repeating
      // it on every tick leaves no room for the ticks themselves.
      labels: d.rows.map((r) => clock(asStr(r[iM]))),
      stamps: d.rows.map((r) => asStr(r[iM])),
      peak: d.rows.map((r) => asNum(r[iP])),
      average: d.rows.map((r) => asNum(r[iA]) ?? 0),
    };
  }, [curve.data]);

  const headline = useMemo(() => {
    if (!curveData) return null;
    let peak: number | null = null;
    let peakAt = "";
    curveData.peak.forEach((v, i) => {
      if (v != null && (peak == null || v > peak)) {
        peak = v;
        peakAt = curveData.stamps[i];
      }
    });
    // Mean of the per-minute time-weighted averages, which for equal-length
    // minutes IS the window's time-weighted average. Not a mean of peaks, which
    // would be meaningless.
    const avg =
      curveData.average.reduce((a, b) => a + b, 0) / curveData.average.length;
    return { peak: peak as number | null, peakAt, avg, minutes: curveData.peak.length };
  }, [curveData]);

  const exactPeak = curve.data?.mask?.exact_peak ?? true;

  return (
    <>
      <header className="mb-5">
        <h1 className="text-[1.0625rem] text-ink">Concurrency analytics</h1>
        <p className="mt-1 max-w-[72ch] text-[0.8125rem] leading-relaxed text-ink-2">
          Foreground-only concurrent viewers over time, read from the minute
          serving tier. Every panel names the rollup it read, what the query cost
          and the statement that produced it.
        </p>
      </header>

      <ErrorNote error={metaError} />

      {meta && db ? (
        <div className="mb-4 flex flex-col gap-3">
          <p className="max-w-[80ch] text-[0.75rem] leading-relaxed text-ink-3">
            {db.note}
          </p>

          {/* The dataset itself is picked in the nav, because it applies to every
              page. The window is picked here, because it does not. */}
          <div
            className="flex flex-wrap items-center gap-2"
            role="group"
            aria-label="Time window"
          >
            <span className="eyebrow text-ink-3">Window</span>
            {db.windows.map((w) => (
              <button
                key={w.key}
                onClick={() => setWinKey(w.key)}
                aria-pressed={w.key === win?.key}
                className={`rounded border px-2.5 py-1 text-[0.8125rem] transition-colors duration-150 ${
                  w.key === win?.key
                    ? "border-accent-dim bg-accent-wash text-accent"
                    : "border-line text-ink-2 hover:border-ink-3 hover:text-ink"
                }`}
              >
                {w.label}
              </button>
            ))}
            {bounds ? (
              <span className="tnum ml-auto font-mono text-[0.6875rem] text-ink-3">
                {bounds.from} → {bounds.to} UTC
              </span>
            ) : null}
          </div>
        </div>
      ) : null}

      {meta ? (
        <FilterBar
          dimensions={meta.dimensions}
          values={dimValues}
          filter={filter}
          onChange={setFilter}
          rollups={meta.rollups}
          cappedAt={200}
        />
      ) : null}

      <div className="mt-4 grid gap-4">
        {/* The hero. Full width, double height, and the headline numbers live in
            its own header rather than in a separate tile row — one strong object
            instead of two weak ones, and the numbers cannot be read apart from
            the curve that produced them. */}
        <PanelFrame
          title="Concurrency over time"
          panel={curve.data}
          query={curveQ}
          transport={curve.transport}
          queryError={curve.query}
          isLoading={curve.isLoading}
          isValidating={curve.isValidating}
          empty={!curveData}
          height={340}
          aside={
            headline ? (
              <div className="flex flex-wrap items-end gap-x-6 gap-y-2">
                <Readout
                  label={exactPeak ? "Peak concurrent" : "Peak"}
                  value={
                    exactPeak && headline.peak != null
                      ? count(headline.peak)
                      : "withheld"
                  }
                  tone="accent"
                  hint={
                    exactPeak && headline.peak != null
                      ? `Exact maximum inside a single minute, at ${stamp(headline.peakAt)} UTC.`
                      : curve.data?.mask?.why
                  }
                />
                <Readout
                  label="Time-weighted avg"
                  value={decimal(headline.avg)}
                  hint="Mean of the per-minute time-weighted averages over this window."
                />
                <Readout
                  label="Minutes"
                  value={count(headline.minutes)}
                  tone="muted"
                  hint="Minutes the serving tier has published in this window."
                />
                <Readout
                  label="Dataset"
                  value={curve.data?.database ?? "—"}
                  tone="muted"
                  hint="Reported by the server, not by the picker: a chart that cannot be attributed is worse than no chart."
                />
              </div>
            ) : null
          }
        >
          {curveData ? (
            <>
              <ChartLegend withheldPeak={!exactPeak} />
              <ConcurrencyLine
                labels={curveData.labels}
                peak={curveData.peak}
                average={curveData.average}
              />
            </>
          ) : null}
        </PanelFrame>

        <div className="grid gap-4 lg:grid-cols-2">
          <BreakdownPanel
            title="Peak by platform"
            dim="platform"
            unit="peak"
            state={platform}
            query={barQ}
          />
          <BreakdownPanel
            title="Viewer-hours by content type"
            dim="video_type"
            unit="viewer_hours"
            state={vtype}
            query={barQ}
          />
          <BreakdownPanel
            title="Viewer-hours by category"
            dim="category"
            unit="viewer_hours"
            state={category}
            query={barQ}
          />
          <BreakdownPanel
            title="Peak by app version"
            dim="app_version"
            unit="peak"
            state={appver}
            query={barQ}
          />
        </div>

        <PanelFrame
          title="Top titles by viewer-hours"
          panel={titles.data}
          query={titleQ}
          transport={titles.transport}
          queryError={titles.query}
          isLoading={titles.isLoading}
          isValidating={titles.isValidating}
          empty={!titles.data?.rows.length}
          height={320}
        >
          {titles.data?.rows.length ? <TitleTable panel={titles.data} /> : null}
        </PanelFrame>

        <div className="grid gap-4 lg:grid-cols-2">
          <BreakdownPanel
            title="Viewer-hours by country"
            dim="country"
            unit="viewer_hours"
            state={country}
            query={barQ}
            height={180}
          />

          <PanelFrame
            title="Serving layer freshness"
            panel={fresh.data}
            query={barQ}
            transport={fresh.transport}
            queryError={fresh.query}
            isLoading={fresh.isLoading}
            isValidating={fresh.isValidating}
            empty={!fresh.data?.rows.length}
            height={180}
          >
            {fresh.data?.rows.length ? <Freshness panel={fresh.data} /> : null}
          </PanelFrame>
        </div>
      </div>
    </>
  );
}

/**
 * A ranked breakdown of one dimension.
 *
 * One component for all five because they differ only in which dimension they
 * group by and which quantity they rank — and a peak panel that looked different
 * from a viewer-hours panel for any reason other than that distinction would be
 * teaching the reader something untrue.
 */
function BreakdownPanel({
  title,
  dim,
  unit,
  state,
  query,
  height = 260,
}: {
  title: string;
  dim: string;
  unit: "peak" | "viewer_hours";
  state: ReturnType<typeof usePanel>;
  query: string | null;
  height?: number;
}) {
  const d = state.data;
  const rows = d && !d.error ? d.rows : [];
  const withheld = unit === "peak" && d ? !d.mask?.exact_peak : false;

  // A peak panel whose peak is withheld falls back to the quantity that IS exact
  // at every rollup, rather than rendering an empty chart. The bar's form changes
  // with it, so the reader is not told "peak" while looking at viewer-hours.
  const shown = withheld ? "viewer_hours" : unit;

  const values = rows.map((r) => (d ? asNum(r[col(d, shown)]) : null));
  const labels = rows.map((r) => (d ? asStr(r[col(d, dim)]) : ""));

  return (
    <PanelFrame
      title={title}
      panel={d}
      query={query}
      transport={state.transport}
      queryError={state.query}
      isLoading={state.isLoading}
      isValidating={state.isValidating}
      empty={!rows.length}
      height={height}
      aside={
        withheld ? (
          <span className="text-[0.6875rem] text-accent" title={d?.mask?.why}>
            showing viewer-hours — peak withheld
          </span>
        ) : rows.length ? (
          <span className="text-[0.6875rem] text-ink-3">
            {count(rows.length)} {rows.length === 1 ? "value" : "values"}
          </span>
        ) : null
      }
    >
      <RankedBar
        label={shown === "peak" ? "peak" : "viewer-hours"}
        labels={labels}
        values={values}
        variant={shown === "peak" ? "fill" : "outline"}
        decimals={shown !== "peak"}
        height={height}
      />
    </PanelFrame>
  );
}

/** The title leaderboard, as a table: five columns of mixed types is not a chart. */
function TitleTable({ panel }: { panel: PanelResponse }) {
  const iTitle = col(panel, "title");
  const iPeak = col(panel, "peak");
  const iAt = col(panel, "peaked_at");
  const iHours = col(panel, "viewer_hours");
  const top = Math.max(...panel.rows.map((r) => asNum(r[iHours]) ?? 0), 1);

  return (
    <div className="-mx-1 overflow-x-auto">
      <table className="w-full min-w-[34rem] text-[0.8125rem]">
        <thead>
          <tr className="border-b border-line text-left text-ink-3">
            <th className="px-1 py-1.5 font-normal">Title</th>
            <th className="px-1 py-1.5 text-right font-normal">Viewer-hours</th>
            <th className="px-1 py-1.5 text-right font-normal">Peak</th>
            <th className="px-1 py-1.5 text-right font-normal">Peaked at</th>
          </tr>
        </thead>
        <tbody>
          {panel.rows.map((r, i) => {
            const hours = asNum(r[iHours]) ?? 0;
            const peak = asNum(r[iPeak]);
            return (
              <tr
                key={i}
                className="group border-b border-line-soft last:border-0"
              >
                <td className="w-[45%] px-1 py-1.5">
                  {/* The share bar is INSIDE the cell, behind the text, rather
                      than a sixth column: it is a reading aid for the ranking
                      that is already there, not a measurement of its own.

                      The percentage resolves against this wrapper, which is why
                      it exists — a percentage width inside a `max-width: 0`
                      table cell resolves against nothing and renders a stub. */}
                  <span className="relative block min-w-0">
                    <span
                      aria-hidden
                      className="absolute inset-y-[-2px] left-0 rounded-sm bg-accent-wash transition-[width] duration-300"
                      style={{ width: `${(hours / top) * 100}%` }}
                    />
                    <span className="relative block truncate text-ink-2 group-hover:text-ink">
                      {asStr(r[iTitle])}
                    </span>
                  </span>
                </td>
                <td className="tnum px-1 py-1.5 text-right font-mono text-ink">
                  {decimal(hours)}
                </td>
                <td className="tnum px-1 py-1.5 text-right font-mono text-ink-2">
                  {peak == null ? (
                    <span className="text-ink-3" title="Not exact at this rollup">
                      —
                    </span>
                  ) : (
                    count(peak)
                  )}
                </td>
                <td className="tnum px-1 py-1.5 text-right font-mono text-ink-3">
                  {asStr(r[iAt]) ? stamp(asStr(r[iAt])) : "—"}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

/** Serving-tier lag, per layer. */
function Freshness({ panel }: { panel: PanelResponse }) {
  const iLayer = col(panel, "layer");
  const iLag = col(panel, "data_lag_s");
  const iWatermark = col(panel, "watermark");
  const iRows = col(panel, "rows_out");

  return (
    <ul className="flex flex-col gap-2">
      {panel.rows.map((r, i) => {
        const lag = asNum(r[iLag]) ?? 0;
        // 900s is the same threshold the drop-detector staleness alert fires on,
        // so this page and that alert agree on what "stale" means.
        const stale = lag > 900;
        return (
          <li
            key={i}
            className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-0.5 rounded border border-line bg-sunken px-2.5 py-2"
          >
            <span className="font-mono text-[0.8125rem] text-ink-2">
              {asStr(r[iLayer])}
            </span>
            <span
              className={`tnum font-mono text-[0.8125rem] ${stale ? "text-bad" : "text-ink"}`}
              title={`Watermark ${asStr(r[iWatermark])} UTC · ${count(asNum(r[iRows]))} rows published`}
            >
              {count(lag)}s behind
            </span>
          </li>
        );
      })}
    </ul>
  );
}
