"use client";

import { useId } from "react";
import type { Dimension, Filter } from "@/lib/analytics";
import { resolveRollup } from "@/lib/analytics";
import { count } from "@/lib/format";

/**
 * The dataset filters.
 *
 * WHY THESE SIX AND NOT AN ARBITRARY QUERY BUILDER. Each one maps to a dimension
 * the minute serving tier is actually rolled up by, which is what lets a filtered
 * question be answered by reading a few thousand pre-aggregated rows instead of
 * re-scanning the event stream. A filter on a dimension with no rollup would
 * still work and would still be fast to *write* — it would just quietly become a
 * full scan, which is the opposite of the thing this pipeline exists to
 * demonstrate.
 *
 * The list, the labels and the backing columns all come from the server. This
 * component renders whatever `dimensions` it is given; adding a seventh filter is
 * a change in Go and nothing here.
 *
 * WHAT HAPPENS WHEN A COMBINATION HAS NO ROLLUP is the part worth reading. Not
 * every pair of dimensions is materialised. Rather than silently answering from a
 * finer grain — where the maximum is the busiest single combination and not the
 * peak of the slice you asked for — the bar says so before the request is made,
 * and the panels withhold the peak rather than estimating it.
 */

function DimensionControl({
  dimension,
  value,
  values,
  onChange,
}: {
  dimension: Dimension;
  value: string;
  values: string[] | undefined;
  onChange: (v: string) => void;
}) {
  const listId = useId();
  const loading = values === undefined;
  // Title carries hundreds of values in a busy window. A select with that many
  // options is a scroll, not a control, so the high-cardinality dimension gets a
  // typeahead and the rest get the simpler affordance. `list` is the native one:
  // no portal, so it cannot be clipped by a scrolling ancestor the way an
  // absolutely-positioned menu would be.
  const typeahead = (values?.length ?? 0) > 40;

  const label = (
    <span className="mb-1 flex items-baseline gap-1.5">
      <span className="text-xs text-ink-2">{dimension.label}</span>
      {value ? (
        <button
          type="button"
          onClick={() => onChange("")}
          className="text-[0.625rem] text-ink-3 transition-colors hover:text-accent"
          aria-label={`Clear the ${dimension.label} filter`}
        >
          clear
        </button>
      ) : null}
    </span>
  );

  return (
    <label
      className="block min-w-0"
      title={`Backed by ${dimension.source}. Rolled up as the “${dimension.grouping}” grouping.`}
    >
      {label}
      {typeahead ? (
        <>
          <input
            type="search"
            value={value}
            list={listId}
            placeholder={loading ? "loading…" : `any (${count(values?.length)})`}
            onChange={(e) => onChange(e.target.value)}
            className={value ? "!border-accent-dim" : undefined}
          />
          <datalist id={listId}>
            {(values ?? []).map((v) => (
              <option key={v} value={v} />
            ))}
          </datalist>
        </>
      ) : (
        <select
          value={value}
          onChange={(e) => onChange(e.target.value)}
          disabled={loading}
          className={value ? "!border-accent-dim" : undefined}
        >
          <option value="">{loading ? "loading…" : "any"}</option>
          {(values ?? []).map((v) => (
            <option key={v} value={v}>
              {v}
            </option>
          ))}
        </select>
      )}
    </label>
  );
}

