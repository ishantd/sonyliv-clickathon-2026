-- =============================================================================
-- 002_raw_events.sql — append-only landing table + in-table normalization
--
-- This is the ingestion boundary. Everything downstream (session compaction,
-- interval extraction, boundary deltas, the minute serving cache) reads from
-- here and never from the CSV or the producer.
-- =============================================================================

CREATE TABLE IF NOT EXISTS {{db}}.sl_raw_events
(
    -- ---------------------------------------------------------------------
    -- Ingest lineage. Present so that "which pipeline run produced this row"
    -- is answerable from the data itself — the problem statement scores
    -- pipeline evidence, and an unattributable row is not evidence.
    -- ---------------------------------------------------------------------
    ingest_batch_id     UUID COMMENT 'Deterministic per (source, batch_ordinal); stable across replays' CODEC(ZSTD(1)),

    -- Row position inside the batch. Rows are stored in ORDER BY sequence, not
    -- arrival sequence, so this column is scrambled on disk and does not
    -- delta-compress. T64 transposes the bit planes — the values only occupy
    -- ~17 of 32 bits — which recovers most of the loss regardless of order.
    batch_row_seq       UInt32 COMMENT 'Row position inside the batch; batch_id+seq is a stable row address' CODEC(T64, ZSTD(1)),

    -- Server receive time. Real lateness is ingested_at - event_time; the CSV
    -- cannot supply it (its row order is session-major, not arrival order) but
    -- a live producer can, which is what makes a lateness SLO measurable.
    ingested_at         DateTime64(3, 'UTC') DEFAULT now64(3) CODEC(DoubleDelta, ZSTD(1)),

    -- NOTE: there is deliberately no stored row-fingerprint column here.
    --
    -- A 64-bit hash of the row is, by construction, incompressible: measured at
    -- 1x it was 6.16 MiB of a 17.34 MiB table — 35% of on-disk size at a
    -- compression ratio of 1.0 — for a column no hot-path query reads. Exact
    -- duplicates already sort adjacently under the ORDER BY below, and the
    -- touched-session read is a few hundred rows, so the fingerprint is cheaper
    -- to compute on demand than to store. Computing it server-side also removes
    -- the risk of a client and the server disagreeing on the canonical form.
    --
    -- The canonical fingerprint, used by `sonyliv-ingest verify`:
    --
    --   xxHash64(concatWithSeparator('\x1F',
    --       video_session_id, user_id, toString(content_id),
    --       event_type, event, toString(toUnixTimestamp64Milli(event_time)),
    --       platform, app_version, country,
    --       audio_language, subtitle_language, player_version,
    --       toString(toUnixTimestamp64Milli(session_start_time))))

    -- ---------------------------------------------------------------------
    -- Source-faithful payload. Typed, but NOT semantically altered: this table
    -- must stay re-derivable, so no value is corrected, coalesced or dropped
    -- here. Normalization is additive (materialized columns below).
    -- ---------------------------------------------------------------------

    -- 64-char uppercase hex. FixedString(64) rather than String: the length is
    -- guaranteed by the source, so this drops the per-value length prefix and
    -- makes the ORDER BY prefix a fixed-width compare.
    -- Not LowCardinality: 10,866 sessions at 1x but ~1.09M at 100x, past the
    -- point where dictionary encoding helps.
    -- [official: schema-types-native-types, schema-types-lowcardinality]
    video_session_id    FixedString(64),
    user_id             FixedString(64),

    content_id          Int64 COMMENT 'Signed: catalogue contains a negative id stored unsigned',

    -- event_type is left open (LowCardinality(String), not Enum) on purpose:
    -- the dictionary lists 7 types but the unseen day may introduce more, and
    -- an Enum would reject the entire insert block rather than land the row.
    -- The closed, validated classification lives in `signal` below.
    event_type          LowCardinality(String),
    event               LowCardinality(String) COMMENT '47 distinct values; 41 hide under event_type=VideoHeartbeat',

    -- DoubleDelta: event_time is the second ORDER BY column, so within each
    -- session it is stored ascending and the second differences are tiny.
    event_time          DateTime64(3, 'UTC') COMMENT 'Event time. The only time axis concurrency is computed on.' CODEC(DoubleDelta, ZSTD(1)),
    session_start_time  DateTime64(3, 'UTC') COMMENT 'From session_start_epoch; constant per session in the extract' CODEC(DoubleDelta, ZSTD(1)),

    platform            LowCardinality(String),
    app_version         LowCardinality(String),
    country             LowCardinality(String),
    audio_language      LowCardinality(String),
    subtitle_language   LowCardinality(String),
    player_version      LowCardinality(String),

    -- ---------------------------------------------------------------------
    -- Normalization — computed server-side at insert, stored alongside the
    -- source value rather than replacing it.
    --
    -- Placed here rather than in the Go producer for one reason: it must be
    -- identical for every producer forever (CSV backfill, live generator, a
    -- future Kafka consumer). A normalization rule that lives in one client is
    -- a rule that will eventually differ between clients.
    -- [derived from decision-real-time-preaggregation: transformation that is
    --  row-local and deterministic belongs at the insert boundary]
    -- ---------------------------------------------------------------------

    event_date          Date MATERIALIZED toDate(event_time),

    -- Language fields are case-inconsistent by event type: VideoSessionStart
    -- emits lowercase 'unk'/'' while later events emit 'UNK'/'OFF'/'ENG', and
    -- some carry an 'eng-English' suffix form. Without this, every GROUP BY
    -- double-counts OFF/off and UNK/unk.
    -- 'off' is preserved as a distinct value: explicitly-disabled subtitles are
    -- not the same fact as unknown subtitles.
    audio_language_norm LowCardinality(String) MATERIALIZED
        if(lowerUTF8(splitByChar('-', trimBoth(audio_language))[1]) IN ('', 'unk', 'und', 'null', 'unknown'),
           'unknown',
           lowerUTF8(splitByChar('-', trimBoth(audio_language))[1])),

    subtitle_language_norm LowCardinality(String) MATERIALIZED
        if(lowerUTF8(splitByChar('-', trimBoth(subtitle_language))[1]) IN ('', 'unk', 'und', 'null', 'unknown'),
           'unknown',
           lowerUTF8(splitByChar('-', trimBoth(subtitle_language))[1])),

    player_version_norm LowCardinality(String) MATERIALIZED
        if(empty(trimBoth(player_version)), 'unknown', trimBoth(player_version)),

    -- The single most valuable normalization in the whole pipeline: collapse 47
    -- inconsistently-cased event names into the closed set the concurrency
    -- state machine actually branches on. Pause/resume exist ONLY as lowercase
    -- heartbeat sub-events; a state machine reading event_type alone cannot see
    -- them at all.
    --
    -- Closed set, guaranteed by the trailing 'liveness' fallback, so Enum8 is
    -- safe and validates. Adding a class later is a metadata-only ALTER.
    -- [official: schema-types-enum]
    signal Enum8(
        'liveness'      = 1,
        'session_start' = 2,
        'session_end'   = 3,
        'play'          = 4,
        'pause'         = 5,
        'resume'        = 6,
        'background'    = 7,
        'foreground'    = 8,
        'error'         = 9
    ) MATERIALIZED multiIf(
        event_type = 'VideoSessionStart', 'session_start',
        event_type = 'VideoSessionEnd',   'session_end',
        event_type = 'VideoPlay',         'play',
        event_type = 'AppBackgrounded',   'background',
        event_type = 'AppForegrounded',   'foreground',
        event_type = 'VideoError',        'error',
        lowerUTF8(event) IN ('pause',  'adpause',  'speed-pause'),  'pause',
        lowerUTF8(event) IN ('resume', 'adresume', 'speed-resume'), 'resume',
        'liveness'
    ),

    -- The genuinely periodic ping is the {network-activity, buffer-health,
    -- video-resize} trio emitted at one identical millisecond — 53.69% of all
    -- rows. Flagged so the hot path can exclude or TTL it, but NOT used as the
    -- liveness signal: 74.4% of IPHONE sessions never emit the trio, so a
    -- trio-only liveness rule silently drops most iOS traffic.
    is_periodic_ping Bool MATERIALIZED
        event IN ('network-activity', 'buffer-health', 'video-resize'),

    -- Skipping index on event_time. The sort key leads with video_session_id,
    -- so a time-ranged scan has no primary-index support; because a session's
    -- events are tightly time-clustered (p50 span ~12 min) the per-granule
    -- min/max of event_time is narrow and prunes well.
    -- [official: query-index-skipping-indices]
    INDEX idx_event_time  event_time TYPE minmax    GRANULARITY 4,
    INDEX idx_signal      signal     TYPE set(9)    GRANULARITY 4
)
ENGINE = MergeTree
-- Partition on session start, not event time. session_start_time is constant
-- per session, so every event of a session — including the 43.6h outlier and
-- any late correction that arrives days later — lands in exactly ONE partition.
-- The touched-session read (the only hot read on this table) therefore never
-- fans out across partitions.
-- Daily granularity is for lifecycle (DROP PARTITION / TTL), not for query
-- pruning. [official: schema-partition-lifecycle]
-- At >2y retention switch to toYYYYMM to stay inside the 100-1,000 partition
-- guidance. [official: schema-partition-low-cardinality]
PARTITION BY toYYYYMMDD(session_start_time)
-- Deliberate exception to "order low-cardinality first".
-- [official rule: schema-pk-cardinality-order — overridden here, with cause]
--
-- The only hot read on raw is "give me the complete history of these N touched
-- sessions, in event-time order". That is a high-cardinality point lookup, and
-- a session-leading key turns it into a handful of granules. Dashboard filters
-- (platform / content / time) never touch this table — they are served from the
-- pre-aggregated boundary and minute tables, which order low-cardinality-first
-- as the rule prescribes.
-- Putting platform or event_date first here would serve no query and would
-- destroy the one access pattern that matters.
--
-- Secondary benefit: the source file is already session-major, so this ordering
-- also gives near-optimal compression on the ingest path — the two 64-char hex
-- id columns compress ~58x because equal values are adjacent.
--
-- Byte-identical duplicate rows share every key column and therefore land in
-- consecutive positions, which is what makes duplicate detection a local scan
-- rather than a global hash aggregation.
ORDER BY (video_session_id, event_time, event_type, event)
SETTINGS
    -- Enables insert_deduplication_token on a non-replicated MergeTree, so a
    -- crashed loader can safely replay the same batch locally. Replicated /
    -- SharedMergeTree (ClickHouse Cloud) dedupes via replicated_deduplication_window
    -- and ignores this. 1000 blocks x 50K rows = 50M rows of retry protection.
    non_replicated_deduplication_window = 1000
