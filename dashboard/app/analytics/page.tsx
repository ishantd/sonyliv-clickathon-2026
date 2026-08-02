"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";
import { ChartLegend, ConcurrencyLine, RankedBar } from "@/components/Charts";
import { FilterBar } from "@/components/FilterBar";
import { GrainNote, GrainPicker } from "@/components/GrainPicker";
import { CUSTOM, RangePicker } from "@/components/RangePicker";
import { LiveSessionsPanel } from "@/components/LiveSessions";
import { PanelFrame } from "@/components/PanelFrame";
import { ErrorNote } from "@/components/ui";
import {
  asNum,
  asStr,
  bucketLabel,
  bucketsInWindow,
  col,
  grainPlural,
  panelQuery,
  resolveGrain,
  useDimensionValues,
  usePanel,
  windowParams,
  type Filter,
  type Meta,
  type PanelResponse,
} from "@/lib/analytics";
import { fetcher } from "@/lib/api";
import { useDataset } from "@/lib/dataset";
import { count, decimal, stamp } from "@/lib/format";

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
  // The typed range, in API form. Null means "follow the preset", which is the
  // state the page opens in and returns to whenever a preset is chosen — so the
  // two controls are one range rather than two competing sources of truth.
  const [custom, setCustom] = useState<{ from: string; to: string } | null>(null);
  const [grainKey, setGrainKey] = useState<string | null>(null);
  const [filter, setFilter] = useState<Filter>({});

  // Defaults to minute — the grain the serving tier publishes at, and the one
  // every figure quoted in the README and the deck is measured on. Falling back
  // to the first grain offered rather than hard-failing, so the picker still
  // works if the server ever reorders or renames the list.
  const grains = meta?.grains ?? [];
  const grain = resolveGrain(grains, grainKey, "minute");

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
  //
  // The GRAIN is deliberately not cleared with them. A window belongs to a
  // dataset — each one declares its own — and a filter can select a value the
  // next dataset has never seen, so both have to go. Minute/hour/day is a
  // property of time itself and means the same thing everywhere, so resetting it
  // would just undo the reader's choice for no reason.
  const [seenDb, setSeenDb] = useState<string | null>(null);
  if (db && db.name !== seenDb) {
    setSeenDb(db.name);
    if (winKey !== null) setWinKey(null);
    // Cleared with the window, and for the same reason: a range typed against
    // 26 July finds nothing in a dataset whose only traffic is on the 31st, and
    // an empty chart is indistinguishable from a broken one.
    if (custom !== null) setCustom(null);
    if (Object.keys(filter).length) setFilter({});
  }

  // Recomputed only when the window or the filter changes, so a relative window
  // does not produce a new URL on every render and re-fetch forever.
  const presetBounds = useMemo(() => (win ? windowParams(win) : null), [win]);

  // The typed range wins when it is set AND valid. An inverted range is held
  // back rather than sent: the server rejects from >= to outright, so forwarding
  // it would replace every panel with an error while someone is mid-edit — the
  // half-typed state of a datetime field is not a question anyone asked.
  const bounds = useMemo(() => {
    if (!custom) return presetBounds;
    const ms = (s: string) => Date.parse(`${s.replace(" ", "T")}Z`);
    const ok =
      custom.from !== "" &&
      custom.to !== "" &&
      Number.isFinite(ms(custom.from)) &&
      Number.isFinite(ms(custom.to)) &&
      ms(custom.from) < ms(custom.to);
    return ok ? custom : presetBounds;
  }, [custom, presetBounds]);
  const q = useMemo(() => {
    if (!db || !bounds) return null;
    // Every panel carries the grain, not just the curve. The breakdowns are
    // window-totals and do not bucket, so it changes nothing for them today —
    // but a panel that silently ignored a parameter the URL claims to carry
    // would make the shown API call a lie, and that call is on screen under
    // each card.
    return (cap: number) =>
      panelQuery({
        db: db.name,
        from: bounds.from,
        to: bounds.to,
        cap,
        filter,
        grain: grain?.key,
      });
  }, [db, bounds, filter, grain]);

  // The filter's own options follow the window, so a filter never offers a value
  // that never appears in it. Unfiltered, deliberately: the values are what you
  // could narrow TO, and narrowing them by the current selection would make a
  // filter impossible to change once set.
  //
  // No grain here, and that is not an oversight: which values EXIST in a window
  // does not depend on how the window is bucketed. Sending it would put the
  // grain in this request's cache key and re-fetch every dimension's values on
  // every grain change, for an identical answer.
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
  const live = usePanel("live_sessions", barQ);

  // The grain the ROWS ON SCREEN were bucketed at, which is not always the one
  // the picker holds: `keepPreviousData` keeps the last result visible while the
  // next request is in flight, so for one round trip the control says "Day" over
  // a chart of minutes. Everything that describes the plotted rows — the axis
  // format, the bucket count, the readout labels — is driven from the server's
  // echo, and only the pending-window note is driven from the control.
  const shownGrain = resolveGrain(grains, curve.data?.grain, grain?.key);
  // The singular noun for one x-axis bucket, for the legend and the tooltip.
  // Falls back to "minute" rather than to the picker: before meta resolves there
  // is no grain to read, and minute is what the server defaults to, so the two
  // agree during the first frame instead of disagreeing.
  const bucketNoun = (shownGrain?.label ?? "Minute").toLowerCase();

  const curveData = useMemo(() => {
    const d = curve.data;
    if (!d || d.error || !d.rows.length) return null;
    // Still `minute`, at every grain — the server keeps the bucket column's name
    // fixed on purpose so this lookup does not have to guess at it, and reports
    // the grain in its own field instead.
    const iM = col(d, "minute");
    const iP = col(d, "peak");
    const iA = col(d, "average");
    const secs = shownGrain?.seconds ?? 60;
    return {
      // The label format follows the grain. Time-only is right at minute grain —
      // the date is in the window selector, and repeating it on every tick
      // leaves no room for the ticks themselves — and wrong the moment a bucket
      // is a whole day, when every tick would read 00:00. See bucketLabel.
      labels: d.rows.map((r) => bucketLabel(asStr(r[iM]), secs)),
      stamps: d.rows.map((r) => asStr(r[iM])),
      peak: d.rows.map((r) => asNum(r[iP])),
      average: d.rows.map((r) => asNum(r[iA]) ?? 0),
    };
  }, [curve.data, shownGrain]);

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
    // Mean of the per-bucket time-weighted averages, which for equal-length
    // buckets IS the window's time-weighted average. Not a mean of peaks, which
    // would be meaningless.
    //
    // Coarsening the grain does not change this figure's meaning, because each
    // bucket's average is time-weighted within itself: an hour's average is the
    // mean of its minutes' averages. It does soften one edge — a window that
    // starts or ends mid-bucket contributes a short bucket weighted as a whole
    // one, which is negligible over 761 minutes and visible over two days. The
    // per-bucket figures the server computed are exact either way; this is the
    // one number on the page the browser reduces, and the reduction is a mean.
    const avg =
      curveData.average.reduce((a, b) => a + b, 0) / curveData.average.length;
    return { peak: peak as number | null, peakAt, avg, buckets: curveData.peak.length };
  }, [curveData]);

  const exactPeak = curve.data?.mask?.exact_peak ?? true;

  // Predicted from the resolved window and the SELECTED grain, so the note lands
  // with the click rather than after the response it is warning about.
  const pendingBuckets = bucketsInWindow(bounds, grain?.seconds);

  // Singular of whatever the server called the grain: "minute", "hour", "day".
  const unit = (shownGrain?.label ?? "Minute").toLowerCase();

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

          {/* Window, range and interval on one row.

              These were two rows of pill buttons — three windows above, three
              grains below — which came to eight boxes in the page's own accent
              styling before the reader reached the curve. The dataset picker in
              the nav is already a select, so three different treatments were
              competing to look like the primary control and the actual answer
              was pushed down the page.

              The dataset is picked in the nav because it applies to every page.
              These are picked here because they do not. */}
          <RangePicker
            windows={db.windows}
            presetKey={custom ? CUSTOM : (win?.key ?? "")}
            from={bounds?.from ?? ""}
            to={bounds?.to ?? ""}
            onPreset={(k) => {
              // Choosing a preset drops the typed range entirely rather than
              // copying the preset's instants into it. A relative window like
              // "last hour" has to stay relative — frozen into two absolute
              // fields it would stop tracking the clock the moment it was
              // selected, which is the one thing that window is for.
              setCustom(null);
              setWinKey(k);
            }}
            onFrom={(v) =>
              setCustom({ from: v, to: custom?.to ?? bounds?.to ?? "" })
            }
            onTo={(v) =>
              setCustom({ from: custom?.from ?? bounds?.from ?? "", to: v })
            }
          />

          <div className="flex flex-wrap items-center gap-x-5 gap-y-2">
            <GrainPicker
              grains={grains}
              value={grain?.key ?? null}
              onChange={setGrainKey}
            />

            {/* The resolved bounds, right-aligned. This is the row's evidence:
                a relative window like "last hour" is only checkable against the
                absolute instants it turned into, and a typed range is only
                checkable against the seconds the fields do not show. */}
            {bounds ? (
              <span className="tnum ml-auto font-mono text-[0.6875rem] text-ink-3">
                {bounds.from} → {bounds.to} UTC
              </span>
            ) : null}
          </div>

          {/* Its own line: it is a sentence, and wrapping a sentence around a
              timestamp reads badly. */}
          <GrainNote buckets={pendingBuckets} />
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
                      ? // The invariance is worth stating rather than leaving to
                        // be discovered: coarsening the grain does not move this
                        // number, because the peak of an hour is the maximum of
                        // its minutes' peaks. Only the average rescales, and a
                        // reader who expects both to move will distrust the one
                        // that does not.
                        `Exact maximum inside a single ${unit}, at ${stamp(headline.peakAt)} UTC. Unchanged by the grain — a coarser bucket takes the maximum of the finer ones.`
                      : curve.data?.mask?.why
                  }
                />
                <Readout
                  label="Time-weighted avg"
                  value={decimal(headline.avg)}
                  hint={`Mean of the per-${unit} time-weighted averages over this window.`}
                />
                <Readout
                  label={grainPlural(shownGrain)}
                  value={count(headline.buckets)}
                  tone="muted"
                  hint={`Buckets the serving tier has published in this window, at ${unit} grain.`}
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
              {/* shownGrain, not the picker: with keepPreviousData the control
                  leads the rows by one round trip, and a key that renames the
                  accent line to "peak in day" while it is still drawing minute
                  buckets is actively misleading about a number people quote. */}
              <ChartLegend
                withheldPeak={!exactPeak}
                bucket={bucketNoun}
              />
              <ConcurrencyLine
                labels={curveData.labels}
                peak={curveData.peak}
                average={curveData.average}
                bucket={bucketNoun}
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

        {/* Current state, below the history. Everything above this point is a
            window — a span with a from and a to — and this is the one panel that
            reports an instant, so it sits after them rather than among them. It
            owns its own frame; see the component for why. */}
        <LiveSessionsPanel state={live} query={barQ} />
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
