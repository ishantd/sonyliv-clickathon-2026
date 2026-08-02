"use client";

import {
  BarElement,
  CategoryScale,
  Chart as ChartJS,
  Filler,
  Legend,
  LinearScale,
  LineElement,
  PointElement,
  Tooltip,
  type Chart,
  type ChartOptions,
  type Plugin,
} from "chart.js";
import { Bar, Line } from "react-chartjs-2";
import { count, decimal } from "@/lib/format";

/*
 * Chart.js, and why here when CurveChart is hand-rolled SVG.
 *
 * CurveChart's own comment gives the rule: "one series, no interaction beyond a
 * hover readout, and pulling in a chart package for that would be more bytes than
 * the whole app." That rule still holds for the live curve, which is why it is
 * untouched.
 *
 * It stops holding here. These panels are multi-series lines, ranked bars with
 * value labels, and hover readouts across seven charts of two types. Hand-authoring
 * axis ticks and a shared tooltip for each of them is how you end up with a chart
 * library anyway, written worse and without tests.
 *
 * Only the components used are registered. Chart.js ships every controller,
 * scale and plugin, and the default `Chart.register(...registerables)` pulls all
 * of them into the bundle — including the radial scales and the doughnut
 * controller nothing here draws.
 */
ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  Filler,
  Tooltip,
  Legend,
);

/*
 * Tokens read from globals.css rather than re-picked here. Chart.js draws to a
 * canvas, so it cannot inherit CSS custom properties the way the SVG charts do —
 * the values have to be passed in, and duplicating them is the one thing that
 * would let the charts drift from the rest of the UI.
 *
 * THE BLUE IS GONE, deliberately. These charts used to distinguish their second
 * series with #5b9dd9, which broke the system's one standing rule: SonyLIV's
 * surface carries a single non-neutral, and hierarchy is carried by FORM — fill
 * against outline, solid against dashed, weight — never by inventing a hue. The
 * second series is now white and dashed, which is the brand's own gold-over-white
 * hierarchy and reads correctly on a projector, in a screenshot, and to a reader
 * who cannot separate blue from grey.
 */
const INK = "#ffffff";
const INK_2 = "#aaaaaa";
const INK_3 = "#8a8a8a";
const LINE = "#2e2e2e";
const GRID = "#1c1c1c";
const PANEL = "#141414";
const ACCENT = "#ffa800";
const ACCENT_WASH = "rgba(255, 168, 0, 0.14)";

/** Shared axis/legend styling, so seven charts cannot each look slightly different. */
function base(): ChartOptions<"line" | "bar"> {
  return {
    responsive: true,
    maintainAspectRatio: false,
    // A dashboard that re-animates on every poll is unreadable, and these panels
    // refetch on a window or filter change. Motion here would be decoration, not
    // state.
    animation: false,
    interaction: { mode: "index", intersect: false },
    plugins: {
      legend: { display: false },
      tooltip: {
        backgroundColor: PANEL,
        borderColor: LINE,
        borderWidth: 1,
        titleColor: INK,
        bodyColor: INK_2,
        padding: 8,
        displayColors: true,
        usePointStyle: true,
      },
    },
    scales: {
      x: {
        ticks: { color: INK_3, maxRotation: 0, autoSkipPadding: 16 },
        grid: { color: GRID },
        border: { color: LINE },
      },
      y: {
        beginAtZero: true,
        ticks: { color: INK_3, callback: (v) => count(Number(v)) },
        grid: { color: GRID },
        border: { color: LINE },
      },
    },
  };
}

/**
 * Marks the maximum of the peak series on the plot itself.
 *
 * The peak is the number this whole page exists to report, and making a reader
 * find it by eye on a sixty-point line — then cross-reference the x axis to learn
 * when it happened — is asking them to do the chart's job. Drawn as a hairline
 * drop to the axis with the value set above it: no callout box, no leader line,
 * nothing that would need a z-order.
 *
 * A plugin rather than a second dataset, because a one-point dataset would appear
 * in the legend and in every tooltip.
 */