COMMENT 'Append-only event landing table. Never mutated: corrections arrive as new rows.';


-- =============================================================================
-- Touched-session queue
--
-- An incremental materialized view is used here and ONLY here, because this is
-- the one derivation that is correct block-locally: "which sessions appear in
-- the block I just inserted". It never needs to see another block.
--
-- What an incremental MV must NOT be asked to do on this stream — and the
-- reason the concurrency model is not an MV over raw events:
--   * lead/lag across events (the next event may be in another block)
--   * "was this session foregrounded before?" (prior state is in another block)
--   * retract previously emitted output (an MV only appends)
-- 99.65% of sessions contain at least one out-of-order event, so any of the
-- above would be wrong for nearly every session.
-- [official: query-mv-incremental — incremental MVs are insert-block scoped]
-- =============================================================================

CREATE TABLE IF NOT EXISTS {{db}}.sl_dirty_sessions
(
    video_session_id     FixedString(64),
    session_start_date   Date,
    ingest_batch_id      UUID,
    max_batch_row_seq    UInt32,
    last_ingested_at     DateTime64(3, 'UTC'),
    event_count          UInt32,
    min_event_time       DateTime64(3, 'UTC'),
    max_event_time       DateTime64(3, 'UTC'),

    -- Deterministic identity for the work item. A replayed insert produces the
    -- same id, so the downstream "has this been applied?" check is a set
    -- membership test rather than a guess.
    dirty_operation_id   UInt64 MATERIALIZED
        xxHash64(concatWithSeparator('\x1F',
            video_session_id, toString(ingest_batch_id), toString(max_batch_row_seq)))
)
ENGINE = MergeTree
ORDER BY (session_start_date, video_session_id, last_ingested_at, ingest_batch_id)
COMMENT 'Append-only work queue: sessions whose history changed and must be recompacted.';

CREATE MATERIALIZED VIEW IF NOT EXISTS {{db}}.sl_raw_to_dirty_mv
TO {{db}}.sl_dirty_sessions
AS
SELECT
    video_session_id,
    toDate(session_start_time) AS session_start_date,
    ingest_batch_id,
    max(batch_row_seq)         AS max_batch_row_seq,
    max(ingested_at)           AS last_ingested_at,
    count()                    AS event_count,
    min(event_time)            AS min_event_time,
    max(event_time)            AS max_event_time
FROM {{db}}.sl_raw_events
GROUP BY video_session_id, session_start_date, ingest_batch_id;
