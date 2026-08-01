-- SonyLIV foreground-concurrency schema
-- ClickHouse 26.x; all timestamps are UTC and millisecond-precise.

CREATE DATABASE IF NOT EXISTS sonyliv;

CREATE TABLE IF NOT EXISTS sonyliv.content_dim
(
    content_id Int32 COMMENT 'Signed Int32: supplied range is -987654322..2078179327',
    title String,
    video_type LowCardinality(String) DEFAULT '__unknown__',
    category LowCardinality(String) DEFAULT '__unknown__',
    source_version UInt64,
    loaded_at DateTime64(3, 'UTC') DEFAULT now64(3)
)
ENGINE = ReplacingMergeTree(source_version)
ORDER BY content_id;

CREATE VIEW IF NOT EXISTS sonyliv.content_current AS
SELECT
    content_id,
    argMax(title, source_version) AS title,
    argMax(video_type, source_version) AS video_type,
    argMax(category, source_version) AS category
FROM sonyliv.content_dim
GROUP BY content_id;

-- Static challenge content can use LIFETIME(0). In production, use a refresh
-- lifetime and explicitly reprocess affected sessions when content attributes
-- change: a right-side dictionary change cannot retract old MV output.
CREATE DICTIONARY IF NOT EXISTS sonyliv.content_dictionary
(
    content_id Int32,
    title String,
    video_type String DEFAULT '__unknown__',
    category String DEFAULT '__unknown__'
)
PRIMARY KEY content_id
SOURCE(CLICKHOUSE(DB 'sonyliv' TABLE 'content_current'))
LIFETIME(0)
LAYOUT(HASHED());