function peakMarker(label: string): Plugin<"line"> {
  return {
    id: "peakMarker",
    afterDatasetsDraw(chart: Chart<"line">) {
      const meta = chart.getDatasetMeta(0);
      if (!meta || meta.hidden) return;
      const data = chart.data.datasets[0]?.data as (number | null)[] | undefined;
      if (!data?.length) return;

      let best = -1;
      let bestVal = -Infinity;
      for (let i = 0; i < data.length; i++) {
        const v = data[i];
        if (v != null && v > bestVal) {
          bestVal = v;
          best = i;
        }
      }
      if (best < 0) return;

      const point = meta.data[best];
      if (!point) return;
      const { ctx, chartArea } = chart;
      const x = point.x;
      const y = point.y;

      ctx.save();
      ctx.strokeStyle = ACCENT;
      ctx.globalAlpha = 0.45;
      ctx.setLineDash([2, 3]);
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x, chartArea.bottom);
      ctx.stroke();

      ctx.setLineDash([]);
      ctx.globalAlpha = 1;
      ctx.fillStyle = ACCENT;
      ctx.beginPath();
      ctx.arc(x, y, 3, 0, Math.PI * 2);
      ctx.fill();

      const text = `${label} ${count(bestVal)}`;
      ctx.font =
        '600 11px ui-sans-serif, -apple-system, system-ui, "Segoe UI", Roboto, sans-serif';
      const width = ctx.measureText(text).width;
      // Flipped to the left near the right edge so the label never runs off the
      // plot — measured, not guessed at with a fixed margin.
      const left = x + 8 + width > chartArea.right ? x - 8 - width : x + 8;
      ctx.fillStyle = ACCENT;
      ctx.textBaseline = "middle";
      ctx.fillText(text, left, Math.max(chartArea.top + 8, y - 10));
      ctx.restore();
    },
  };
}

/**
 * The concurrency chart's key, drawn in the DOM rather than on the canvas.
 *
 * Each swatch is the line it stands for: the same stroke, the same dash pattern,
 * the same fill. A key whose samples do not match the marks they name is worse
 * than no key, and a canvas legend cannot draw a 2px dashed rule at this size
 * without it collapsing into a dot.
 */
export function ChartLegend({
  withheldPeak = false,
  bucket = "minute",
}: {
  withheldPeak?: boolean;
  /**
   * The singular noun for one bucket on the x-axis — "minute", "hour", "day".
   *
   * Passed in rather than assumed, because the series is no longer always at
   * minute grain. A key reading "peak in minute" over hour buckets is not a
   * cosmetic slip: peak and average differ by roughly 2.7x over the hot hour, so
   * a reader who believes the accent line is a per-minute maximum when it is a
   * per-hour one has been told the wrong thing about the number they are
   * quoting.
   */
  bucket?: string;
}) {
  return (
    <ul className="flex flex-wrap items-center gap-x-4 gap-y-1 text-[0.6875rem] text-ink-2">
      <li className="flex items-center gap-1.5">
        <svg width="26" height="8" aria-hidden className="shrink-0">
          <rect x="0" y="3" width="26" height="5" fill={ACCENT_WASH} />
          <line x1="0" y1="3" x2="26" y2="3" stroke={ACCENT} strokeWidth="1.5" />
        </svg>
        <span className={withheldPeak ? "text-ink-3 line-through" : undefined}>
          peak in {bucket}
        </span>
        {withheldPeak ? (
          <span className="text-accent">withheld at this rollup</span>
        ) : null}
      </li>
      <li className="flex items-center gap-1.5">
        <svg width="26" height="8" aria-hidden className="shrink-0">
          <line
            x1="0"
            y1="4"
            x2="26"
            y2="4"
            stroke={INK}
            strokeWidth="1.5"
            strokeDasharray="4 3"
          />
        </svg>
        <span>time-weighted average</span>
      </li>
    </ul>
  );
}

/**
 * Peak and time-weighted average concurrency on one pair of axes.
 *
 * Both series, deliberately. They differ by ~2.7× over the same hour — peak 2,305
 * against an average of 855.58 — so a chart showing one invites the other to be
 * guessed from it. Peak is the filled gold series because it is the headline
 * number; the average is drawn over it, white and dashed, since its job is to
 * show how much of that peak was sustained.
 *
 * `peak` may be all-null: a filter combination with no materialised rollup cannot
 * carry an exact peak, and the server sends null rather than a number it would
 * have had to estimate. The chart then draws the average alone rather than
 * plotting a gap and letting it read as an outage.
 */
