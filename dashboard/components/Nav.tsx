"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useSyncExternalStore } from "react";
import useSWR from "swr";
import { fetcher, getToken, setToken } from "@/lib/api";
import { setDataset, useDataset } from "@/lib/dataset";
import { ClickHouseMark, SonyLivMark } from "./BrandMarks";

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

type DbOption = { name: string; label: string; note: string; writable: boolean };

/**
 * The dataset picker, in the nav so it applies to every page rather than to one.
 *
 * A <select>, not a row of buttons: the list is server-supplied and will grow, and
 * a growing row of buttons competes with the page tabs for the same horizontal
 * space. A picker stays one control however many datasets exist.
 *
 * The options come from /api/analytics, which is where they are hardcoded — in Go,
 * where the same list is the SQL allowlist. Restating them here would be a second
 * copy of a security-relevant list.
 *
 * Renders nothing until the list loads, and nothing if only one dataset exists: a
 * picker with a single option is furniture, not a control.
 */
function DatasetPicker() {
  const { data } = useSWR<{ databases: DbOption[]; default: string }>(
    "/api/analytics",
    fetcher,
    { revalidateOnFocus: false },
  );
  const selected = useDataset();

  if (!data || data.databases.length < 2) return null;
  const current =
    data.databases.find((d) => d.name === selected) ??
    data.databases.find((d) => d.name === data.default) ??
    data.databases[0];

  return (
    <label className="flex shrink-0 items-center gap-1.5" title={current.note}>
      <span className="sr-only">ClickHouse dataset</span>
      <select
        value={current.name}
        onChange={(e) => setDataset(e.target.value)}
        className="rounded border border-line bg-sunken px-2 py-1 text-[0.8125rem] text-ink-2 transition-colors hover:text-ink focus:border-accent-dim focus:outline-none"
      >
        {data.databases.map((d) => (
          <option key={d.name} value={d.name}>
            {d.label}
          </option>
        ))}
      </select>
      {/* The one thing a reader on the evaluation set has to know: the controls on
          the other pages do not write here. Shown as a state, not a warning —
          nothing is wrong, it is simply read-only. */}
      {!current.writable ? (
        <span
          className="rounded border border-line px-1.5 py-0.5 font-mono text-[0.625rem] text-ink-3"
          title="The simulator writes only to the writable dataset. Reads follow this picker; writes do not."
        >
          read-only
        </span>
      ) : null}
    </label>
  );
}

/**
 * The collaboration lockup: the real `liv` mark over the real ClickHouse wordmark.
 *
 * Both are the parties' own assets — SonyLIV's header PNG and ClickHouse's own
 * SVG — rather than lettering set in Inter and hoped to pass. Two brands in one
 * lockup is exactly where an approximation shows.
 *
 * Stacked, because side by side two wordmarks read as a hyphenated product name
 * while stacked with the × between them reads as two parties. The left edges
 * align and the gap is tight, which is what binds them into one mark instead of
 * two logos that happen to be near each other.
 *
 * The × stays typographic and gold. It is a multiplication sign doing the job it
 * exists for — the one case where a glyph is not standing in for an icon — and
 * it is the only place the signal colour appears in the header, so the eye reads
 * the join rather than the chrome.
 *
 * The ClickHouse mark inherits `currentColor` at ink-2, deliberately a step below
 * the liv mark's own gold: a lockup where both parties shout has no hierarchy,
 * and this is the SonyLIV problem statement.
 */
function Lockup() {
  return (
    <span
      className="flex shrink-0 flex-col gap-1"
      aria-label="SonyLIV × ClickHouse"
      title="SonyLIV × ClickHouse"
    >
      <span className="flex items-center gap-1.5">
        <SonyLivMark />
        <span className="text-[0.8125rem] leading-none text-accent">×</span>
      </span>
      <span className="text-ink-2">
        <ClickHouseMark />
      </span>
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
  // The ClickStack dashboards, reproduced here rather than linked: managed
  // ClickStack has no stable deep link, so an external tab would land on a login.
  { href: "/analytics", label: "Analytics" },
  { href: "/", label: "Load test" },
  { href: "/manual", label: "Stepper" },
];

/*
 * The three surfaces that are not this app, resolved at build time.
 *
 * LibreChat shares this host: nginx gives it the root of :443 and mounts this app
 * at /build, because LibreChat cannot be served from a prefix (see next.config).
 * So its href is a bare "/" — the one link here that must NOT be rebased, which is
 * why the nav renders these as plain anchors.
 *
 * There is deliberately NO ClickStack link. ClickStack is queries over the same
 * ClickHouse this app already reads, and managed ClickStack has no stable deep link
 * — console -> service -> ClickStack -> Launch, through an authenticated redirect —
 * so a tab would land on a login page. The panels are reproduced at /analytics
 * instead, against the same serving-layer views.
 *
 * Langfuse stays a link rather than a proxy: it is cookie-authenticated on its own
 * origin, and reverse-proxying a session-bearing third-party app breaks its auth in
 * ways that look like the app being broken.
 *
 * Empty means absent, not broken — an unconfigured tab is not rendered at all.
 */
const externals: {
  href: string;
  label: string;
  title: string;
  newTab: boolean;
}[] = [
  {
    href: "/",
    label: "Analyst",
    title: "LibreChat over the serving-layer MCP server",
    newTab: false,
  },
  {
    href: process.env.NEXT_PUBLIC_LANGFUSE_URL ?? "",
    label: "Traces",
    title: "Langfuse traces for the analyst's queries",
    newTab: true,
  },
].filter((x) => x.href !== "");

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

        {/* The other three surfaces of the demo, which are not this app.

            Plain <a>, never <Link>, and that is the whole reason this block is
            separate. Under NEXT_PUBLIC_BASE_PATH=/build a <Link href="/"> resolves
            to /build/ — this app's own root — so linking to LibreChat with it would
            silently point back here. `external` opts out of Next's routing entirely
            so the href reaches the browser verbatim.

            Rendered only when configured. A nav tab that leads to a placeholder is
            worse than an absent one, so an unset URL means the tab does not exist. */}
        <div className="ml-auto flex shrink-0 items-center gap-3">
          <DatasetPicker />
        </div>

        <nav
          className="flex shrink-0 items-center gap-1"
          aria-label="Other surfaces"
        >
          {externals.map((x) => (
            <a
              key={x.label}
              href={x.href}
              // Only the off-box links open a tab. LibreChat is on this same host,
              // so replacing the page is the right behaviour; ClickStack and
              // Langfuse are elsewhere and losing the demo to a navigation would
              // be a poor trade.
              {...(x.newTab
                ? { target: "_blank", rel: "noopener noreferrer" }
                : {})}
              title={x.title}
              className="rounded px-2.5 py-1 text-[0.8125rem] whitespace-nowrap text-ink-2 transition-colors hover:text-ink"
            >
              {x.label}
              {x.newTab ? (
                <span aria-hidden className="ml-1 text-ink-3">
                  ↗
                </span>
              ) : null}
            </a>
          ))}
        </nav>

        {/* Just the timezone. "writes to events_raw" was stating the obvious —
            every page here writes to events_raw, so a permanent banner saying so
            carried no information and spent header width doing it. UTC stays
            because the tables are full of bare clock times and nothing else on
            the page says which zone they are in. */}
        <span className="font-mono text-[0.6875rem] text-ink-3">UTC</span>

        <TokenBadge />
      </div>
    </header>
  );
}