export function FilterBar({
  dimensions,
  values,
  filter,
  onChange,
  rollups,
  cappedAt,
}: {
  dimensions: Dimension[];
  values: Record<string, string[]> | undefined;
  filter: Filter;
  onChange: (next: Filter) => void;
  rollups: Record<string, string> | undefined;
  cappedAt?: number;
}) {
  const active = dimensions.filter((d) => filter[d.key]);
  const resolved = resolveRollup(rollups, Object.keys(filter).filter((k) => filter[k]));

  function set(key: string, v: string) {
    const next = { ...filter };
    if (v) next[key] = v;
    else delete next[key];
    onChange(next);
  }

  return (
    <section
      aria-label="Dataset filters"
      className="rounded-lg border border-line bg-panel p-4"
    >
      <div className="mb-3 flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
        <h2 className="eyebrow text-ink-3">Filters</h2>
        <p className="text-[0.6875rem] text-ink-3">
          Applied to the curve and to every breakdown below.
        </p>
      </div>

      <div className="grid grid-cols-[repeat(auto-fit,minmax(9.5rem,1fr))] gap-3">
        {dimensions.map((d) => (
          <DimensionControl
            key={d.key}
            dimension={d}
            value={filter[d.key] ?? ""}
            values={values?.[d.key]}
            onChange={(v) => set(d.key, v)}
          />
        ))}
      </div>

      {/* The resolved rollup, stated BEFORE a panel renders.
          A reader who watches the peak vanish after choosing a second filter will
          assume the pipeline broke. Saying which combinations are materialised at
          the moment of choosing turns that into an understood limit. */}
      <div className="mt-3 flex flex-wrap items-center gap-x-3 gap-y-2 border-t border-line-soft pt-3 text-[0.6875rem]">
        {active.length ? (
          <>
            <span className="text-ink-3">Filtering</span>
            {active.map((d) => (
              <button
                key={d.key}
                type="button"
                onClick={() => set(d.key, "")}
                title={`Remove the ${d.label} filter`}
                className="group flex items-center gap-1.5 rounded border border-accent-dim bg-accent-wash px-2 py-0.5 text-accent transition-colors hover:border-accent"
              >
                <span className="text-ink-3">{d.label}</span>
                <span className="font-mono">{filter[d.key]}</span>
                <span aria-hidden className="text-ink-3 group-hover:text-accent">
                  ×
                </span>
              </button>
            ))}
            <button
              type="button"
              onClick={() => onChange({})}
              className="text-ink-3 underline-offset-2 transition-colors hover:text-ink-2 hover:underline"
            >
              Clear all
            </button>
          </>
        ) : (
          <span className="text-ink-3">
            No filter — the curve is the whole dataset, read from the{" "}
            <span className="font-mono">total</span> rollup.
          </span>
        )}

        <span className="ml-auto flex items-center gap-1.5">
          <span className="text-ink-3">resolves to</span>
          <span className={`font-mono ${resolved.exact ? "text-ink-2" : "text-accent"}`}>
            {resolved.grouping}
          </span>
        </span>
      </div>

      {!resolved.exact ? (
        <p className="mt-2 border-l border-accent-dim pl-2.5 text-[0.6875rem] leading-relaxed text-ink-2">
          This combination is not materialised as its own rollup, so the peak is
          withheld rather than estimated — the maximum over a finer grain is the
          busiest single combination, not the peak of this slice. Viewer-hours and
          the time-weighted average stay exact, because they are additive.
        </p>
      ) : null}

      <details className="group mt-2.5">
        <summary className="flex cursor-pointer list-none items-center gap-1.5 text-[0.6875rem] text-ink-3 transition-colors hover:text-ink-2 [&::-webkit-details-marker]:hidden">
          <span
            aria-hidden
            className="inline-block transition-transform duration-150 group-open:rotate-90"
          >
            ›
          </span>
          Which dataset column backs each filter
        </summary>
        <dl className="mt-2 grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-[0.6875rem]">
          {dimensions.map((d) => (
            <div key={d.key} className="contents">
              <dt className="text-ink-3">{d.label}</dt>
              <dd className="min-w-0 font-mono break-words text-ink-2">
                {d.source}
                <span className="text-ink-3">
                  {" "}
                  → serving_minute_current.{d.column}
                </span>
              </dd>
            </div>
          ))}
        </dl>
        {cappedAt ? (
          <p className="mt-2 text-[0.6875rem] leading-relaxed text-ink-3">
            Values are read from the selected window, ranked by viewer-hours and
            capped at {count(cappedAt)} per dimension — so a filter never offers a
            value that would produce an empty chart.
          </p>
        ) : null}
      </details>
    </section>
  );
}
