-- =============================================================================
-- 012_session_live_state.sql — current per-session state, for "who is live NOW"
--
-- This table answers a question none of the serving tables can. The concurrency
-- rollups are a HISTORICAL CURVE: they are built from sealed interval time and
-- bucketed on a grid, so the freshest thing they can say is "at 10:59:50 there
-- were N". "Is session X open right this second" is a question about the OPEN
-- TAIL, which is exactly the part a curve deliberately does not publish.
--
-- WHY THE COLUMNS ARE NOT OURS
-- ---------------------------------------------------------------------------
-- The sibling pipeline in `sonyliv` (pipeline/sql/020_serving_layer.sql) already
-- defines a table of this name, and the dashboard's Live sessions panel is one
-- statement pointed at whichever database the reader picked. So this DDL is a
-- deliberate, exact copy of that column list and those types — names, order,
-- aggregate signatures and sort key — because a single column disagreeing turns
-- "one query serves both datasets" into two queries that drift. If that file
-- changes shape, this one has to change with it.
--
-- The types are copied verbatim from SHOW CREATE TABLE on the live service, not
-- retyped from intent. Two things about them are easy to get wrong:
--
--   * the dimension columns are AggregateFunction(argMax, String, UInt64) and
--     NOT LowCardinality(String). The server drops the LowCardinality wrapper
--     inside an AggregateFunction, so declaring it makes the DDL disagree with
--     SHOW CREATE TABLE for no benefit. Our session_intervals stores them AS
--     LowCardinality, so the writer has to toString() them on the way in.
--   * the ordering argument of every argMax is UInt64, and that type is part of
--     the AggregateFunction's IDENTITY rather than a value that gets coerced. A
--     bare integer literal parses as UInt8 and the insert then fails outright.
--     015_session_live_state.sql pins it with toUInt64 for that reason.
--
-- WHY AggregatingMergeTree AND NOT ReplacingMergeTree
-- ---------------------------------------------------------------------------
-- Consistent with the rest of this schema, the answer must be correct against a
-- table on which NO MERGE HAS RUN. A Replacing table keyed on session_key gives
-- the right answer only after a merge collapses the revisions, and merges are
-- eventual — on this service a two-part partition sat unmerged for nearly two
-- hours with no merge scheduled. -State columns read back through -Merge under
-- GROUP BY are exact at zero merges, which is why the table comment says
-- argMaxMerge and says never FINAL.
--
-- One row is written PER RECOMPACTION PASS per session, not one row per session.
-- state_revision (our session_intervals.version, ms since epoch at recompute
-- time) is the argMax ordering key, so the newest pass wins and older revisions
-- are inert until a merge folds them away.
--
-- THE LEASE IS EVALUATED AT READ TIME
-- ---------------------------------------------------------------------------
-- lease_expiry is a wall-clock instant at which, by definition, NO EVENT
-- ARRIVES. Nothing can be written when it passes — ClickHouse has no primitive
-- that fires on absence — so the reader compares it to now64(3) itself:
--
--     SELECT count() AS live_now
--     FROM (
--         SELECT session_key,
--                argMaxMerge(lease_expiry)  AS lease_expiry,
--                argMaxMerge(is_active_now) AS active,
--                argMaxMerge(is_terminated) AS terminated
--         FROM {{db}}.session_live_state
--         WHERE policy_version = 'sonyliv-active-v1'
--         GROUP BY session_key
--     )
--     WHERE terminated = 0 AND active = 1 AND lease_expiry > now64(3, 'UTC')
--
-- SORT KEY (policy_version, session_key), matching the sibling. policy_version
-- leads so two contested semantics can sit side by side, and with it pinned by
-- the WHERE clause GROUP BY session_key is an exact sort-key prefix and streams
-- rather than re-sorting. ORDER BY is immutable, so it is this or never.
--
-- Not partitioned: one row per session per pass at this size does not need it,
-- and a partition key would have to be derived from something stable, which
-- rules out every column here except session_key itself.
-- =============================================================================

