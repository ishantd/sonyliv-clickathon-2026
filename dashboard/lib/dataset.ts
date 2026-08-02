"use client";

import { useSyncExternalStore } from "react";

/**
 * The selected ClickHouse dataset, shared by every page.
 *
 * WHY A STORE AND NOT PAGE STATE. The picker lives in the nav, which persists
 * across route changes, while the pages that consume it mount and unmount. Page
 * state would reset the choice on every navigation — you would pick the evaluation
 * set, click Live, and silently be back on the default without being told.
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
