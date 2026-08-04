-- =============================================================================
-- 006_session_state.sql — per-session commutative state, maintained at insert
--
-- Replaces the window-function state machine. One row per session, filled by an
-- incremental MV off events_clean, holding everything the interval derivation
-- needs and nothing else.
--
-- Why an insert-time MV is legal here, when it is NOT legal for reconstructing
-- intervals directly
-- ---------------------------------------------------------------------------
-- policy.yaml's active predicate is built from four LAST-SETTER-WINS booleans
-- plus a lease. A last-setter-wins boolean is a union of intervals:
--
--     F     = ⋃ [f, first_bg  >= f)      over f in fg_ts
--     P     = ⋃ [p, first_stop >= p)      over p in play_start_ts
--     L     = [lifecycle_start, first_end)
--     Base  = F ∩ P ∩ L
--     Elig  = { s in signal_ts : s ∈ Base }
--     Lease = ⋃ [s, s + T)                over s in Elig
--     Active = Base ∩ Lease
--
-- Every input to that is a SET of timestamps. Sets merge commutatively and
-- idempotently, so arrival order, block boundaries, duplicate rows and late
-- events all collapse to the same state — which is exactly what an incremental
-- MV can maintain, and exactly what a `lead()`/ordered pipeline cannot.
--
-- Two consequences worth stating because they are the whole argument:
--
--   * duplicated and repeated events are FREE. 109 double-backgrounds, 74
--     orphan foregrounds, 9,768 adjacent resume->resume and the 4,210 exact
--     duplicate rows all vanish into the set union. No defensive state-machine
--     rules, and no parity assumption — parity would be wrong for the 4.45% of
--     sessions whose bg/fg does not alternate.
--   * the lease needs no fold. "t is within T of the most recent eligible
--     signal" is equivalent to "t ∈ ⋃ [s, s+T)": if t ∈ [sᵢ, sᵢ+T) for any
--     eligible sᵢ, and s* is the latest eligible signal <= t, then
--     sᵢ <= s* <= t so t - s* < T. And renew_only_when carries no lease term,
--     so eligibility depends only on Base — no fixed point to solve.
--
-- Sizing (measured on the supplied extract)
-- ---------------------------------------------------------------------------
-- signal_ts holds distinct TIMESTAMPS, not events: the {network-activity,
-- buffer-health, video-resize} trio fires at one identical millisecond, so the
-- set union collapses 827,143 liveness events to 616,553 timestamps (1.34x).
-- Array length p50 34, p90 128, p99 347, max 1,709. Bounded by SESSION LENGTH,
-- which does not grow with scale — only session count does — so merge write
-- amplification is data-invariant.
--
-- Transition arrays are small: bg 14,616, fg 14,291, play_start 42,456,
-- play_stop 27,495 timestamps in total across all 10,866 sessions.
--
-- The min-sentinel trap
-- ---------------------------------------------------------------------------
-- Every min() below writes a FAR-FUTURE sentinel for non-matching rows rather
-- than using minIf. minIf over zero matching rows yields 1970-01-01, and
-- min(1970, real) = 1970 — so a block containing no VideoSessionEnd would erase
-- a real End on merge. max() has no such problem (max(0, real) = real), which is
-- why only the mins carry the sentinel.
-- =============================================================================