CREATE TABLE IF NOT EXISTS {{db}}.session_live_state
(
    policy_version      LowCardinality(String) COMMENT 'Semantic contract; see solution/policy.yaml',
    session_key         UInt64,

    -- Monotone by construction (session_intervals.version, ms since epoch at
    -- recompute time), so max is correct here where it is wrong for every field
    -- below — max of a lease_expiry across revisions would resurrect a stale
    -- longer lease that a later pass had already shortened.
    state_revision      SimpleAggregateFunction(max, UInt64),

    -- End of the session's LAST interval, which our interval builder already
    -- computes as least(next_event_time, last_eligible_signal + heartbeat lease)
    -- — so for an open session it IS the lease expiry, with no second definition
    -- of the lease anywhere. Compared against now64(3) at read time, never
    -- pre-evaluated. A terminated session carries its terminal_end_time instead.
    lease_expiry        AggregateFunction(argMax, DateTime64(3, 'UTC'), UInt64),

    -- The three-axis conjunction (started AND not ended AND foreground AND
    -- playing) still holding at the end of observed history, which our builder
    -- expresses as "the last interval's lease outlives the ingest watermark".
    -- Not "the last event was not a pause".
    is_active_now       AggregateFunction(argMax, UInt8, UInt64),

    -- A VideoSessionEnd was observed. Distinct from an expired lease: a
    -- terminated session can never come back, a lapsed one can.
    is_terminated       AggregateFunction(argMax, UInt8, UInt64),

    -- Start of the currently-open interval, if any; the epoch when there is
    -- none. This interval is the open tail the rollups deliberately do not seal.
    open_interval_start AggregateFunction(argMax, DateTime64(3, 'UTC'), UInt64),

    user_key            AggregateFunction(argMax, UInt64, UInt64),
    content_id          AggregateFunction(argMax, Int64,  UInt64),

    -- String, not LowCardinality(String) — see the header. This is what the
    -- server stores and what SHOW CREATE TABLE reports on both databases.
    platform            AggregateFunction(argMax, String, UInt64),
    country             AggregateFunction(argMax, String, UInt64),
    video_type          AggregateFunction(argMax, String, UInt64),

    recompacted_at      SimpleAggregateFunction(max, DateTime64(3, 'UTC'))
)
-- AggregatingMergeTree, NOT SharedAggregatingMergeTree. Cloud substitutes the
-- Shared engine silently and SHOW CREATE TABLE then reports it; writing it here
-- would make this file unloadable against the local Docker ClickHouse the tests
-- run on, for a difference the server makes for us anyway.
ENGINE = AggregatingMergeTree
ORDER BY (policy_version, session_key)
SETTINGS
    -- The project rule, stated on every MergeTree table here: which of these
    -- applies is decided by the engine, not by this file. A local MergeTree
    -- honours the non_replicated_* window and ignores the rest; the Shared
    -- engine Cloud creates does the opposite, and its time window defaults to
    -- one hour — so setting only the first works on a laptop and silently
    -- doubles the table in production an hour later.
    non_replicated_deduplication_window = 1000,
    replicated_deduplication_window = 1000,
    replicated_deduplication_window_seconds = 2592000
COMMENT 'Current per-session state. Read via argMaxMerge GROUP BY session_key, never FINAL.';

-- CREATE TABLE IF NOT EXISTS above is a no-op against a database that already
-- has this table, so the settings correction would never reach one. This is what
-- makes `schema` converge rather than merely not-fail: metadata-only, costs
-- nothing, and re-running it changes nothing.
ALTER TABLE {{db}}.session_live_state
    MODIFY SETTING
        non_replicated_deduplication_window = 1000,
        replicated_deduplication_window = 1000,
        replicated_deduplication_window_seconds = 2592000;

-- RETENTION IS DELIBERATELY ABSENT, matching the sibling and for the same sharp
-- reason: any deletion must remove ALL revisions of a session or none. Delete
-- one revision and leave an older one behind and the older one wins the argMax,
-- resurrecting stale state with no error anywhere. That rules out the obvious
-- `TTL lease_expiry + INTERVAL n DAY` outright — TTL is evaluated per row at
-- merge time and revisions of one session carry different lease_expiry values,
-- so it deletes them piecemeal. The safe form is a whole-key
-- DELETE WHERE session_key IN (...) sweep, which is not implemented here.
