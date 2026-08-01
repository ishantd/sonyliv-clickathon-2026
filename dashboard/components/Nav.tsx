"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useSyncExternalStore } from "react";
import { getToken, setToken } from "@/lib/api";

/**
 * Shows whether a token is stored, and allows clearing it.
 *
 * Only rendered once a token exists: on loopback there is no token and no need
 * for one, so an empty control would be noise. Clearing reloads for the same
 * reason saving does -- every poll has to pick up the changed header.
 */
function TokenBadge() {
  // useSyncExternalStore, not state-in-an-effect: localStorage does not exist during
  // the static export's prerender, so the server snapshot is "" and the prerendered
  // HTML cannot disagree with the first client render. It also picks up a token set
  // in another tab, which the effect version could not.
  const token = useSyncExternalStore(
    (onChange) => {
      window.addEventListener("storage", onChange);
      return () => window.removeEventListener("storage", onChange);
    },
    getToken,
    () => "",
  );

  if (!token) return null;
  return (
    <button
      onClick={() => {
        setToken("");
        window.location.reload();
      }}
      title="Clear the stored bearer token"
      className="rounded border border-line px-2 py-0.5 font-mono text-[0.6875rem] text-ink-3 transition-colors hover:border-bad hover:text-bad"
    >
      token set ×
    </button>
  );
}

/**
 * The collaboration lockup: SONYLIV over CLICKHOUSE.
 *
 * Stacked rather than inline, because two brand words on one line read as a
 * hyphenated product name; stacked with the × between them reads as two parties.
 * Tight leading (0.95) binds the pair into one mark, and the shared left edge is
 * what makes it a lockup rather than two labels.
 *
 * The × is set in the text face, not drawn — it is a typographic multiplication
 * sign doing the job it exists for, which is the one case where a glyph is not a
 * stand-in for an icon.
 *
 * Gold lands only on the ×. SonyLIV spends its single signal colour on the tick
 * in its own logo and nowhere else in the header; putting it on both words would
 * spend the whole budget in the corner of the screen.
 */
function Lockup() {
  return (
    <span
      className="flex shrink-0 flex-col leading-[0.95] font-semibold tracking-[0.02em] uppercase"
      aria-label="SonyLIV × ClickHouse"
    >
      <span className="text-[0.8125rem] text-ink">
        sonyliv <span className="font-normal text-accent">×</span>
      </span>
      <span className="text-[0.8125rem] text-ink-2">clickhouse</span>
    </span>
  );
}

// Ordered by workflow, not by age: create a fleet, watch it, control it. The two
// original dashboards come last because they answer different questions — throughput
// for the load simulator, one-event-at-a-time semantics for the stepper.
const routes: { href: string; label: string; also?: string[] }[] = [
  { href: "/fleet/new", label: "Create" },
  // Session detail is a query-param page under /fleet/session, so it needs naming
  // here — otherwise opening a session lights up no tab at all.
  { href: "/fleet", label: "Sessions", also: ["/fleet/session"] },
  { href: "/live", label: "Live" },
  { href: "/", label: "Load test" },
  { href: "/manual", label: "Stepper" },
];

/**
 * Trailing slashes are stripped before comparing.
 *
 * next.config sets trailingSlash: true, so usePathname reports "/fleet/" while the
 * hrefs here are written without one. Comparing them raw would leave every tab
 * inactive.
 */
const norm = (p: string) => (p.length > 1 ? p.replace(/\/+$/, "") : p);

export function Nav() {
  const pathname = usePathname();

  return (
    <header className="sticky top-0 z-10 border-b border-line bg-ground/90 backdrop-blur">
      <div className="mx-auto flex w-full max-w-[80rem] items-center gap-4 px-5 py-3 sm:gap-6">
        <Lockup />

        <nav
          className="flex min-w-0 gap-1 overflow-x-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
          aria-label="Dashboards"
        >
          {routes.map((r) => {
            // Exact match, not startsWith: "/" is a prefix of every route, so a
            // prefix test would light up every tab everywhere.
            const here = norm(pathname);
            const active =
              here === norm(r.href) || (r.also?.includes(here) ?? false);
            return (
              <Link
                key={r.href}
                href={r.href}
                aria-current={active ? "page" : undefined}
                className={`rounded px-2.5 py-1 text-[0.8125rem] whitespace-nowrap transition-colors ${
                  active
                    ? "bg-accent-wash text-accent"
                    : "text-ink-2 hover:text-ink"
                }`}
              >
                {r.label}
              </Link>
            );
          })}
        </nav>

        <span className="ml-auto hidden font-mono text-[0.6875rem] text-ink-3 sm:block">
          writes to events_raw · UTC
        </span>

        <TokenBadge />
      </div>
    </header>
  );
}
