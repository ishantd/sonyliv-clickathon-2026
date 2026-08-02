"use client";

import type { Grain } from "@/lib/analytics";

/**
 * The time granularity the curve is bucketed at.
 *
 * A SELECT, NOT A ROW OF BUTTONS. This started as buttons on the reasoning that
 * a short fixed list should be readable without opening anything. That was the
 * wrong trade once it sat under the window control, which is also a short fixed
 * list: the two together were eight boxes across two rows, all in the same
 * border-and-pill styling, and the page's most important control — the dataset —
 * is a select in the nav. Three visually identical treatments for three
 * different kinds of choice is not a hierarchy, it is noise, and it pushed the
 * curve below the fold.
 *
 * Two selects on one line say the same thing in one row and match the nav. The
 * cost is that the unselected options are hidden until you open it; for three
 * units of time that costs nothing, because nobody needs to be told that the
 * alternatives to "Minute" are "Hour" and "Day".
 *
 * The list still comes from the server. Minute/hour/day is a fact about what the
 * serving tier can bucket to, not a preference of this page, and a fourth grain
 * added in Go should appear here without a second edit.
 *
 * Renders the label and the control only. The sparse-window note is a separate
 * export because it is a sentence and belongs on its own line, not wedged into a
 * row that already ends in a timestamp.
 */
export function GrainPicker({
  grains,
  value,
  onChange,
}: {
  grains: Grain[];
  /** The selected grain's key, or null before the list has loaded. */
  value: string | null;
  onChange: (key: string) => void;
}) {
  // Nothing to pick means no control. A server that predates the grains field
  // sends none, and a single grain is furniture rather than a choice — the same
  // rule the dataset picker applies to a one-dataset deployment. This is the
  // whole of the "Go has not shipped yet" handling: the page renders as it did
  // before the feature existed.
  if (grains.length < 2) return null;

  return (
    <label className="flex shrink-0 items-center gap-2">
      <span className="eyebrow text-ink-3">Grain</span>
      <select
        value={value ?? ""}
        onChange={(e) => onChange(e.target.value)}
        aria-label="Time granularity"
        title="Bucket the curve into minutes, hours or days. The peak is unchanged by this — the peak of an hour is the maximum of its minutes' peaks — only the average rescales."
        className="rounded border border-line bg-sunken px-2 py-1 text-[0.8125rem] text-ink-2 transition-colors hover:text-ink focus:border-accent-dim focus:outline-none"
      >
        {grains.map((g) => (
          <option key={g.key} value={g.key}>
            {g.label}
          </option>
        ))}
      </select>
    </label>
  );
}

/**
 * "This window is too short to draw at this grain."
 *
 * Separate from the picker so it can sit on its own line. Three is the point at
 * which a line is a line: two points draw a segment and one draws nothing at
 * all, and the reader should be told that BEFORE they conclude the dataset is
 * empty.
 *
 * Not an error and not styled as one. A day-grain reading of a one-hour window
 * is a legitimate thing to ask for, and a single number for the day is
 * legitimately what comes back. Nothing is disabled.
 */
export function GrainNote({ buckets }: { buckets: number | null }) {
  if (buckets == null || buckets >= 3) return null;
  return (
    <span className="max-w-[64ch] text-[0.6875rem] leading-snug text-ink-3" role="note">
      {buckets === 1
        ? "One bucket in this window — a point, not a curve."
        : `${buckets} buckets in this window — too few to read as a curve.`}{" "}
      The figures are still exact; widen the window or pick a finer grain to see
      the shape.
    </span>
  );
}