CREATE TABLE IF NOT EXISTS sonyliv.raw_events
(
    ingest_batch_id UUID,
    ingest_version UInt64 COMMENT 'Row sequence inside the immutable batch; conflict order also uses server receive time and batch UUID',
    ingested_at DateTime64(3, 'UTC') DEFAULT now64(3),
    source_row_hash UInt128 COMMENT 'Fingerprint of the normalized full source row',

    video_session_id FixedString(64),
    user_id FixedString(64),
    content_id Int32,
    event_type LowCardinality(String) COMMENT 'Kept open for unseen event types',
    event LowCardinality(String),
    event_time DateTime64(3, 'UTC'),
    session_start_time DateTime64(3, 'UTC'),
    session_start_date Date MATERIALIZED toDate(session_start_time),

    platform LowCardinality(String),
    app_version LowCardinality(String),
    country LowCardinality(String),
    audio_language LowCardinality(String),
    subtitle_language LowCardinality(String),
    player_version LowCardinality(String)
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(session_start_time)
ORDER BY
(
    video_session_id,
    event_time,
    event_type,
    event,
    source_row_hash
);

-- An incremental MV may safely identify touched sessions because this operation
-- depends only on the inserted block. It must not derive cross-block state.
CREATE TABLE IF NOT EXISTS sonyliv.dirty_session_events
(
    video_session_id FixedString(64),
    ingest_batch_id UUID,
    max_batch_row_sequence UInt64,
    last_ingested_at DateTime64(3, 'UTC'),
    dirty_operation_id UInt128
)
ENGINE = MergeTree
ORDER BY
(
    video_session_id,
    last_ingested_at,
    ingest_batch_id,
    max_batch_row_sequence,
    dirty_operation_id
);

CREATE MATERIALIZED VIEW IF NOT EXISTS sonyliv.raw_to_dirty_sessions_mv
TO sonyliv.dirty_session_events
AS
SELECT
    video_session_id,
    ingest_batch_id,
    max(ingest_version) AS max_batch_row_sequence,
    max(ingested_at) AS last_ingested_at,
    reinterpretAsUInt128(
        sipHash128(video_session_id, ingest_batch_id, max(ingest_version))
    ) AS dirty_operation_id
FROM sonyliv.raw_events
GROUP BY video_session_id, ingest_batch_id;

CREATE TABLE IF NOT EXISTS sonyliv.applied_dirty_operations
(
    dirty_operation_id UInt128,
    adjustment_batch_id UUID,
    applied_at DateTime64(3, 'UTC'),
    state_revision UInt64
)
ENGINE = MergeTree
ORDER BY (dirty_operation_id, adjustment_batch_id);

CREATE TABLE IF NOT EXISTS sonyliv.compaction_worksets
(
    adjustment_batch_id UUID,
    video_session_id FixedString(64),
    dirty_operation_ids Array(UInt128),
    selected_at DateTime64(3, 'UTC')
)
ENGINE = MergeTree
ORDER BY (adjustment_batch_id, video_session_id);

CREATE TABLE IF NOT EXISTS sonyliv.affected_compaction_users
(
    adjustment_batch_id UUID,
    canonical_user_id FixedString(64)
)
ENGINE = MergeTree
ORDER BY (adjustment_batch_id, canonical_user_id);

-- Immutable revision history. Consumers obtain the current value with argMax
-- over the touched IDs; they do not rely on background replacement timing.
CREATE TABLE IF NOT EXISTS sonyliv.session_state_versions
(
    session_start_date Date,
    video_session_id FixedString(64),
    state_revision UInt64,
    processed_at DateTime64(3, 'UTC'),
    policy_version LowCardinality(String),

    canonical_user_id FixedString(64),
    content_id Int32,
    platform LowCardinality(String),
    app_version LowCardinality(String),
    country LowCardinality(String),
    video_type LowCardinality(String),

    has_terminal_end Bool,
    terminal_end_time DateTime64(3, 'UTC') DEFAULT toDateTime64(0, 3, 'UTC'),
    intervals Array(Tuple(start_time DateTime64(3, 'UTC'), end_time DateTime64(3, 'UTC'))),
    boundary_hash UInt128,
    source_event_count UInt32,
    anomaly_flags Array(LowCardinality(String))
)
ENGINE = ReplacingMergeTree(state_revision)
PARTITION BY toYYYYMM(session_start_date)
ORDER BY (session_start_date, video_session_id);

CREATE TABLE IF NOT EXISTS sonyliv.session_recompute_candidates
(
    adjustment_batch_id UUID,
    state_revision UInt64,
    oracle_run_id UUID,
    policy_version LowCardinality(String),
    session_start_date Date,
    video_session_id FixedString(64),
    canonical_user_id FixedString(64),
    content_id Int32,
    platform LowCardinality(String),
    app_version LowCardinality(String),
    country LowCardinality(String),
    video_type LowCardinality(String),
    has_terminal_end Bool,
    terminal_end_time DateTime64(3, 'UTC'),
    intervals Array(Tuple(start_time DateTime64(3, 'UTC'), end_time DateTime64(3, 'UTC'))),
    boundary_hash UInt128,
    source_event_count UInt32,
    staged_at DateTime64(3, 'UTC')
)
ENGINE = ReplacingMergeTree(state_revision)
ORDER BY (adjustment_batch_id, video_session_id);

CREATE TABLE IF NOT EXISTS sonyliv.user_recompute_candidates
(
    adjustment_batch_id UUID,
    state_revision UInt64,
    canonical_user_id FixedString(64),
    rollup_mask UInt16,
    platform LowCardinality(String),
    country LowCardinality(String),
    video_type LowCardinality(String),
    content_id Int32,
    intervals Array(Tuple(start_time DateTime64(3, 'UTC'), end_time DateTime64(3, 'UTC')))
)
ENGINE = ReplacingMergeTree(state_revision)
ORDER BY
(
    adjustment_batch_id,
    canonical_user_id,
    rollup_mask,
    platform,
    country,
    video_type,
    content_id
);

-- Current masked interval maps for differential comparison. Replacement is
-- read with argMax over scoped entity IDs; is_deleted tombstones removed keys.
CREATE TABLE IF NOT EXISTS sonyliv.entity_state_versions
(
    entity Enum8('session' = 1, 'user' = 2),
    source_entity_id FixedString(64),
    rollup_mask UInt16,
    platform LowCardinality(String),
    country LowCardinality(String),
    video_type LowCardinality(String),
    content_id Int32,
    state_revision UInt64,
    adjustment_batch_id UUID,
    policy_version LowCardinality(String),
    is_deleted Bool,
    intervals Array(Tuple(start_time DateTime64(3, 'UTC'), end_time DateTime64(3, 'UTC')))
)
ENGINE = ReplacingMergeTree(state_revision)
ORDER BY
(
    entity,
    source_entity_id,
    rollup_mask,
    platform,
    country,
    video_type,
    content_id
);

-- Normalized intervals are retained as an audit/oracle layer. The dashboard
-- reads the delta table below, not this table or raw_events.
CREATE TABLE IF NOT EXISTS sonyliv.active_intervals_reference
(
    oracle_run_id UUID,
    policy_version LowCardinality(String),
    session_start_date Date,
    video_session_id FixedString(64),
    canonical_user_id FixedString(64),
    interval_index UInt32,
    start_time DateTime64(3, 'UTC'),
    end_time DateTime64(3, 'UTC'),
    content_id Int32,
    platform LowCardinality(String),
    country LowCardinality(String),
    video_type LowCardinality(String)
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(session_start_date)
ORDER BY (oracle_run_id, session_start_date, video_session_id, start_time);

-- A processor writes one -1 row for the previous interval map and one +1 row
-- for the replacement map. rollup_mask/dimensions are already resolved here so
-- distinct-user intervals can be unioned correctly per requested slice.
CREATE TABLE IF NOT EXISTS sonyliv.entity_interval_changes
(
    adjustment_batch_id UUID,
    state_revision UInt64,
    processed_at DateTime64(3, 'UTC') DEFAULT now64(3),
    entity Enum8('session' = 1, 'user' = 2),
    source_entity_id FixedString(64),
    rollup_mask UInt16,
    platform LowCardinality(String),
    country LowCardinality(String),
    video_type LowCardinality(String),
    content_id Int32,
    change_sign Int8 COMMENT '+1 replacement interval map, -1 previous interval map',
    intervals Array(Tuple(start_time DateTime64(3, 'UTC'), end_time DateTime64(3, 'UTC')))
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(processed_at)
ORDER BY
(
    adjustment_batch_id,
    entity,
    source_entity_id,
    rollup_mask,
    platform,
    country,
    video_type,
    content_id,
    state_revision,
    change_sign
);

-- Append-only audit feed. Every row is an explicit correction contribution.
CREATE TABLE IF NOT EXISTS sonyliv.boundary_adjustments
(
    adjustment_operation_id UInt128,
    adjustment_batch_id UUID,
    state_revision UInt64,
    emitted_at DateTime64(3, 'UTC') DEFAULT now64(3),
    source_entity_id FixedString(64) COMMENT 'Session ID for session entity; canonical user ID for user entity',

    entity Enum8('session' = 1, 'user' = 2),
    rollup_mask UInt16,
    service_date Date,
    boundary_time DateTime64(3, 'UTC'),
    platform LowCardinality(String),
    country LowCardinality(String),
    video_type LowCardinality(String),
    content_id Int32,
    delta Int8 COMMENT 'Signed contribution: +1 start, -1 end, or inverse old boundary'
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(service_date)
ORDER BY
(
    entity,
    rollup_mask,
    service_date,
    platform,
    country,
    video_type,
    content_id,
    boundary_time,
    source_entity_id,
    state_revision,
    adjustment_operation_id
);

CREATE TABLE IF NOT EXISTS sonyliv.published_adjustment_batches
(
    adjustment_batch_id UUID,
    policy_version LowCardinality(String),
    pipeline_run_id UUID COMMENT 'Stable serving-pipeline lineage; distinct from a scoped reference oracle run',
    source_snapshot_hash FixedString(64),
    adjustment_block_hash FixedString(64),
    adjustment_rows UInt64,
    published_at DateTime64(3, 'UTC')
)
ENGINE = MergeTree
ORDER BY (adjustment_batch_id, adjustment_block_hash);

CREATE TABLE IF NOT EXISTS sonyliv.delta_snapshots
(
    source_delta_snapshot UInt128,
    policy_version LowCardinality(String),
    pipeline_run_id UUID,
    cutoff DateTime64(3, 'UTC'),
    adjustment_batches UInt64,
    adjustment_rows UInt64,
    adjustment_ledger_hash FixedString(64),
    created_at DateTime64(3, 'UTC')
)
ENGINE = MergeTree
ORDER BY (source_delta_snapshot, policy_version, pipeline_run_id);

-- The hot table contains only exact grouping keys and a signed measure.
-- SummingMergeTree merges are asynchronous, so every query still sum(delta)s.
CREATE TABLE IF NOT EXISTS sonyliv.concurrency_deltas
(
    entity Enum8('session' = 1, 'user' = 2),
    rollup_mask UInt16,
    service_date Date,
    boundary_time DateTime64(3, 'UTC'),
    platform LowCardinality(String),
    country LowCardinality(String),
    video_type LowCardinality(String),
    content_id Int32,
    delta Int64
)
ENGINE = SummingMergeTree(delta)
PARTITION BY toYYYYMM(service_date)
ORDER BY
(
    entity,
    rollup_mask,
    service_date,
    platform,
    country,
    video_type,
    content_id,
    boundary_time
);

-- This MV is correct because the source already contains explicit additive
-- corrections. A replacement/merge in session_state_versions is never expected
-- to retract anything downstream.
CREATE MATERIALIZED VIEW IF NOT EXISTS sonyliv.boundary_adjustments_mv
TO sonyliv.concurrency_deltas
AS
SELECT
    entity,
    rollup_mask,
    service_date,
    boundary_time,
    platform,
    country,
    video_type,
    content_id,
    sum(toInt64(delta)) AS delta
FROM sonyliv.boundary_adjustments
GROUP BY
    entity,
    rollup_mask,
    service_date,
    boundary_time,
    platform,
    country,
    video_type,
    content_id;

-- Immutable exact minute snapshots. A generation is built from concurrency_deltas
-- for an affected (day, entity, mask), validated, then published in the manifest.
-- Dashboard peak=max(minute_peak); dashboard average=sum(active_entity_ms)/range_ms.
CREATE TABLE IF NOT EXISTS sonyliv.concurrency_minute_versions
(
    generation UInt64,
    policy_version LowCardinality(String),
    pipeline_run_id UUID,
    source_delta_snapshot UInt128,
    entity Enum8('session' = 1, 'user' = 2),
    rollup_mask UInt16,
    service_date Date,
    minute_start DateTime64(3, 'UTC'),
    platform LowCardinality(String),
    country LowCardinality(String),
    video_type LowCardinality(String),
    content_id Int32,
    minute_peak UInt64,
    active_entity_ms UInt64,
    ending_concurrency UInt64,
    source_boundary_points UInt64
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(service_date)
ORDER BY
(
    generation,
    policy_version,
    pipeline_run_id,
    source_delta_snapshot,
    entity,
    rollup_mask,
    service_date,
    platform,
    country,
    video_type,
    content_id,
    minute_start
);

CREATE TABLE IF NOT EXISTS sonyliv.serving_generation_manifest
(
    service_date Date,
    entity Enum8('session' = 1, 'user' = 2),
    rollup_mask UInt16,
    generation UInt64,
    policy_version LowCardinality(String),
    pipeline_run_id UUID,
    source_delta_snapshot UInt128,
    published_at DateTime64(3, 'UTC'),
    answer_hash FixedString(64),
    minute_rows UInt64
)
ENGINE = MergeTree
ORDER BY (service_date, entity, rollup_mask, generation, published_at);

-- Session-independent comparison path. It asks only whether a session emitted a
-- liveness event inside the lease at a minute boundary; it cannot retract
-- paused/backgrounded time and is not the trusted foreground answer.
CREATE TABLE IF NOT EXISTS sonyliv.heartbeat_lease_minute_states
(
    generation UInt64,
    service_date Date,
    minute_start DateTime64(3, 'UTC'),
    platform LowCardinality(String),
    country LowCardinality(String),
    video_type LowCardinality(String),
    content_id Int32,
    active_sessions AggregateFunction(uniqCombined64, FixedString(64))
)
ENGINE = AggregatingMergeTree
PARTITION BY toYYYYMM(service_date)
ORDER BY
(
    generation,
    service_date,
    platform,
    country,
    video_type,
    content_id,
    minute_start
);

CREATE TABLE IF NOT EXISTS sonyliv.processing_batches
(
    adjustment_batch_id UUID,
    input_manifest_hash FixedString(64),
    policy_version LowCardinality(String),
    started_at DateTime64(3, 'UTC'),
    completed_at DateTime64(3, 'UTC') DEFAULT toDateTime64(0, 3, 'UTC'),
    status Enum8('started' = 1, 'published' = 2, 'validated' = 3, 'failed' = 4),
    touched_sessions UInt64,
    adjustment_rows UInt64,
    answer_hash FixedString(64) DEFAULT ''
)
ENGINE = ReplacingMergeTree(completed_at)
ORDER BY adjustment_batch_id;
