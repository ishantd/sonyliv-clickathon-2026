"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { TokenField } from "./TokenField";

const routes = [
  { href: "/", label: "Load simulator" },
  { href: "/manual", label: "Event stepper" },
];

export function Nav() {
  const pathname = usePathname();

  return (
    <header className="sticky top-0 z-10 border-b border-line bg-ground/90 backdrop-blur">
      <div className="mx-auto flex w-full max-w-[80rem] items-center gap-6 px-5 py-3">
        <span className="font-mono text-[0.8125rem] font-semibold tracking-tight">
          sonyliv<span className="text-accent">-mock</span>
        </span>

        <nav className="flex gap-1" aria-label="Dashboards">
          {routes.map((r) => {
            // Exact match, not startsWith: "/" is a prefix of every route, so a
            // prefix test would light up both tabs on /manual.
            const active = pathname === r.href;
            return (
              <Link
                key={r.href}
                href={r.href}
                aria-current={active ? "page" : undefined}
                className={`rounded px-2.5 py-1 text-[0.8125rem] transition-colors ${
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

        <span className="ml-auto hidden font-mono text-[0.6875rem] text-ink-3 lg:block">
          writes to events_raw · UTC
        </span>

        {/* Renders nothing unless the server is token-gated. */}
        <TokenField />
      </div>
    </header>
  );
}
