-- ============================================================================
-- Stage 01 target: normalized active viewing intervals.
--
-- One row per stretch of genuinely active viewing, per session, per clip
-- variant. This is the only thing stages 02+ read; nothing downstream touches
-- events_clean or events_raw again.
--
-- Apply with:
--   clickhouse-client --multiquery < pipeline/sql/010_active_intervals.sql
--
-- Idempotent and converging: CREATE TABLE IF NOT EXISTS is a no-op against an
-- existing table, so the settings corrections are re-issued as ALTER ... MODIFY
-- SETTING (metadata-only). A table created by an earlier version of this file
-- is fixed by running it again rather than rebuilt. Same pattern as
-- ingest/sql/002_events_raw.sql.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- active_intervals
--
-- SORT KEY. Exactly three readers touch this table, and the key serves them:
--
--   1. active_intervals_current  GROUP BY policy_version, clip_variant, session_key
--                                -- every downstream read goes through this
--   2. stage 02 (deltas)         reads a whole policy+variant slice
--   3. correction lane           WHERE session_key IN (...)
--
--   policy_version   1 value today; 2-3 if we publish side-by-side answers under
--                    contested semantics, as COMPARISON.md commits to. Prunes
--                    nothing right now -- but ORDER BY is immutable, so it is
--                    either here or never. A thin bet, taken deliberately.
--   clip_variant     2 values. Every reader picks exactly one, so this genuinely
--                    halves the scan.
--   session_key      10,866 values. The correction lane's lookup key -- the only
--                    lookup-shaped read this table gets.
--   start_time       Highest cardinality, last. Also leaves stage 02's output
--                    pre-sorted.
--
-- The first three columns are exactly the resolution view's GROUP BY, in order,
-- so that grouping can stream instead of re-sorting. That property is the main
-- reason this key looks the way it does.
--
-- session_start_date is deliberately NOT here, though an earlier draft had it
-- between clip_variant and session_key. It serves no reader: stage 02 needs
-- intervals that OVERLAP a service day (a start_time/end_time range), not ones
-- whose session happened to start that day -- a 43-hour session starting on the
-- 24th still contributes to the 26th. And sitting mid-key it broke the view's
-- GROUP BY prefix, taxing the one read everything depends on.
--
-- Scale honesty: 31,947 intervals x 2 variants = 63,894 rows at 8,192 rows per
-- granule -- about eight granules. No sort key prunes meaningfully across eight
-- granules. This choice is about the aggregation-in-order property above and
-- about behaviour at 100x, NOT about today's latency.
--
-- Not partitioned, on purpose: same reasoning at this size. Partitioning would
-- add parts and buy nothing, and TRUNCATE covers the wipe between the tuning day
-- and the unseen day. See ClickHouse guidance on starting without partitioning.
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS sonyliv.active_intervals
(
    policy_version      LowCardinality(String) COMMENT 'Semantic contract that produced this row; see solution/policy.yaml',

    -- 'unclipped': an open session runs to last_eligible_signal + timeout, which
    --              can land after the last event we ever observed.
    -- 'clipped':   the same interval, truncated at the observation horizon.
    -- Both are built every run. Which one is authoritative is a judgement call
    -- against a private answer key, so the pipeline refuses to make it silently.
    clip_variant        Enum8('unclipped' = 1, 'clipped' = 2),

    -- Retained as a plain column, not a sort-key column. Useful for eyeballing
    -- and for joining back to dirty_sessions, but it prunes nothing that matters
    -- here -- see the sort-key note above for why it was taken out of the key.
    session_start_date  Date,

    session_key         UInt64 COMMENT 'Joins to events_clean.session_key and dirty_sessions.session_key',
    user_key            UInt64 COMMENT 'Canonical user, anchored on the first VideoSessionStart',

    -- Presentation ordering ONLY. Never a join key, never an identity.
    -- row_number() is positional: a late event that inserts an interval in the
    -- middle of a session renumbers every interval after it. Corrections diff
    -- boundary timestamps, which do not shift. Joining on this would report
    -- three intervals changed when one was added.
    -- Measured: max 167 intervals in one session, p99 11, mean 2.94. UInt16
    -- leaves room; UInt8 would be 1.5x headroom against a 255 ceiling.
    interval_index      UInt16,

    start_time          DateTime64(3, 'UTC') COMMENT 'Inclusive. Half-open interval [start_time, end_time)',
    end_time            DateTime64(3, 'UTC') COMMENT 'Exclusive',

    -- Int64, not Int32, deliberately. The catalogue spans -987,654,322 to
    -- 2,078,179,327 and Int32 tops out at 2,147,483,647 -- it fits today with
    -- 3.2% headroom, which is too thin for a catalogue that grows.
    content_id          Int64,

    platform            LowCardinality(String),   -- 10 distinct
    country             LowCardinality(String),   -- 1 distinct in the extract, retained for unseen-day correctness
    video_type          LowCardinality(String),   -- resolved from content_dict at build time

    -- Append-only revision history. A rebuild of one session writes a higher
    -- revision rather than mutating; readers resolve to the winning revision.
    -- Read through active_intervals_current, never this table directly.
    state_revision      UInt64,

    built_at            DateTime64(3, 'UTC') DEFAULT now64(3, 'UTC')
)
ENGINE = MergeTree
ORDER BY (policy_version, clip_variant, session_key, start_time)
SETTINGS
    -- Without these, a re-run of stage 01 is a no-op for exactly one hour and
    -- then silently doubles the table. ClickHouse Cloud substitutes
    -- SharedMergeTree for MergeTree, which reads the *replicated* window and
    -- expires it after replicated_deduplication_window_seconds -- server default
    -- 3600. The non-replicated window has no time component at all, so a laptop
    -- would never reveal this. Matches ingest/sql/002_events_raw.sql, which had
    -- to be corrected for the same reason.
    non_replicated_deduplication_window = 1000,
    replicated_deduplication_window = 1000,
    replicated_deduplication_window_seconds = 2592000;


-- CREATE TABLE IF NOT EXISTS does nothing to a table that already exists, so a
-- database built by an earlier version of this file would keep the server
-- defaults forever and the correction would never arrive. Converge explicitly.
ALTER TABLE sonyliv.active_intervals
    MODIFY SETTING
        non_replicated_deduplication_window = 1000,
        replicated_deduplication_window = 1000,
        replicated_deduplication_window_seconds = 2592000;


-- ----------------------------------------------------------------------------
-- active_intervals_current
--
-- READ THIS, NOT active_intervals.
--
-- The base table keeps every revision of every session. Resolving to the
-- winning revision is not optional -- a query that forgets counts a session's
-- intervals once per rebuild. Making it a view means downstream code cannot
-- forget, which is the same reason events_dedup exists over events_clean.
--
-- Why not ReplacingMergeTree, which is the usual answer for this shape: it
-- replaces rows sharing a sort key, but a session's interval *set* can shrink.
-- A late pause that removes an interval leaves an orphan row at a start_time
-- the new revision never writes, so nothing replaces it. Only whole-set
-- resolution by revision is correct here.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW sonyliv.active_intervals_current AS
SELECT *
FROM sonyliv.active_intervals
WHERE (policy_version, clip_variant, session_key, state_revision) IN
(
    SELECT
        policy_version,
        clip_variant,
        session_key,
        max(state_revision)
    FROM sonyliv.active_intervals
    GROUP BY policy_version, clip_variant, session_key
);