export function ConcurrencyLine({
  labels,
  peak,
  average,
  height = 340,
  bucket = "minute",
}: {
  labels: string[];
  peak: (number | null)[];
  average: number[];
  height?: number;
  /**
   * Same noun as ChartLegend's, and it has to agree with it: this string is the
   * dataset label, which is what the hover tooltip prints. The legend and the
   * tooltip disagreeing about what a point means is worse than either being
   * wrong on its own.
   */
  bucket?: string;
}) {
  const opts = base() as ChartOptions<"line">;
  const hasPeak = peak.some((v) => v != null);

  const datasets = [
    {
      label: `peak in ${bucket}`,
      data: peak,
      borderColor: ACCENT,
      backgroundColor: ACCENT_WASH,
      fill: true,
      borderWidth: 1.5,
      pointRadius: 0,
      pointHoverRadius: 3,
      pointHoverBackgroundColor: ACCENT,
      tension: 0.2,
      // A withheld peak is absent, not zero. Without this Chart.js would join the
      // points either side of a null and draw a line through data that does not
      // exist.
      spanGaps: false,
    },
    {
      label: "time-weighted average",
      data: average,
      borderColor: INK,
      backgroundColor: "transparent",
      fill: false,
      borderWidth: 1.5,
      pointRadius: 0,
      pointHoverRadius: 3,
      pointHoverBackgroundColor: INK,
      tension: 0.2,
      borderDash: [4, 3],
    },
  ];

  return (
    <div style={{ height }}>
      <Line
        plugins={hasPeak ? [peakMarker("peak")] : []}
        options={{
          ...opts,
          plugins: {
            ...opts.plugins,
            // Chart.js's own legend is off, and ChartLegend below replaces it.
            // Canvas legends cannot use the app's type or spacing tokens, cannot
            // wrap the way the rest of the panel header does, and — the reason
            // this was actually changed — cannot draw a swatch that shows a dash
            // pattern at 11px, which left two visually identical entries beside
            // two visually different lines.
            legend: { display: false },
            tooltip: {
              ...opts.plugins?.tooltip,
              callbacks: {
                label: (c) =>
                  `${c.dataset.label}: ${
                    c.parsed.y == null
                      ? "withheld at this rollup"
                      : c.datasetIndex === 1
                        ? decimal(c.parsed.y)
                        : count(c.parsed.y)
                  }`,
              },
            },
          },
        }}
        data={{ labels, datasets }}
      />
    </div>
  );
}

/**
 * A ranked horizontal bar.
 *
 * Horizontal because the labels are platform names, titles and category codes —
 * rotated vertical labels are unreadable and the alternative, truncating them,
 * loses the thing the bar identifies.
 *
 * `variant` separates the two quantities by FORM rather than by hue, which is the
 * rule this system runs on. A filled bar is a count of sessions; an outlined one
 * is viewer-hours. That distinction matters more than it looks: the filled bars
 * are peaks and must not be added together, the outlined ones are additive.
 */
export function RankedBar({
  labels,
  values,
  label,
  height = 280,
  variant = "fill",
  decimals = false,
}: {
  labels: string[];
  values: (number | null)[];
  label: string;
  height?: number;
  variant?: "fill" | "outline";
  decimals?: boolean;
}) {
  const opts = base() as ChartOptions<"bar">;
  return (
    <div style={{ height }}>
      <Bar
        options={{
          ...opts,
          indexAxis: "y",
          plugins: {
            ...opts.plugins,
            tooltip: {
              ...opts.plugins?.tooltip,
              callbacks: {
                label: (c) =>
                  `${label}: ${
                    c.parsed.x == null
                      ? "withheld at this rollup"
                      : decimals
                        ? decimal(c.parsed.x)
                        : count(c.parsed.x)
                  }`,
              },
            },
          },
          scales: {
            x: {
              ...opts.scales?.x,
              beginAtZero: true,
              ticks: { color: INK_3, callback: (v) => count(Number(v)) },
            },
            y: {
              ...opts.scales?.y,
              grid: { display: false },
              ticks: { color: INK_2, font: { size: 11 } },
            },
          },
        }}
        data={{
          labels,
          datasets: [
            {
              label,
              data: values,
              backgroundColor: variant === "fill" ? ACCENT : "transparent",
              borderColor: ACCENT,
              borderWidth: variant === "fill" ? 0 : 1,
              borderRadius: 2,
              // Bars stay legible rather than becoming a solid block when a
              // breakdown returns fifteen rows in a 280px panel.
              maxBarThickness: 22,
            },
          ],
        }}
      />
    </div>
  );
}