CREATE TABLE IF NOT EXISTS {{db}}.session_state
(
    -- Constant per session (session_start_epoch is verified constant and equal to
    -- the Start event timestamp for all 10,866 sessions), so a session never
    -- migrates between partitions and its partial rows always merge together.
    session_start_date Date,
    session_key        UInt64,

    -- ---------------------------------------------------------------------
    -- Scalars. Commutative, and no arrays needed: only the extremum matters.
    -- ---------------------------------------------------------------------
    -- FAR-FUTURE sentinel means "not observed":
    --   lifecycle_start = sentinel -> no VideoSessionStart seen. policy
    --                     missing_start_action: quarantine keys off this.
    --   first_end       = sentinel -> session still open.
    -- policy end_choice: first, hence min rather than max.
    lifecycle_start SimpleAggregateFunction(min, DateTime64(3, 'UTC')),
    first_end       SimpleAggregateFunction(min, DateTime64(3, 'UTC')),
    last_event      SimpleAggregateFunction(max, DateTime64(3, 'UTC')),

    -- ---------------------------------------------------------------------
    -- Toggle sets. Two arrays per boolean, not one signed array: the split
    -- encodes direction positionally (so it is strictly smaller than carrying a
    -- sign byte), and it makes millisecond ties resolve for free — the closing
    -- search uses >=, so a background sharing an instant with a foreground
    -- yields an empty interval, which IS policy's stop-wins precedence with no
    -- precedence table required.
    --
    -- foreground and playing are INDEPENDENT booleans and must stay separate:
    -- 1,967 pauses and 367 resumes occur while backgrounded, and 13,501 of
    -- 14,321 foregrounds happen while the player is stopped. Collapsing them
    -- into one "inactive" flag disagrees at 38,958 of 905,558 event positions
    -- across 98.8% of sessions, every one of them an overcount.
    -- ---------------------------------------------------------------------
    bg_ts         SimpleAggregateFunction(groupUniqArrayArray, Array(DateTime64(3, 'UTC'))),
    fg_ts         SimpleAggregateFunction(groupUniqArrayArray, Array(DateTime64(3, 'UTC'))),
    play_start_ts SimpleAggregateFunction(groupUniqArrayArray, Array(DateTime64(3, 'UTC'))),
    play_stop_ts  SimpleAggregateFunction(groupUniqArrayArray, Array(DateTime64(3, 'UTC'))),

    -- Liveness observations. signal IN ('play','resume','liveness') — i.e.
    -- VideoPlay or any VideoHeartbeat that is not 'pause', which is policy's
    -- signal_events exactly. AdPause and speed-pause land here by 003's
    -- deliberate classification, not as play-state transitions.
    signal_ts     SimpleAggregateFunction(groupUniqArrayArray, Array(DateTime64(3, 'UTC'))),

    -- ---------------------------------------------------------------------
    -- Session-static dimensions, anchored to the FIRST VideoSessionStart.
    --
    -- ONE argMin over a named tuple rather than six separate argMins, so every
    -- dimension provably comes from the SAME Start row. Six independent argMins
    -- could each break a tie differently and assemble a session that never
    -- existed. 13 sessions have duplicate Starts; row_version breaks the tie
    -- deterministically so the winner is identical on every machine and rerun.
    -- ---------------------------------------------------------------------
    start_anchor AggregateFunction(
        argMin,
        Tuple(
            video_session_id String,
            user_key         UInt64,
            user_id          String,
            content_id       Int64,
            platform         String,
            app_version      String,
            country          String
        ),
        Tuple(DateTime64(3, 'UTC'), UInt64)
    ),

    -- Landed rows, NOT distinct events: this is a plain sum and a re-delivered
    -- batch inflates it. Named for what it is. The distinct-event count is
    -- derivable at read time from the array lengths.
    landed_rows SimpleAggregateFunction(sum, UInt64)
)
ENGINE = SharedAggregatingMergeTree('/clickhouse/tables/{uuid}/{shard}', '{replica}')
PARTITION BY session_start_date
-- session_key leads: the only read is "give me these N touched sessions", a
-- point lookup. The partition key already segments by date, and a session lives
-- in exactly one partition, so aggregation per (partition, session_key) is
-- aggregation per session.
ORDER BY (session_key)
COMMENT 'Per-session commutative state. Insert-time MV target; read with -Merge, never assume a merge has run.';


-- =============================================================================
-- The maintaining MV.
--
-- Reads events_clean, NOT events_dedup: an incremental MV cannot read a view,
-- and it does not need to. Every aggregate here is a set union or an extremum,
-- so duplicate rows are already harmless — dedup is only required where ORDER
-- matters, and nothing here is ordered. (landed_rows is the one exception, and
-- it is labelled as a landed count for that reason.)
--
-- Strictly block-local: every output is an aggregate over the inserted block
-- alone. No lead/lag, no lookup against another block, no cross-block state.
-- That is what makes it correct under insert-block scoping.
-- =============================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS {{db}}.clean_to_session_state_mv
TO {{db}}.session_state
AS
SELECT
    toDate(session_start_ts) AS session_start_date,
    session_key,

    -- Sentinel-carrying mins. See the header: minIf would erase these on merge.
    min(if(signal = 'session_start', event_ts, toDateTime64('2299-12-31 23:59:59.999', 3, 'UTC'))) AS lifecycle_start,
    min(if(signal = 'session_end',   event_ts, toDateTime64('2299-12-31 23:59:59.999', 3, 'UTC'))) AS first_end,
    max(event_ts) AS last_event,

    groupUniqArrayIf(event_ts, signal = 'background')            AS bg_ts,
    groupUniqArrayIf(event_ts, signal = 'foreground')            AS fg_ts,
    groupUniqArrayIf(event_ts, signal IN ('play', 'resume'))     AS play_start_ts,
    groupUniqArrayIf(event_ts, signal IN ('pause', 'error'))     AS play_stop_ts,
    groupUniqArrayIf(event_ts, signal IN ('play', 'resume', 'liveness')) AS signal_ts,

    argMinStateIf(
        tuple(video_session_id, user_key, user_id, content_id, platform, app_version, country),
        tuple(event_ts, row_version),
        signal = 'session_start'
    ) AS start_anchor,

    toUInt64(count()) AS landed_rows
FROM {{db}}.events_clean
GROUP BY session_start_date, session_key;

-- Read pattern for the derivation:
--
--   SELECT session_key,
--          min(lifecycle_start)                  AS lifecycle_start,
--          min(first_end)                        AS first_end,
--          max(last_event)                       AS last_event,
--          groupUniqArrayArray(bg_ts)            AS bg_ts,
--          ...
--          argMinMerge(start_anchor)             AS start_anchor
--   FROM session_state
--   WHERE session_key IN {session_keys:Array(UInt64)}
--   GROUP BY session_key
--
-- SimpleAggregateFunction columns are read with the plain function (min/max/
-- groupUniqArrayArray); start_anchor needs argMinMerge because it is a full
-- AggregateFunction. Then start_anchor.platform, start_anchor.content_id, etc.
-- Never read part-rows directly: they are partial states until merged.
