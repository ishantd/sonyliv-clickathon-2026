import type { ReactNode } from "react";

/**
 * Shared primitives. These exist so spacing and colour decisions live in one
 * place — the failure mode with Tailwind on a multi-page tool is two panels that
 * differ by 2px because two files each spelled out their own padding.
 */

export function Panel({
  title,
  children,
  accent = "accent",
  className = "",
}: {
  title?: string;
  children: ReactNode;
  /** Left rule colour. Semantic, so a panel can read as live or as a warning. */
  accent?: "accent" | "live" | "bad" | "none";
  className?: string;
}) {
  const rule = {
    accent: "border-l-accent-dim",
    live: "border-l-live",
    bad: "border-l-bad",
    none: "border-l-line",
  }[accent];

  return (
    <section
      className={`rounded border border-line border-l-2 bg-panel p-4 ${rule} ${className}`}
    >
      {title && <h2 className="eyebrow mb-3 text-accent">{title}</h2>}
      {children}
    </section>
  );
}

export function Field({
  label,
  hint,
  children,
}: {
  label: string;
  hint?: string;
  children: ReactNode;
}) {
  return (
    <label className="block">
      <span className="mb-1 block text-xs text-ink-2">{label}</span>
      {children}
      {hint && (
        <span className="mt-1 block text-[0.6875rem] leading-snug text-ink-3">
          {hint}
        </span>
      )}
    </label>
  );
}

export function Button({
  children,
  variant = "default",
  ...rest
}: React.ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: "default" | "primary" | "danger";
}) {
  const styles = {
    default: "border-line bg-sunken text-ink hover:border-accent",
    primary:
      "border-accent bg-accent text-[#1a1305] font-semibold hover:brightness-110",
    danger: "border-bad/60 bg-sunken text-bad hover:border-bad",
  }[variant];

  return (
    <button
      {...rest}
      className={`rounded border px-3 py-2 text-[0.8125rem] transition-colors disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:border-line ${styles} ${rest.className ?? ""}`}
    >
      {children}
    </button>
  );
}

/**
 * One measurement. `tone` encodes state in form as well as number, so what needs
 * attention reads at a glance rather than requiring the label to be read.
 */
export function Stat({
  label,
  value,
  tone = "plain",
}: {
  label: string;
  value: ReactNode;
  tone?: "plain" | "live" | "bad" | "muted";
}) {
  const color = {
    plain: "text-ink",
    live: "text-live",
    bad: "text-bad",
    muted: "text-ink-3",
  }[tone];

  return (
    <div className="rounded border border-line bg-sunken px-2.5 py-2">
      <div className="eyebrow text-ink-3">{label}</div>
      <div className={`tnum mt-0.5 font-mono text-base ${color}`}>{value}</div>
    </div>
  );
}

export function StatGrid({ children }: { children: ReactNode }) {
  return (
    <div className="grid grid-cols-[repeat(auto-fit,minmax(7rem,1fr))] gap-2">
      {children}
    </div>
  );
}

/** A boolean rendered as a state, not as the word "true". */
export function Flag({
  on,
  onLabel,
  offLabel,
}: {
  on: boolean;
  onLabel: string;
  offLabel: string;
}) {
  return (
    <span className={on ? "text-live" : "text-ink-3"}>
      {on ? onLabel : offLabel}
    </span>
  );
}

export function ErrorNote({ error }: { error: unknown }) {
  if (!error) return null;
  const msg = error instanceof Error ? error.message : String(error);
  return (
    <p className="mt-3 rounded border border-bad/40 bg-bad-wash px-2.5 py-2 font-mono text-xs whitespace-pre-wrap text-bad">
      {msg}
    </p>
  );
}

/**
 * A claim the reader must not mistake for the served answer. Used for the live
 * curve, which is an approximation and says so.
 */
export function Caveat({ children }: { children: ReactNode }) {
  return (
    <p className="mt-3 border-l-2 border-accent-dim pl-2.5 text-xs leading-relaxed text-ink-3">
      {children}
    </p>
  );
}
