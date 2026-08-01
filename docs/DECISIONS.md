# Finalized Design Decisions

*Settled in design discussion on 2026-08-01, after profiling (`EVIDENCE.md`), draft design (`DESIGN.md`), adversarial review (`REVIEW-FINDINGS.md`), and prototype validation (`../prototype/RESULTS.md`). These decisions supersede the corresponding draft sections of `DESIGN.md`; a v2 rewrite folds them in when implementation resumes.*

## D1. Correctness contract → ground-truth parity

**Chosen:** The primary serving tables implement the reproduced benchmark semantics exactly:
- Counting key = `video_session_id` alone (not `(user_id, video_session_id)`)
- Session span = first event → last event (no clipping at `VideoSessionEnd`)
- Paused-in-foreground counts as active
- Activity = any event with `event_type ∈ {VideoSessionStart, VideoPlay, VideoHeartbeat, AppForegrounded}`
- Liveness T = 120s; bg exclusion = wholly-contained-minute rule with next-fg pairing
- Slices event-attributed (per `(session, dims)` unit), global session-attributed — non-additive by design, matching the ground-truth pipeline

**Rejected:** production-first semantics as primary (user+session key, End-clipping) — risks systematic divergence from the judges' private answer key; dual parallel tables — double the logic to defend.

**Kept as documented policy knobs** (each with measured impact): End-clipping (≈ −198 session-minutes; 239 sessions trail events past End), user+session key (120 colliding session ids), pause-as-inactive (pause/resume events exist under the heartbeat type), T ∈ {90, 120, 180}s (false-cut 0.253% / 0.201% / 0.157%).

## D2. Live freshness → compactor tick only

**Chosen:** One serving path. The "right now" number is the served value at the last compacted minute; compactor cadence 30–60s bounds staleness. The replay demo still shows the curve building live.

**Rejected:** a second live-overlay query on `session_state` — the review showed the draft version was wrong three ways (unmerged aggregate states, missing foreground gate → 9.2% backgrounded contamination, End sentinel mishandling); fixing it means maintaining a second semantics forever. Not worth it for ~45s of freshness.

## D3. OSS integration → both LibreChat+MCP and ClickStack

- **LibreChat + ClickHouse MCP**: conversational layer over the serving tables ("what was peak concurrency on Android in the last hour?") — the problem statement's own suggested fit; demo moment.
- **ClickStack**: observes our pipeline itself — ingest lag, compactor tick latency, serving query performance — and directly feeds the unseen-day "pipeline evidence" requirement.
- Langfuse: skipped (only meaningful with an LLM layer in the data path; weakest fit).

## D4. Benchmark insurance → all three extra scopes

Benchmark queries are unknown until event day; each scope is cheap now, impossible to backfill fast later:
1. **User-level concurrency table** (`concurrency_deltas_users`, user-scoped compactor emission) — the data dictionary names user-level concurrency explicitly; it diverges 3.3% from session-level at peak.
2. **`app_version`** added to the dimension delta key — 65 values, session-constant, listed as a filter dimension.
3. **`audio_language`** added to the dimension delta key — 41 values, genuinely switches mid-session in 16.1% of sessions, so it must be event-attributed like platform.

Resulting dim serving key: `(platform, content_id, app_version, audio_language, m)` + `video_type` denormalized via dictionary; roll-up tables (global, platform) unchanged.

## By-fiat defaults (documented, data cannot decide)

| Knob | Default | Note |
|---|---|---|
| Timezone | UTC everywhere (epoch-seconds arithmetic; `DateTime('UTC')` on Cloud); IST display-only | An IST/UTC mixup already caused a cross-investigator discrepancy during profiling |
| Duplicate Ends | Last-End-wins (argMax) | 4 sessions differ between first/last-End |
| Bot user `4CE58A95…` | Kept at session level; excluded only from user-level metrics | 301 sessions, up to 95 concurrent |
| Missing minutes | Served as explicit zeros via dense-grid reconstruction | 26.3% of naive-active minutes have fg = 0 |
| Unseen-day content misses | `dictGetOrDefault(..., 'unknown')` + dictionary refresh before each compaction | Tuning data had 100% join coverage; unseen day may not |
| Raw heartbeat retention | Keep during hackathon (auditability); note TTL path for the 53.7% trio share | Storage-vs-audit tradeoff |
