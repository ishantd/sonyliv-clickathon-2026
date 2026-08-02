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
  type ChartOptions,
} from "chart.js";
import { Bar, Line } from "react-chartjs-2";

/*
 * Chart.js, and why here when CurveChart is hand-rolled SVG.
 *
 * CurveChart's own comment gives the rule: "one series, no interaction beyond a
 * hover readout, and pulling in a chart package for that would be more bytes than
 * the whole app." That rule still holds for the live curve, which is why it is
 * untouched.
 *
 * It stops holding here. These panels are multi-series lines, ranked bars with
 * value labels, and hover readouts across six charts of three different types.
 * Hand-authoring axis ticks and a shared tooltip for each of them is how you end
 * up with a chart library anyway, written worse and without tests.
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

// Tokens read from globals.css rather than re-picked here. Chart.js draws to a
// canvas, so it cannot inherit CSS custom properties the way the SVG charts do —
// the values have to be passed in, and duplicating them is the one thing that
// would let the charts drift from the rest of the UI.
const INK = "#aaaaaa";
const INK_3 = "#8a8a8a";
const LINE = "#2e2e2e";
const ACCENT = "#ffa800";
const ACCENT_WASH = "rgba(255, 168, 0, 0.16)";
const COOL = "#5b9dd9";
const COOL_WASH = "rgba(91, 157, 217, 0.14)";

/** Shared axis/legend styling, so six charts cannot each look slightly different. */
function base(): ChartOptions<"line" | "bar"> {
  return {
    responsive: true,
    maintainAspectRatio: false,
    animation: false, // A dashboard that re-animates on every 10s poll is unreadable.
    interaction: { mode: "index", intersect: false },
    plugins: {
      legend: {
        display: false,
        labels: { color: INK, boxWidth: 10, boxHeight: 10 },
      },
      tooltip: {
        backgroundColor: "#141414",
        borderColor: LINE,
        borderWidth: 1,
        titleColor: "#ffffff",
        bodyColor: INK,
        padding: 8,
        displayColors: true,
      },
    },
    scales: {
      x: {
        ticks: { color: INK_3, maxRotation: 0, autoSkipPadding: 16 },
        grid: { color: "#1c1c1c" },
        border: { color: LINE },
      },
      y: {
        beginAtZero: true,
        ticks: { color: INK_3 },
        grid: { color: "#1c1c1c" },
        border: { color: LINE },
      },
    },
  };
}

/**
 * Peak and average concurrency on one pair of axes.
 *
 * Both series, deliberately. They differ by ~2.7x over the same hour — peak 2,305
 * against an average of 855.58 — so a chart showing one invites the other to be
 * guessed from it. Peak is the filled series because it is the headline number;
 * average is drawn over it, thinner, since its job is to show how much of the
 * peak was sustained.
 */
export function ConcurrencyLine({
  labels,
  peak,
  average,
  height = 260,
}: {
  labels: string[];
  peak: number[];
  average: number[];
  height?: number;
}) {
  const opts = base() as ChartOptions<"line">;
  return (
    <div style={{ height }}>
      <Line
        options={{
          ...opts,
          plugins: { ...opts.plugins, legend: { display: true, position: "top" } },
        }}
        data={{
          labels,
          datasets: [
            {
              label: "peak in minute",
              data: peak,
              borderColor: ACCENT,
              backgroundColor: ACCENT_WASH,
              fill: true,
              borderWidth: 1.5,
              pointRadius: 0,
              tension: 0.2,
            },
            {
              label: "time-weighted average",
              data: average,
              borderColor: COOL,
              backgroundColor: COOL_WASH,
              fill: false,
              borderWidth: 1.5,
              pointRadius: 0,
              tension: 0.2,
              borderDash: [4, 3],
            },
          ],
        }}
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
 */
export function RankedBar({
  labels,
  values,
  label,
  height = 260,
  cool = false,
}: {
  labels: string[];
  values: number[];
  label: string;
  height?: number;
  cool?: boolean;
}) {
  const opts = base() as ChartOptions<"bar">;
  return (
    <div style={{ height }}>
      <Bar
        options={{
          ...opts,
          indexAxis: "y",
          scales: {
            x: { ...opts.scales?.x, beginAtZero: true },
            y: { ...opts.scales?.y, grid: { display: false } },
          },
        }}
        data={{
          labels,
          datasets: [
            {
              label,
              data: values,
              backgroundColor: cool ? COOL_WASH : ACCENT_WASH,
              borderColor: cool ? COOL : ACCENT,
              borderWidth: 1,
              borderRadius: 2,
            },
          ],
        }}
      />
    </div>
  );
}
