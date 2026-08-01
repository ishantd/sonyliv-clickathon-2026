-- =============================================================================
-- 001_content.sql — content dimension + enrichment dictionary
--
-- Database: default (per project decision; every object is `sl_`-prefixed so it
-- coexists safely with anything else living in `default`).
-- All timestamps are UTC and millisecond-precise.
-- =============================================================================

-- Content dimension.
--
-- ReplacingMergeTree(source_version) rather than plain MergeTree: the content
-- catalogue is a slowly-changing dimension and a re-load of the same CSV must
-- converge to one row per content_id instead of doubling the table.
-- [official: insert-mutation-avoid-update — replacement semantics with a
--  version column, never ALTER UPDATE]
--
-- content_id is Int64, not Int32:
--   * the supplied catalogue contains 18446744072721897294, which is
--     -987654322 stored as an unsigned 64-bit value, so the domain is signed;
--   * the largest positive id observed is 2,078,177,474 = 96.8% of Int32 max.
-- Int32 would fit today's extract but leaves ~3.2% headroom before an overflow
-- silently corrupts the join key on the unseen day. The extra 4 bytes on a
-- 33K-row dimension is free, and on the event table it compresses away.
-- [derived: schema-types-minimize-bitwidth says smallest type that FITS —
--  the range that must fit is the source domain, not one sample of it]
CREATE TABLE IF NOT EXISTS {{db}}.sl_content_dim
(
    content_id      Int64,
    title           String,
    video_type      LowCardinality(String) DEFAULT 'unknown',
    category        LowCardinality(String) DEFAULT 'unknown',

    source_version  UInt64 COMMENT 'Monotonic load version; highest wins',
    loaded_at       DateTime64(3, 'UTC') DEFAULT now64(3)
)
ENGINE = ReplacingMergeTree(source_version)
ORDER BY content_id
SETTINGS
    -- Without this, insert_deduplication_token is ignored on a non-replicated
    -- MergeTree and re-running the loader appends a second full copy of the
    -- catalogue. ReplacingMergeTree would eventually collapse it, but "wait for
    -- a merge" is not a substitute for not writing the rows.
    -- Replicated / SharedMergeTree (ClickHouse Cloud) dedupes independently and
    -- ignores this setting.
    non_replicated_deduplication_window = 100
COMMENT 'Content catalogue. 33,464 rows in the supplied extract, content_id unique.';

-- Deduplicated read view. Replacement by background merge is eventual, so the
-- dictionary source must not assume physical replacement has happened yet.
-- [official: insert-optimize-avoid-final — resolve with argMax, not FINAL]
CREATE OR REPLACE VIEW {{db}}.sl_content_current AS
SELECT
    content_id,
    argMax(title,      source_version) AS title,
    argMax(video_type, source_version) AS video_type,
    argMax(category,   source_version) AS category
FROM {{db}}.sl_content_dim
GROUP BY content_id;

-- Enrichment dictionary.
--
-- A dictionary, not a JOIN: the dimension is 33K rows with 100% join coverage
-- against the event stream, and enrichment happens on the ingest/compaction hot
-- path where a right-side hash build per query would be pure waste.
-- [official: query-join-consider-alternatives — prefer a dictionary over a JOIN
--  for small, stable dimensions]
--
-- LIFETIME(MIN 300 MAX 600): the catalogue can change between loads. Note the
-- correctness caveat — a dictionary refresh does NOT retract already-enriched
-- rows. Anything denormalized from this dictionary must be re-derived by
-- explicitly re-dirtying the affected sessions.
--
-- The CLICKHOUSE source authenticates even when it points at a table on the
-- same server, so credentials are substituted here from .env at apply time
-- rather than committed. They do end up visible in SHOW CREATE DICTIONARY and
-- system.dictionaries; if that matters in your environment, replace the USER /
-- PASSWORD clauses with a named collection:
--
--   CREATE NAMED COLLECTION sl_ch AS user = '...', password = '...';
--   SOURCE(CLICKHOUSE(NAME sl_ch DB '{{db}}' TABLE 'sl_content_current'))
CREATE DICTIONARY IF NOT EXISTS {{db}}.sl_content_dict
(
    content_id  Int64,
    title       String            DEFAULT '',
    video_type  String            DEFAULT 'unknown',
    category    String            DEFAULT 'unknown'
)
PRIMARY KEY content_id
SOURCE(CLICKHOUSE(
    DB       '{{db}}'
    TABLE    'sl_content_current'
    USER     '{{ch_user}}'
    PASSWORD '{{ch_password}}'
))
LIFETIME(MIN 300 MAX 600)
LAYOUT(HASHED());
