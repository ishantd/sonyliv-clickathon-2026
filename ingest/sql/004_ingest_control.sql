-- =============================================================================
-- 004_ingest_control.sql — pipeline evidence and rejected rows
--
-- "No pipeline evidence, no credit." These two tables are how an answer is
-- traced back to the run that produced it.
-- =============================================================================

-- One row per INSERT batch actually sent. Written by the producer AFTER the
-- data insert acknowledges, so a row here means the data is durable.
--
-- Rows are small and arrive one at a time — exactly the shape client-side
-- batching cannot fix. The producer writes this table with async_insert=1 and
-- wait_for_async_insert=1 so ClickHouse buffers server-side and still confirms
-- durability before the call returns.
-- [official: insert-async-small-batches]
CREATE TABLE IF NOT EXISTS {{db}}.ingest_batches
(
    ingest_batch_id   UUID,
    run_id            UUID     COMMENT 'Groups every batch of one pipeline invocation',
    source            LowCardinality(String) COMMENT 'e.g. csv:ch-hackathon-raw-data.csv | generator',
    source_fingerprint String  DEFAULT '' COMMENT 'SHA-256 of the source file, or the generator seed',
    batch_ordinal     UInt32   COMMENT 'Deterministic: row_number / batch_size',
    dedup_token       String   COMMENT 'insert_deduplication_token used for this batch',

    row_count         UInt32,
    rejected_count    UInt32   DEFAULT 0,
    bytes_estimate    UInt64   DEFAULT 0,
    first_event_time  DateTime64(3, 'UTC'),
    last_event_time   DateTime64(3, 'UTC'),

    started_at        DateTime64(3, 'UTC'),
    completed_at      DateTime64(3, 'UTC'),
    duration_ms       UInt32,
    attempt           UInt8    DEFAULT 1,
    status            Enum8('ok' = 1, 'failed' = 2) DEFAULT 'ok',
    error             String   DEFAULT ''
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(started_at)
ORDER BY (source, run_id, batch_ordinal)
COMMENT 'Ingest audit log: one row per acknowledged INSERT batch.';


-- Rows the producer refused to land in events_raw.
--
-- A malformed row is quarantined, never silently dropped: on the unseen day a
-- non-zero, unexplained reject count is the difference between "our answer is
-- wrong" and "our answer excludes 12 rows, here they are, here is why".
CREATE TABLE IF NOT EXISTS {{db}}.ingest_rejects
(
    run_id       UUID,
    source       LowCardinality(String),
    source_line  UInt64   COMMENT '1-based line number in the source file, 0 for generated rows',
    reason       LowCardinality(String) COMMENT 'bad_session_id | bad_user_id | bad_content_id | bad_timestamp | bad_column_count | missing_column',
    detail       String,
    raw_row      String   COMMENT 'The offending row, verbatim',
    rejected_at  DateTime64(3, 'UTC') DEFAULT now64(3)
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(rejected_at)
ORDER BY (source, reason, run_id, source_line)
TTL toDateTime(rejected_at) + INTERVAL 30 DAY
COMMENT 'Quarantine for rows that failed validation. TTL 30d — this is a debugging aid, not a system of record.';
