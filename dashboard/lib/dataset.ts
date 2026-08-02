"use client";

import { useSyncExternalStore } from "react";
import useSWR from "swr";
import { fetcher } from "./api";
import type { Database, Meta } from "./analytics";

/**
 * The selected ClickHouse dataset that Analytics READS.
 *
 * It used to be described as shared by every page, and it no longer is: Pusher
 * only ever touches the server's writable database, so the picker is rendered on
 * Analytics alone and useWriteDataset below is what Pusher displays instead. The
 * store still outlives a route change, because Analytics itself is two addresses
 * (/ and /analytics) and losing the choice between them would be the same bug
 * described next.
 *
 * WHY A STORE AND NOT PAGE STATE. The picker lives in the nav, which persists
 * across route changes, while the pages that consume it mount and unmount. Page
 * state would reset the choice on every navigation — you would pick the evaluation
 * set, navigate, and silently be back on the default without being told.
 *
 * localStorage rather than a URL parameter, deliberately: the nav is shared by
 * pages that do not all take the same query string, and threading one parameter
 * through every link is how one page ends up not carrying it. The tradeoff is that
 * the choice is not shareable in a link — acceptable, because the dataset is
 * always displayed and every panel is labelled with what the SERVER said it read.
 *
 * useSyncExternalStore, matching the token store in lib/api: localStorage does not
 * exist during the static export's prerender, so the server snapshot must be a
 * stable null and the first client render must be free to disagree with the HTML.
 * It also picks up a change made in another tab.
 */

const KEY = "sonyliv.dataset";
const EVENT = "sonyliv:dataset";

function emit() {
  window.dispatchEvent(new CustomEvent(EVENT));
}

export function getDataset(): string | null {
  if (typeof window === "undefined") return null;
  return window.localStorage.getItem(KEY);
}

export function setDataset(name: string) {
  window.localStorage.setItem(KEY, name);
  // storage events do not fire in the tab that made the change, so the local
  // subscribers need an explicit nudge or the nav updates and the page does not.
  emit();
}

function subscribe(onChange: () => void) {
  window.addEventListener("storage", onChange);
  window.addEventListener(EVENT, onChange);
  return () => {
    window.removeEventListener("storage", onChange);
    window.removeEventListener(EVENT, onChange);
  };
}

/**
 * The chosen dataset, or null before one has been chosen.
 *
 * Null is meaningful and must not be collapsed to a default here: a caller that
 * fetches with null should HOLD rather than request the server's default, or the
 * first paint shows one dataset's numbers and the second shows another's.
 */
export function useDataset(): string | null {
  return useSyncExternalStore(subscribe, getDataset, () => null);
}

/**
 * The one dataset the simulator writes into — the server's own database.
 *
 * The counterpart to useDataset, and deliberately not a choice: every write path
 * in the service (fleet INSERT, the stepper, /api/events, the sealer) uses the
 * connection's configured database and reads no `db` parameter at all. Pusher
 * therefore has nothing to pick between, and states this instead of offering a
 * control that could not act.
 *
 * WHY `writable` AND NOT `default`. They are different databases and the
 * difference is the whole reason both fields exist. `default` is the dataset
 * Analytics OPENS ON — `sonyliv`, the submission's own database, which the
 * README, the deck and the benchmark all quote and which nothing here writes to.
 * The write target is `sonyliv_demo`, and the server marks it by setting
 * `writable`, documented in analytics.go as existing precisely so the UI can say
 * which dataset the simulator writes into. Reading `default` here would name the
 * read-only extract on a page whose every button appends rows somewhere else.
 *
 * Null until the list loads, and null if the server advertises no writable
 * dataset at all. Not defaulted: naming the wrong database with confidence is
 * strictly worse than naming none, and a caller that needs a `db` parameter must
 * hold rather than send one that resolves somewhere else.
 */
export function useWriteDataset(): Database | null {
  // Same SWR key as the nav and /analytics, so this shares their cache entry and
  // costs no extra request wherever it is used.
  const { data } = useSWR<Meta>("/api/analytics", fetcher, {
    revalidateOnFocus: false,
  });
  return data?.databases.find((d) => d.writable) ?? null;
}
