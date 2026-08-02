"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useSyncExternalStore } from "react";
import useSWR from "swr";
import { fetcher, getToken, setToken } from "@/lib/api";
import { setDataset, useDataset } from "@/lib/dataset";
import { ClickHouseMark, ClickHouseSymbol, SonyLivMark } from "./BrandMarks";

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
      {/* An EXPLICIT width, not a max-width, and that is a layout fix rather
          than a preference.

          A native select's intrinsic minimum is its longest OPTION, not its
          value — "Evaluation set — 31 Jul" is wide enough that the control
          refused to shrink, consumed the header row and overlapped the links
          beside it. `max-width` does not help, because the element was already
          being squeezed below its min-content size and won that fight;
          `truncate` does not either, since it has no effect on a select's own
          rendering. A fixed width ends the negotiation: the browser ellipsises
          the label itself, and the full text is in the tooltip and in the
          dataset note on the page. */}
      <select
        value={current.name}
        onChange={(e) => setDataset(e.target.value)}
        className="w-[8.5rem] rounded border border-line bg-sunken px-2 py-1 text-[0.8125rem] text-ink-2 transition-colors hover:text-ink focus:border-accent-dim focus:outline-none sm:w-[11rem] lg:w-[13rem]"
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
 * The collaboration lockup: both parties' real marks, joined.
 *
 * Every glyph here is the owner's own asset — SonyLIV's header PNG, ClickHouse's
 * symbol and wordmark from their own SVG — rather than lettering set in Inter and
 * hoped to pass. Two brands in one lockup is exactly where an approximation
 * shows.
 *
 * ONE LINE, NOT TWO. This used to stack the two marks with the × between them,
 * on the reasoning that side by side they read as a hyphenated product name. That
 * reasoning was answering a problem the symbol solves better: with ClickHouse's
 * bars leading its wordmark, the right-hand side is unmistakably a second party's
 * logo and no longer needs vertical separation to say so. One line also halves
 * the header's height budget, which the nav spends on tabs instead.
 *
 * It matches the submission deck's cover, deliberately — pitch/index.html sets
 * the same two marks in the same order with the same join. A deck and a product
 * that lock up their brands differently read as two projects.
 *
 * The × is typographic, at ink-3. It used to be the header's only gold, back when
 * the ClickHouse side was a mono wordmark and the join needed to carry the
 * emphasis. Now that both marks are in their own colours, a gold × would be a
 * third accent competing with two logos — so the join recedes and the marks
 * speak.
 */
function Lockup() {
  return (
    <span
      className="flex shrink-0 items-center gap-2"
      aria-label="SonyLIV × ClickHouse"
      title="SonyLIV × ClickHouse"
    >
      <SonyLivMark />
      <span aria-hidden className="text-[0.75rem] leading-none text-ink-3">
        ×
      </span>
      <span className="flex items-center gap-1.5 text-ink-2">
        <ClickHouseSymbol className="h-[0.9375rem] w-auto" />
        {/* The wordmark is the part that costs width, so it is the part that goes
            first on a narrow viewport. The symbol alone still reads as
            ClickHouse; a wordmark with no symbol beside SonyLIV's logo reads as
            a caption. */}
        <ClickHouseMark className="hidden h-3.5 w-auto sm:block" />
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

/**
 * The route tabs.
 *
 * Extracted so the header can place them in two different slots — inline from
 * `sm` up, on their own row below it — without the markup existing twice.
 */
function Tabs({ pathname, className = "" }: { pathname: string; className?: string }) {
  return (
    <nav
      className={`flex min-w-0 gap-1 overflow-x-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden ${className}`}
      aria-label="Dashboards"
    >
      {routes.map((r) => {
        // Exact match, not startsWith: "/" is a prefix of every route, so a
        // prefix test would light up every tab everywhere.
        const here = norm(pathname);
        const active = here === norm(r.href) || (r.also?.includes(here) ?? false);
        return (
          <Link
            key={r.href}
            href={r.href}
            aria-current={active ? "page" : undefined}
            className={`rounded px-2.5 py-1 text-[0.8125rem] whitespace-nowrap transition-colors duration-150 ${
              active
                ? "bg-accent-wash text-accent"
                : "text-ink-2 hover:bg-raised hover:text-ink"
            }`}
          >
            {r.label}
          </Link>
        );
      })}
    </nav>
  );
}

export function Nav() {
  const pathname = usePathname();

  return (
    <header className="sticky top-0 z-10 border-b border-line bg-ground/90 backdrop-blur">
      {/*
        TWO ROWS UNTIL THERE IS ROOM FOR ONE.

        This was a single flex row, and at 390px it failed in the way that
        matters most: the tab strip is the only min-w-0 item, so it absorbed
        every pixel of the shortfall and collapsed to zero width. The lockup, the
        dataset picker and the external links all rendered; the primary
        navigation did not. A header that drops its own navigation first has its
        priorities exactly backwards.

        Wrapping rather than hiding: every control stays reachable at every
        width. The chrome takes the first row and the tabs take a full-width
        scrollable second one, which is more room than they had inline.

        The breakpoint is `lg`, not `sm`, and that is measured rather than
        chosen: at 768px the tabs fit the row only by being clipped mid-word —
        the active tab rendered as a single letter. One row is the better layout
        exactly when it is not cramped, which on this header is from 1024px.
      */}
      <div className="mx-auto w-full max-w-[80rem] px-5 py-3">
        <div className="flex items-center gap-3 sm:gap-4 md:gap-6">
          <Lockup />

          <Tabs pathname={pathname} className="hidden lg:flex" />

        {/* The other surfaces of the demo, which are not this app.

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
                // Only the off-box links open a tab. LibreChat is on this same
                // host, so replacing the page is the right behaviour; ClickStack
                // and Langfuse are elsewhere and losing the demo to a navigation
                // would be a poor trade.
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
              every page here writes to events_raw, so a permanent banner saying
              so carried no information and spent header width doing it. UTC
              stays because the tables are full of bare clock times and nothing
              else on the page says which zone they are in. Dropped below `sm`,
              where the row is tight and every page states UTC beside its own
              timestamps anyway. */}
          <span className="hidden font-mono text-[0.6875rem] text-ink-3 sm:inline">
            UTC
          </span>

          <TokenBadge />
        </div>

        <Tabs pathname={pathname} className="mt-2 lg:hidden" />
      </div>
    </header>
  );
}
