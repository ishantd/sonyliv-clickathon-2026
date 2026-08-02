/**
 * Number formatting, in one place.
 *
 * WHY A MODULE RATHER THAN toLocaleString AT EACH CALL SITE. This dashboard's
 * entire argument is quantitative — 8,192 rows against 13,945,916, 5 ms against
 * 476 — and a figure that renders two ways on two panels reads as two different
 * measurements. Centralising the rules is what lets a reader compare a number in
 * the header with a number in a table without having to check the units first.
 *
 * Every function here is pure and safe on null/undefined/NaN, because these
 * render mid-fetch, where the value genuinely is not known yet. An em dash is
 * what "not yet" looks like; "0" is a lie and "NaN" is a bug report.
 */

const grouped = new Intl.NumberFormat("en-US");
const compactFmt = new Intl.NumberFormat("en-US", {
  notation: "compact",
  maximumFractionDigits: 1,
});

/** Placeholder for a value that is genuinely unknown, not zero. */
export const DASH = "—";

function bad(n: number | null | undefined): n is null | undefined {
  return n == null || !Number.isFinite(n);
}

/** A whole count, grouped: 8,192 · 13,945,916. */
export function count(n: number | null | undefined): string {
  return bad(n) ? DASH : grouped.format(Math.round(n));
}

/**
 * A count with the digits traded for width: 8.2K · 13.9M.
 *
 * Used only where the exact figure is also on screen or in a title. Row counts
 * are evidence here, and rounding evidence away in the one place it is shown
 * would defeat the point of showing it.
 */
export function compact(n: number | null | undefined): string {
  return bad(n) ? DASH : compactFmt.format(n);
}

/**
 * A duration given in milliseconds, at a precision that matches its size.
 *
 * Sub-10ms keeps a decimal because the difference between 4.9 and 9.4 is the
 * difference between one granule and two; above a second the decimals are noise.
 */
export function ms(v: number | null | undefined): string {
  if (bad(v)) return DASH;
  if (v < 1) return `${v.toFixed(2)} ms`;
  if (v < 10) return `${v.toFixed(1)} ms`;
  if (v < 1000) return `${Math.round(v)} ms`;
  return `${(v / 1000).toFixed(2)} s`;
}

/** Binary bytes, which is what ClickHouse's own counters report. */
export function bytes(n: number | null | undefined): string {
  if (bad(n)) return DASH;
  const units = ["B", "KiB", "MiB", "GiB", "TiB"];
  let v = n;
  let i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return `${i === 0 ? v : v.toFixed(v < 10 ? 1 : 0)} ${units[i]}`;
}

/**
 * A measured quantity with decimals: viewer-hours, time-weighted averages.
 *
 * Three places, matching the pipeline's own published figures (855.578199 is
 * reported as 855.578). Rounding to whole numbers here would make the
 * time-weighted average look like a session count, which is the one thing it is
 * not.
 */
export function decimal(n: number | null | undefined, places = 3): string {
  if (bad(n)) return DASH;
  return n.toLocaleString("en-US", {
    minimumFractionDigits: places,
    maximumFractionDigits: places,
  });
}

/** A percentage, for shares of a total. */
export function percent(part: number, whole: number): string {
  if (!whole || bad(part)) return DASH;
  const p = (part / whole) * 100;
  return `${p < 10 ? p.toFixed(1) : Math.round(p)}%`;
}

/** `HH:MM` out of a `YYYY-MM-DD HH:MM:SS` the server sent. */
export function clock(s: string | null | undefined): string {
  if (!s) return DASH;
  return s.length >= 16 ? s.slice(11, 16) : s;
}

/** `31 Jul 11:15` — enough to place an instant without a full timestamp. */
export function stamp(s: string | null | undefined): string {
  if (!s || s.length < 16) return DASH;
  const d = new Date(`${s.replace(" ", "T")}Z`);
  if (Number.isNaN(d.getTime())) return s;
  const day = d.getUTCDate();
  const month = d.toLocaleString("en-US", { month: "short", timeZone: "UTC" });
  return `${day} ${month} ${s.slice(11, 16)}`;
}
