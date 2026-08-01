import type {
  Action,
  ContentInfo,
  CurveResponse,
  SessionState,
  SimParams,
  SimStatus,
} from "./types";

/**
 * Base URL of the Go service.
 *
 * Empty in production: `next build` with `output: 'export'` produces static files
 * that the Go binary itself serves, so the API is same-origin and no base is
 * needed. In development `next dev` runs on :3000 while Go runs on :8088, so
 * .env.development points this at Go — and Go must be started with
 * `--cors-origin http://localhost:3000` to accept it.
 *
 * A next.config rewrite would be the usual way to avoid the cross-origin hop, but
 * rewrites are unsupported under `output: 'export'` and error even in `next dev`.
 */
export const API_BASE = process.env.NEXT_PUBLIC_API_BASE ?? "";

export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    ...init,
    headers: {
      ...(init?.body ? { "Content-Type": "application/json" } : {}),
      ...init?.headers,
    },
  });

  const text = await res.text();
  let body: unknown;
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    // A non-JSON body means we reached something that is not the API — most
    // often the Next dev server itself, when NEXT_PUBLIC_API_BASE is unset.
    throw new ApiError(
      `${res.status} ${res.statusText}: response was not JSON. Is the Go service running, and is NEXT_PUBLIC_API_BASE set?`,
      res.status,
    );
  }

  if (!res.ok) {
    const msg =
      typeof body === "object" && body && "error" in body
        ? String((body as { error: unknown }).error)
        : `${res.status} ${res.statusText}`;
    throw new ApiError(msg, res.status);
  }
  return body as T;
}

/** SWR fetcher. Keyed by path so SWR dedupes across components. */
export const fetcher = <T,>(path: string) => request<T>(path);

export const api = {
  content: (q: string, limit = 40) =>
    request<{ items: ContentInfo[] | null }>(
      `/api/content?limit=${limit}&q=${encodeURIComponent(q)}`,
    ),

  simStatus: () => request<SimStatus>("/api/sim"),

  simStart: (params: SimParams) =>
    request<SimStatus>("/api/sim/start", {
      method: "POST",
      body: JSON.stringify(params),
    }),

  simStop: () =>
    request<{ stopped: boolean; status: SimStatus }>("/api/sim/stop", {
      method: "POST",
    }),

  curve: (minutes = 30) =>
    request<CurveResponse>(`/api/curve?minutes=${minutes}`),

  manualNew: (content: ContentInfo, platform: string) =>
    request<SessionState["session"]>("/api/manual/session", {
      method: "POST",
      body: JSON.stringify({
        content_id: content.content_id,
        title: content.title,
        video_type: content.video_type,
        platform,
      }),
    }),

  manualEvent: (session: string, action: Action, advanceSeconds: number) =>
    request<SessionState>("/api/manual/event", {
      method: "POST",
      body: JSON.stringify({
        session,
        action,
        advance_seconds: advanceSeconds,
      }),
    }),

  manualSessions: () =>
    request<{ sessions: SessionState["session"][] | null }>(
      "/api/manual/sessions",
    ),

  manualState: (session: string) =>
    request<SessionState>(`/api/manual/session/${session}`),
};

// ---------------------------------------------------------------------------
// Formatting. Centralised so the same number never renders two ways.
// ---------------------------------------------------------------------------

const nf = new Intl.NumberFormat("en-US");

export const num = (n: number | undefined | null) => nf.format(n ?? 0);

/** HH:MM:SS.mmm in UTC — the only timezone in this system. */
export function clockTime(iso: string | undefined): string {
  if (!iso) return "—";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "—";
  // A zero DateTime64 comes back as 1970; showing "00:00:00.000" would read as a
  // real time rather than "never set".
  if (d.getUTCFullYear() <= 1970) return "—";
  return d.toISOString().slice(11, 23);
}

export const seconds = (ms: number) => `${(ms / 1000).toFixed(1)}s`;

export function durationBetween(start: string, end: string): string {
  return seconds(new Date(end).getTime() - new Date(start).getTime());
}
