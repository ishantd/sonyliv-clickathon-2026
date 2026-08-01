"use client";

import { useState, useSyncExternalStore } from "react";
import useSWR from "swr";
import {
  getToken,
  setToken,
  subscribeToken,
  tokenServerSnapshot,
} from "@/lib/api";

/**
 * Bearer token entry, for when the server was started with --token.
 *
 * Hidden entirely when the server is unauthenticated, so the common loopback case
 * shows no chrome for a thing that does not apply. It probes GET /healthz — which
 * is deliberately NOT gated — and then an /api/ route to learn whether auth is on.
 */
export function TokenField() {
  const stored = useSyncExternalStore(
    subscribeToken,
    getToken,
    tokenServerSnapshot,
  );
  // Draft is seeded from the store but diverges while typing, so it is local
  // state rather than derived.
  const [draft, setDraft] = useState<string | null>(null);
  const value = draft ?? stored;
  const [saved, setSaved] = useState(false);

  // A 401 from any /api/ route means the server wants a token. SWR retries on its
  // own cadence, so once a valid token is stored this flips back without a reload.
  const { error, mutate } = useSWR(
    "auth-probe",
    async () => {
      const res = await fetch(
        `${process.env.NEXT_PUBLIC_API_BASE ?? ""}/api/sim`,
        getToken()
          ? { headers: { Authorization: `Bearer ${getToken()}` } }
          : undefined,
      );
      if (res.status === 401) throw new Error("unauthorized");
      return true;
    },
    { refreshInterval: 15_000, shouldRetryOnError: false },
  );

  const needed = Boolean(error);
  if (!needed && !value) return null;

  return (
    <form
      className="ml-auto flex items-center gap-1.5"
      onSubmit={(e) => {
        e.preventDefault();
        setToken(value.trim());
        setDraft(null);
        setSaved(true);
        setTimeout(() => setSaved(false), 1500);
        void mutate();
      }}
    >
      <label className="eyebrow text-ink-3" htmlFor="api-token">
        token
      </label>
      <input
        id="api-token"
        type="password"
        value={value}
        onChange={(e) => setDraft(e.target.value)}
        placeholder={needed ? "required" : "set"}
        aria-invalid={needed}
        className={`!w-40 !py-1 !text-[0.6875rem] ${needed ? "!border-bad" : "!border-line"}`}
      />
      <button
        type="submit"
        className="rounded border border-line bg-sunken px-2 py-1 text-[0.6875rem] text-ink-2 hover:border-accent"
      >
        {saved ? "saved" : "use"}
      </button>
    </form>
  );
}
