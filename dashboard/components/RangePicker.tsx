"use client";

import type { Window } from "@/lib/analytics";

/**
 * The window: a preset dropdown and two datetime fields that agree with it.
 *
 * WHY BOTH AND NOT JUST THE FIELDS. The presets are not convenience — they are
 * the only thing on this page that knows where each dataset's data actually
 * lives. The evaluation set's traffic is one hour on 31 July; the tuning
 * extract's is a different hour on 26 July; the demo database's is the last few
 * minutes. Someone handed two empty datetime boxes on a dataset they have never
 * seen has to guess a date to find any data at all, and every wrong guess draws
 * an empty chart that reads as a broken pipeline.
 *
 * WHY NOT JUST THE PRESETS. Because "show me 10:40 to 10:50" is a real question
 * and a fixed list cannot answer it. Picking a preset fills the fields; editing
 * a field switches the dropdown to Custom and keeps whatever is typed. Neither
 * control is subordinate — they are two views of one range.
 *
 * EVERYTHING HERE IS UTC, and `datetime-local` has no timezone at all. So the
 * value in the box is read as UTC rather than as the reader's own clock: a
 * judge in IST typing 11:15 means the 11:15 the peak is at, not 05:45. That is
 * the opposite of what the input's name suggests, which is exactly why the label
 * says UTC and why the resolved bounds are printed beside it — the one place a
 * timezone error would be silent is the one place it is spelled out.
 */

/** `YYYY-MM-DD HH:MM:SS` (what the API takes) -> `YYYY-MM-DDTHH:MM` (what the input takes). */
export function toInputValue(s: string): string {
  return s.replace(" ", "T").slice(0, 16);
}

/** The reverse. Seconds are appended rather than parsed: the input has none. */
export function fromInputValue(s: string): string {
  if (!s) return "";
  return `${s.replace("T", " ")}:00`.slice(0, 19);
}

/** Marks the dropdown when the fields no longer match any preset. */
export const CUSTOM = "__custom__";

export function RangePicker({
  windows,
  presetKey,
  from,
  to,
  onPreset,
  onFrom,
  onTo,
}: {
  windows: Window[];
  /** The selected preset's key, or CUSTOM once the fields have been edited. */
  presetKey: string;
  /** Both in API form, `YYYY-MM-DD HH:MM:SS`. */
  from: string;
  to: string;
  onPreset: (key: string) => void;
  onFrom: (v: string) => void;
  onTo: (v: string) => void;
}) {
  // A range whose end is not after its start returns nothing and the server
  // rejects it outright, so say so here rather than letting an empty chart
  // stand in for the explanation.
  const inverted =
    from !== "" && to !== "" && !(Date.parse(`${from.replace(" ", "T")}Z`) < Date.parse(`${to.replace(" ", "T")}Z`));

  const field = (
    label: string,
    value: string,
    onChange: (v: string) => void,
  ) => (
    <label className="flex shrink-0 items-center gap-1.5">
      <span className="eyebrow text-ink-3">{label}</span>
      <input
        type="datetime-local"
        // Seconds are not exposed. The serving tier's floor is a minute, so a
        // second in this box could never change the answer, and a field that
        // accepts a value it cannot honour is a worse control than one that
        // does not offer it.
        step={60}
        value={toInputValue(value)}
        onChange={(e) => onChange(fromInputValue(e.target.value))}
        className={`rounded border bg-sunken px-2 py-1 font-mono text-[0.75rem] text-ink-2 transition-colors hover:text-ink focus:border-accent-dim focus:outline-none ${
          inverted ? "border-bad" : "border-line"
        }`}
      />
    </label>
  );

  return (
    <div className="flex flex-col gap-2">
      <div className="flex flex-wrap items-center gap-x-5 gap-y-2">
        <label className="flex shrink-0 items-center gap-2">
          <span className="eyebrow text-ink-3">Window</span>
          <select
            value={presetKey}
            onChange={(e) => onPreset(e.target.value)}
            aria-label="Time window"
            className="rounded border border-line bg-sunken px-2 py-1 text-[0.8125rem] text-ink-2 transition-colors hover:text-ink focus:border-accent-dim focus:outline-none"
          >
            {windows.map((w) => (
              <option key={w.key} value={w.key}>
                {w.label}
              </option>
            ))}
            {/* Present only once it applies. An always-visible "Custom" that
                does nothing when chosen is a dead option in a live menu. */}
            {presetKey === CUSTOM ? <option value={CUSTOM}>Custom</option> : null}
          </select>
        </label>

        {field("From", from, onFrom)}
        {field("To", to, onTo)}

        <span className="ml-auto shrink-0 font-mono text-[0.6875rem] text-ink-3">
          UTC
        </span>
      </div>

      {inverted ? (
        <span className="text-[0.6875rem] text-bad" role="alert">
          From must be before To — the range is empty as entered, so the panels
          below are still showing the last valid one.
        </span>
      ) : null}
    </div>
  );
}
