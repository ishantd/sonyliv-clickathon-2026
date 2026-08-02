"use client";

import { PanelFrame } from "./PanelFrame";
import { asNum, asStr, col, usePanel, type PanelResponse } from "@/lib/analytics";
import { count } from "@/lib/format";

/**
 * Current per-platform session state, as a table.
 *
 * NOT A CHART, and that is a judgement about the data rather than about effort.
 * Every other breakdown on this page ranks one quantity across one dimension,
 * which is what a bar is for. This is five columns of different quantities in
 * different units — three counts and a duration — for one instant. Ranked
 * against each other they would be meaningless, and stacked they would imply an
 * additivity that open/active/terminated do not have.
 *
 * WHY THIS COMPONENT OWNS ITS PANELFRAME when the breakdowns are handed theirs.
 * It is the only panel on the page whose backing table does not exist in every
 * dataset, so the failure it has to render is not a failure at all — it is a
 * fact about the dataset. Owning the frame is what lets it decide, for its own
 * two absence cases, that the answer is an explanation rather than a red box.
 * Every other state — loading, empty, a real query error — is left to the frame,
 * because a panel that invented its own version of those would be the thing
 * PanelFrame exists to prevent.
 */

/**
 * Distinguishes "cannot be answered here" from "went wrong".
 *
 * Two shapes, because the two halves of this feature ship separately and each
 * has its own way of saying no:
 *
 *   - 404 / unknown panel — the Go service on this box predates the panel. The
 *     dashboard is built and deployed independently of the binary, so this is a
 *     normal state during a rollout and not worth alarming anyone about.
 *   - UNKNOWN_TABLE on a 200 — the panel is served, but the selected dataset has
 *     no live-sessions table. The fixed extracts do not; a dataset with a live
 *     rollup behind it does.
 *
 * Anything else is a genuine error and is returned as such, unclassified, so it
 * reaches PanelFrame's error path with its message intact. Matching on message
 * text is coarse, and it is deliberately biased the safe way: an unrecognised
 * message reads as an error, never as an absence.
 */
function absence(msg: string | undefined): "unserved" | "no-table" | null {
  if (!msg) return null;
  if (/unknown panel|\b404\b|not found/i.test(msg)) return "unserved";
  if (/unknown_?table|doesn'?t exist|does not exist|code:\s*60\b/i.test(msg)) {
    return "no-table";
  }
  return null;
}

/** The quiet version of "no", with the server's own words kept underneath it. */
function Absent({ kind, detail }: { kind: "unserved" | "no-table"; detail?: string }) {
  const [lead, body] =
    kind === "unserved"
      ? [
          "Not served by this build of the API.",
          "The dashboard and the Go service deploy separately, so this panel arrives with the service. Nothing else on this page depends on it.",
        ]
      : [
          "This dataset has no live-sessions table.",
          "Current session state comes from the live rollup, which the fixed extracts do not carry — they are a settled day, and there is no “now” in them to report. The statement that would have run is below.",
        ];

  return (
    <div className="flex flex-col items-center justify-center gap-1 py-4 text-center">
      <p className="text-[0.8125rem] text-ink-2">{lead}</p>
      <p className="max-w-[42ch] text-[0.6875rem] leading-relaxed text-ink-3">
        {body}
      </p>
      {detail ? (
        // The real message, never hidden — just not dressed as a fault. Someone
        // debugging this needs the server's words, not our paraphrase of them.
        <p className="mt-1 max-w-[52ch] font-mono text-[0.625rem] leading-relaxed break-words text-ink-3/80">
          {detail}
        </p>
      ) : null}
    </div>
  );
}

export function LiveSessionsPanel({
  state,
  query,
  height = 200,
}: {
  state: ReturnType<typeof usePanel>;
  query: string | null;
  height?: number;
}) {
  const d = state.data;
  const failed = state.transport ?? state.query;
  const kind = absence(failed);

  return (
    <PanelFrame
      title="Live sessions by platform"
      panel={d}
      query={query}
      // Suppressed only for the two classified absences. Everything else is
      // handed straight to the frame, red box and all, because it IS an error.
      transport={kind ? undefined : state.transport}
      queryError={kind ? undefined : state.query}
      isLoading={state.isLoading}
      isValidating={state.isValidating}
      // An absence renders its own body, so it must not be routed to the frame's
      // empty state — "no published rows in this window" would be a wrong
      // explanation for a table that is not there at all.
      empty={!kind && !d?.rows?.length}
      height={height}
    >
      {kind ? (
        <Absent kind={kind} detail={failed} />
      ) : d?.rows?.length ? (
        <Table panel={d} />
      ) : null}
    </PanelFrame>
  );
}

/**
 * Column indices by name, exactly as the breakdowns do it.
 *
 * Five numeric columns of the same type are the case where a reordered SELECT
 * mis-renders in complete silence — every cell still holds a plausible number.
 * Nothing here reads a row by position.
 */
function Table({ panel }: { panel: PanelResponse }) {
  const iPlatform = col(panel, "platform");
  const iOpen = col(panel, "open_sessions");
  const iActive = col(panel, "active_now");
  const iTerminated = col(panel, "terminated");
  const iLease = col(panel, "median_lease_age_s");

  return (
    <div className="-mx-1 overflow-x-auto">
      <table className="w-full min-w-[30rem] text-[0.8125rem]">
        <thead>
          <tr className="border-b border-line text-left text-ink-3">
            <th className="px-1 py-1.5 font-normal">Platform</th>
            <th className="px-1 py-1.5 text-right font-normal">Open</th>
            <th className="px-1 py-1.5 text-right font-normal">Active now</th>
            <th className="px-1 py-1.5 text-right font-normal">Terminated</th>
            <th
              className="px-1 py-1.5 text-right font-normal"
              title="Median age of the open sessions' leases. A lease older than the renewal interval is a session the pipeline is still counting on an optimistic expiry."
            >
              Median lease
            </th>
          </tr>
        </thead>
        <tbody>
          {panel.rows.map((r, i) => (
            <tr key={i} className="border-b border-line-soft last:border-0">
              <td className="px-1 py-1.5 font-mono text-ink-2">
                {asStr(r[iPlatform])}
              </td>
              <td className="tnum px-1 py-1.5 text-right font-mono text-ink">
                {count(asNum(r[iOpen]))}
              </td>
              {/* The only accented column: "how many right now" is the one figure
                  here that answers the same question as the curve above, and it
                  is additive across platforms in the way a peak is not. */}
              <td className="tnum px-1 py-1.5 text-right font-mono text-accent">
                {count(asNum(r[iActive]))}
              </td>
              <td className="tnum px-1 py-1.5 text-right font-mono text-ink-2">
                {count(asNum(r[iTerminated]))}
              </td>
              <td className="tnum px-1 py-1.5 text-right font-mono text-ink-3">
                {count(asNum(r[iLease]))}s
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
