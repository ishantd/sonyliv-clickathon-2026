-- =============================================================================
-- 015_session_live_state.sql — session_intervals -> session_live_state
--
-- Runs as the SECOND statement of the intervals layer, immediately after
-- 010_recompute_sessions.sql and under the SAME version, so the two can never
-- describe different generations of the same session. It is not a layer of its
-- own and there is no flag for it: the only thing that can change a session's
-- current state is a recompute of that session's intervals, so anywhere else it
-- would either run too often or go stale.
--
-- WHAT THIS IS FOR
-- ---------------------------------------------------------------------------
-- The serving rollups are a historical curve on a bucket grid. They cannot
-- answer "is this session open right now", because the open tail is precisely
-- the part a curve must not publish — an open session's trailing interval end
-- moves forward with every liveness ping, so publishing it would mean retracting
-- and re-adding a boundary per ping. session_live_state carries that tail
-- instead, one row per session per recompaction pass.
--
-- NO SECOND DEFINITION OF "ACTIVE"
-- ---------------------------------------------------------------------------
-- Every field below is read off the intervals 010 already produced. Nothing here
-- re-derives liveness from events, and that is the point: 010 owns the state
-- machine (started AND not ended AND foreground AND playing, three independent
-- axes) and this file owns nothing but a projection of its output.
--
-- The lease in particular is NOT recomputed. 010 closes each segment at
--
--     end_time = least(next_event_time, last_eligible_signal + heartbeat_timeout)
--
-- and for a session with no later event the first term defaults to
-- evaluation_as_of + heartbeat_timeout. So the LAST interval's end_time is
-- already `last_eligible_signal + the heartbeat lease` for any session whose
-- lease is what closed it, and taking it verbatim is the only way to be sure the
-- panel and the rollups agree about when a session went quiet. Adding the
-- timeout again here — the obvious reading of "last interval end plus the lease"
-- — would double-count it and hold every lapsed session open for a further 120s.
--
-- Because the intervals are sorted by start and provably disjoint (010's island
-- merge), the last element carries both the latest start and the latest end, so
-- intervals[-1] is the open interval if any is.
--
-- Parameters (textual {{db}}; the rest bound server-side):
--   {session_keys:Array(UInt64)}  workset; EMPTY ARRAY means "every session"
--   {evaluation_as_of:String}     the ingest watermark, never a literal date
--   {policy_version:String}
--   {version:UInt64}              the SAME value 010 stamped, ms since epoch
--
-- ONE ROW PER PASS, NOT ONE ROW PER SESSION. state_revision is the argMax
-- ordering key, so a re-run at a HIGHER version strictly supersedes; a re-run at
-- the SAME version leaves two states tied on that key and the winner becomes
-- arbitrary. The caller therefore takes its version from the clock once per
-- pass and hands the same value to both statements.
-- =============================================================================

INSERT INTO {{db}}.session_live_state
(
    policy_version, session_key, state_revision, lease_expiry, is_active_now,
    is_terminated, open_interval_start, user_key, content_id,
    platform, country, video_type, recompacted_at
)
WITH
    -- toUInt64 is NOT redundant. The ordering argument's type is part of an
    -- AggregateFunction's type IDENTITY, not a value that gets coerced: a bare
    -- literal parses as UInt8, producing argMax(DateTime64, UInt8), and the
    -- insert then fails with "Conversion from AggregateFunction(argMax,
    -- DateTime64(3,'UTC'), UInt8) to ... UInt64 is not supported". The bound
    -- parameter is already UInt64, so this only bites when the statement is
    -- pasted into a console with the value inlined — which is exactly what
    -- ch.sh --file does. Pinning it makes both paths behave the same.
    toUInt64({version:UInt64}) AS rev,
    toDateTime64({evaluation_as_of:String}, 3, 'UTC') AS evaluation_as_of,
    toDateTime64(0, 3, 'UTC') AS epoch
-- The per-session scalars are folded in the inner query and the -State functions
-- applied in the outer one. They cannot be combined: an aggregate inside an
-- aggregate is rejected outright. session_intervals FINAL already yields one row
-- per session, so the outer GROUP BY reshapes rather than aggregates.
SELECT
    {policy_version:String} AS policy_version,
    session_key,
    rev AS state_revision,

    argMaxState(lease_val,      rev) AS lease_expiry,
    argMaxState(active_val,     rev) AS is_active_now,
    argMaxState(terminated_val, rev) AS is_terminated,
    argMaxState(open_start_val, rev) AS open_interval_start,
    argMaxState(user_val,       rev) AS user_key,
    argMaxState(content_val,    rev) AS content_id,
    argMaxState(platform_val,   rev) AS platform,
    argMaxState(country_val,    rev) AS country,
    argMaxState(video_val,      rev) AS video_type,

    now64(3, 'UTC') AS recompacted_at
FROM
(
    SELECT
        session_key,

        -- The lease. For a live session this is 010's own
        -- last_eligible_signal + heartbeat_timeout; for a terminated one the
        -- End event is the hard stop and outlives nothing.
        if(has_terminal_end, terminal_end_time, last_end) AS lease_val,

        -- Active means the three-axis state was still holding when observation
        -- stopped: not terminated, and the lease reaches past the watermark.
        -- Compared against evaluation_as_of rather than now() deliberately —
        -- now() would claim the pipeline had seen events it has not received,
        -- and the reader re-checks lease_expiry against now64(3) anyway.
        toUInt8(NOT has_terminal_end AND last_end > evaluation_as_of) AS active_val,

        toUInt8(has_terminal_end) AS terminated_val,

        -- Only meaningful while the tail is open; the epoch otherwise, so a
        -- lapsed session cannot be mistaken for one that opened in 1970.
        if(NOT has_terminal_end AND last_end > evaluation_as_of, last_start, epoch) AS open_start_val,

        user_key                AS user_val,
        content_id              AS content_val,
        -- toString because session_intervals stores these LowCardinality and the
        -- target column is AggregateFunction(argMax, String, UInt64) — the server
        -- drops the LowCardinality wrapper inside an AggregateFunction, so being
        -- explicit here keeps the DDL and the writer visibly in agreement.
        toString(platform)      AS platform_val,
        toString(country)       AS country_val,
        toString(video_type)    AS video_val
    FROM
    (
        SELECT
            session_key, has_terminal_end, terminal_end_time,
            user_key, content_id, platform, country, video_type,
            -- Out-of-range arrayElement returns the element type's default, so
            -- these are the epoch for a session whose recompute produced an
            -- EMPTY interval array — the retraction case. Guarded explicitly
            -- anyway, because relying on that default is a footgun to read.
            if(empty(intervals), epoch, intervals[-1].2) AS last_end,
            if(empty(intervals), epoch, intervals[-1].1) AS last_start
        FROM {{db}}.session_intervals FINAL
        WHERE (empty({session_keys:Array(UInt64)}) OR session_key IN {session_keys:Array(UInt64)})
          AND policy_version = {policy_version:String}
    )
)
GROUP BY session_key
SETTINGS
    -- session_intervals partitions on session_start_date and never lets a
    -- session migrate, so FINAL can resolve inside one partition at a time.
    do_not_merge_across_partitions_select_final = 1,
    max_execution_time = 300;
