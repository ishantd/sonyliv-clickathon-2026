/**
 * Mirrors the JSON the Go service emits. Field names are snake_case because they
 * are the wire format from `internal/mock`, not a local convention — renaming
 * them here would put a translation layer between two things that should stay
 * obviously identical.
 */

export interface ContentInfo {
  content_id: number;
  title: string;
  video_type: string;
  category: string;
}

/** Mirrors generator.Summary, which Go marshals with its Go field names. */
export interface GeneratorSummary {
  Events: number;
  Sessions: number;
  SessionsOpen: number;
  Duplicates: number;
  LateEvents: number;
  DroppedPastCutoff: number;
  PeakConcurrency: number;
}

export interface SimParams {
  concurrency: number;
  user_pool: number;
  content_ids: number[];
  content_pool: number;
  speed_factor: number;
  ramp_up_seconds: number;
  duration_minutes: number;
  max_events: number;
  /**
   * null means "use the measured rates" (7% late, 0.5% duplicate); an explicit 0
   * means "generate a perfectly ordered stream". The Go side models this as
   * *float64 for exactly that reason, so the distinction has to survive the wire.
   */
  late_fraction: number | null;
  dup_fraction: number | null;
  batch_size: number;
  workers: number;
  async: boolean;
  /**
   * "direct" writes over the ClickHouse native protocol; "api" makes the
   * generator a real client of POST /api/events, exercising that endpoint's
   * decoding, validation, chunking and async-insert path on every run.
   */
  sink: "direct" | "api";
}

export interface SimStatus {
  running: boolean;
  run_id?: string;
  started_at?: string;
  elapsed_seconds: number;
  params?: SimParams;
  content_requested: number;
  content_resolved: number;
  rows: number;
  batches: number;
  retries: number;
  rows_per_sec: number;
  insert_p50_ms: number;
  insert_p99_ms: number;
  summary?: GeneratorSummary;
  finished: boolean;
  error?: string;
}

export interface CurvePoint {
  minute: string;
  sessions: number;
  events: number;
}

export interface CurveResponse {
  points: CurvePoint[];
  /** The server labels its own estimator; the UI surfaces that label verbatim. */
  estimator: string;
}

export interface ManualSession {
  video_session_id: string;
  user_id: string;
  content_id: number;
  content_title: string;
  platform: string;
  app_version: string;
  country: string;
  start_epoch: string;
  /** Event-time cursor, advanced by the operator — not wall clock. */
  clock: string;
  events_sent: number;
}

export interface TimelineRow {
  event_ts: string;
  event_type: string;
  event: string;
  signal: string;
  is_liveness: boolean;
  started: boolean;
  end_seen: boolean;
  foreground: boolean;
  playing: boolean;
  last_eligible_signal: string;
  lease_expires: string;
  active: boolean;
}

export interface Interval {
  start: string;
  end: string;
}

export interface SessionState {
  session: ManualSession;
  timeline: TimelineRow[];
  intervals: Interval[];
  active_ms: number;
  timeout_ms: number;
}

/** The stepper's buttons, matching mock.Action on the Go side. */
export type Action =
  | "start"
  | "play"
  | "pause"
  | "resume"
  | "background"
  | "foreground"
  | "heartbeat"
  | "error"
  | "end"
  | "adbreak"
  | "ratechange";
