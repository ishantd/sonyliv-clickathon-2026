-- =============================================================================
-- 008_concurrency_minute.sql — the served concurrency metric
--
-- Until now every read of the concurrency curve re-ran the whole state machine:
-- window functions over every event of every session in the window, on every
-- five-second poll. Measured at 1.1s for 100,000 sessions and ~1M events, which
-- is fine as an oracle and hopeless as a serving layer — the cost grows with
-- history, and the answer for a minute that closed ten minutes ago does not.
--
-- This is that answer, written once per minute and read as a GROUP BY.
-- =============================================================================

-- Per-minute concurrency, already grouped by the dimensions anyone filters on.
--
-- SummingMergeTree, and the reason it is safe is worth stating: a session's
-- dimensions are fixed for its whole life, so every session lands in exactly one
-- (content_id, video_type, platform, app_version, country) bucket. Summing
-- `sessions` across buckets therefore counts each session once and gives the true
-- total — which is what makes an arbitrary dimension filter a WHERE plus a SUM,
-- rather than something that needs the raw sessions back.
--
-- `active_ms` is carried alongside the count, not instead of it. count is
-- any-overlap concurrency (the peak-style number people mean by "concurrent
-- viewers"); active_ms/60000 is average concurrency; and the pair is what makes
-- the conservation check possible — Σ active_ms across the curve must equal Σ of
-- the interval durations it was built from.
CREATE TABLE IF NOT EXISTS {{db}}.concurrency_minute
(
    minute       DateTime('UTC'),

    content_id   Int64,
    video_type   LowCardinality(String),
    platform     LowCardinality(String),
    app_version  LowCardinality(String),
    country      LowCardinality(String),

    sessions     UInt64 COMMENT 'Distinct sessions active for >=1ms of this minute',
    active_ms    UInt64 COMMENT 'Summed active milliseconds inside this minute'
)
ENGINE = SummingMergeTree((sessions, active_ms))
PARTITION BY toYYYYMMDD(minute)
-- minute leads: every read is a time range, and this keeps it a contiguous scan.
ORDER BY (minute, content_id, platform, app_version, country, video_type)
TTL minute + INTERVAL 30 DAY
COMMENT 'Served concurrency: one row per minute per dimension combination.';


-- How far the sealer has got.
--
-- One row. ReplacingMergeTree rather than an ALTER or a mutation, because this is
-- a value that changes every thirty seconds and a mutation per update would be
-- absurd; the newest version wins and the old rows merge away.
--
-- The sealer only writes minutes that are already closed AND past the
-- late-arrival grace, so a sealed minute is final. Everything after the watermark
-- is computed on the fly by the reader, which is what keeps the newest minute
-- correct while it is still filling.
CREATE TABLE IF NOT EXISTS {{db}}.concurrency_watermark
(
    id             UInt8 DEFAULT 1 COMMENT 'Always 1: this table holds one row',
    sealed_through DateTime('UTC') COMMENT 'Exclusive upper bound of sealed minutes',
    updated_at     DateTime64(3, 'UTC'),
    version        UInt64
)
ENGINE = ReplacingMergeTree(version)
ORDER BY id
COMMENT 'Single-row watermark: concurrency_minute is complete below sealed_through.';
