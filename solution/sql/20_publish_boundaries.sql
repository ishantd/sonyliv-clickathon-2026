-- Convert normalized interval-map changes into signed point corrections.
--
-- Initial backfill sequence:
--   1. Run 10_reference_intervals.sql.
--   2. Run the two INSERTs below to build session and distinct-user maps.
--   3. Run the boundary INSERT at the bottom.
--
-- Incremental sequence:
--   1. Drain append-only dirty operation IDs not present in applied_dirty_operations.
--   2. Recompute only those sessions using the state query from step 10.
--   3. Before publishing, persist previous and replacement interval maps in
--      entity_interval_changes with change_sign -1 and +1 respectively.
--   4. When a session changes, recompute every affected canonical user across
--      all that user's current sessions before producing the user's -1/+1 maps.
--   5. Insert the boundary block once with a deterministic
--      insert_deduplication_token, then mark processing_batches as published.

SELECT throwIf(
    count() > 0,
    'adjustment_batch_id is already published; never reuse a published batch ID'
)
FROM sonyliv.published_adjustment_batches
WHERE adjustment_batch_id = {adjustment_batch_id:UUID};

-- ---- Initial session maps --------------------------------------------------
INSERT INTO sonyliv.entity_interval_changes
(
    adjustment_batch_id,
    state_revision,
    entity,
    source_entity_id,
    rollup_mask,
    platform,
    country,
    video_type,
    content_id,
    change_sign,
    intervals
)
WITH
    [toUInt16(0), 1, 2, 4, 8, 3, 5, 9, 12, 15] AS masks
SELECT
    {adjustment_batch_id:UUID},
    {state_revision:UInt64},
    CAST('session', 'Enum8(\'session\' = 1, \'user\' = 2)') AS entity,
    video_session_id AS source_entity_id,
    mask AS rollup_mask,
    if(bitAnd(mask, 1) != 0, platform, '__all__') AS masked_platform,
    if(bitAnd(mask, 2) != 0, country, '__all__') AS masked_country,
    if(bitAnd(mask, 8) != 0, video_type, '__all__') AS masked_video_type,
    if(bitAnd(mask, 4) != 0, content_id, toInt32(0)) AS masked_content_id,
    toInt8(1) AS change_sign,
    arraySort(groupArray((start_time, end_time))) AS intervals
FROM sonyliv.active_intervals_reference
ARRAY JOIN masks AS mask
WHERE oracle_run_id = {oracle_run_id:UUID}
  AND policy_version = {policy_version:String}
  AND {initialize_from_oracle:UInt8} = 1
GROUP BY
    video_session_id,
    mask,
    masked_platform,
    masked_country,
    masked_video_type,
    masked_content_id
SETTINGS insert_deduplication_token = {session_changes_dedup_token:String};

-- ---- Initial distinct-user maps -------------------------------------------
-- Union overlapping session intervals per (user, requested dimension mask)
-- before emitting boundaries. Counting raw session boundaries as users is wrong:
-- 775 canonical users have multiple sessions and 61 overlap in the supplied data.
INSERT INTO sonyliv.entity_interval_changes
(
    adjustment_batch_id,
    state_revision,
    entity,
    source_entity_id,
    rollup_mask,
    platform,
    country,
    video_type,
    content_id,
    change_sign,
    intervals
)
WITH
    [toUInt16(0), 1, 2, 4, 8, 3, 5, 9, 12, 15] AS masks,

    masked_session_intervals AS
    (
        SELECT
            canonical_user_id,
            mask AS rollup_mask,
            if(bitAnd(mask, 1) != 0, platform, '__all__') AS masked_platform,
            if(bitAnd(mask, 2) != 0, country, '__all__') AS masked_country,
            if(bitAnd(mask, 8) != 0, video_type, '__all__') AS masked_video_type,
            if(bitAnd(mask, 4) != 0, content_id, toInt32(0)) AS masked_content_id,
            start_time,
            end_time
        FROM sonyliv.active_intervals_reference
        ARRAY JOIN masks AS mask
        WHERE oracle_run_id = {oracle_run_id:UUID}
          AND policy_version = {policy_version:String}
          AND {initialize_from_oracle:UInt8} = 1
    ),

    marked AS
    (
        SELECT
            *,
            start_time > max(end_time) OVER
            (
                PARTITION BY
                    canonical_user_id,
                    rollup_mask,
                    masked_platform,
                    masked_country,
                    masked_video_type,
                    masked_content_id
                ORDER BY start_time, end_time
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            ) AS starts_new_island
        FROM masked_session_intervals
    ),

    numbered AS
    (
        SELECT
            *,
            sum(starts_new_island) OVER
            (
                PARTITION BY
                    canonical_user_id,
                    rollup_mask,
                    masked_platform,
                    masked_country,
                    masked_video_type,
                    masked_content_id
                ORDER BY start_time, end_time
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS island_number
        FROM marked
    ),

    merged AS
    (
        SELECT
            canonical_user_id,
            rollup_mask,
            masked_platform,
            masked_country,
            masked_video_type,
            masked_content_id,
            island_number,
            min(start_time) AS start_time,
            max(end_time) AS end_time
        FROM numbered
        GROUP BY
            canonical_user_id,
            rollup_mask,
            masked_platform,
            masked_country,
            masked_video_type,
            masked_content_id,
            island_number
    )

SELECT
    {adjustment_batch_id:UUID},
    {state_revision:UInt64},
    CAST('user', 'Enum8(\'session\' = 1, \'user\' = 2)') AS entity,
    canonical_user_id AS source_entity_id,
    rollup_mask,
    masked_platform,
    masked_country,
    masked_video_type,
    masked_content_id,
    toInt8(1) AS change_sign,
    arraySort(groupArray((start_time, end_time))) AS intervals
FROM merged
GROUP BY
    canonical_user_id,
    rollup_mask,
    masked_platform,
    masked_country,
    masked_video_type,
    masked_content_id
SETTINGS insert_deduplication_token = {user_changes_dedup_token:String};

-- ---- Interval-map differences -> exact boundary adjustments --------------
INSERT INTO sonyliv.boundary_adjustments
(
    adjustment_operation_id,
    adjustment_batch_id,
    state_revision,
    source_entity_id,
    entity,
    rollup_mask,
    service_date,
    boundary_time,
    platform,
    country,
    video_type,
    content_id,
    delta
)
WITH
    deduplicated_change_rows AS
    (
        SELECT DISTINCT
            adjustment_batch_id,
            state_revision,
            source_entity_id,
            entity,
            rollup_mask,
            platform,
            country,
            video_type,
            content_id,
            change_sign,
            intervals
        FROM sonyliv.entity_interval_changes
        WHERE adjustment_batch_id = {adjustment_batch_id:UUID}
    ),

    changed_intervals AS
    (
        SELECT
            *,
            arrayJoin(intervals) AS interval
        FROM deduplicated_change_rows
        WHERE interval.2 > interval.1
    ),

    day_slices AS
    (
        SELECT
            *,
            addDays(toDate(interval.1), day_offset) AS service_date,
            greatest(interval.1, toDateTime64(service_date, 3, 'UTC')) AS slice_start,
            least(interval.2, toDateTime64(addDays(service_date, 1), 3, 'UTC')) AS slice_end
        FROM changed_intervals
        ARRAY JOIN range(
            toUInt32(
                dateDiff(
                    'day',
                    toDate(interval.1),
                    toDate(interval.2 - toIntervalMillisecond(1))
                ) + 1
            )
        ) AS day_offset
    ),

    endpoints AS
    (
        SELECT
            *,
            arrayJoin([
                (slice_start, toInt8(1)),
                (slice_end, toInt8(-1))
            ]) AS endpoint
        FROM day_slices
        WHERE slice_end > slice_start
    )

SELECT
    reinterpretAsUInt128(
        sipHash128(
            adjustment_batch_id,
            state_revision,
            source_entity_id,
            entity,
            rollup_mask,
            service_date,
            endpoint.1,
            platform,
            country,
            video_type,
            content_id,
            change_sign * endpoint.2
        )
    ) AS adjustment_operation_id,
    adjustment_batch_id,
    state_revision,
    source_entity_id,
    entity,
    rollup_mask,
    service_date,
    endpoint.1 AS boundary_time,
    platform,
    country,
    video_type,
    content_id,
    toInt8(change_sign * endpoint.2) AS delta
FROM endpoints
SETTINGS insert_deduplication_token = {boundary_adjustments_dedup_token:String};

-- Stable-token insert deduplication is the crash-retry mechanism on replicated
-- ClickHouse/ClickHouse Cloud. The logical operation-ID gate detects any failure
-- of that contract before a serving generation is published.
SELECT throwIf(
    count() != uniqExact(adjustment_operation_id),
    'duplicate boundary operation IDs detected; do not publish a serving generation'
)
FROM sonyliv.boundary_adjustments
WHERE adjustment_batch_id = {adjustment_batch_id:UUID};

INSERT INTO sonyliv.published_adjustment_batches
SELECT
    {adjustment_batch_id:UUID},
    {policy_version:String},
    {pipeline_run_id:UUID},
    {source_snapshot_hash:String},
    hex(
        SHA256(
            arrayStringConcat(
                arraySort(groupArray(toString(adjustment_operation_id))),
                '\n'
            )
        )
    ) AS adjustment_block_hash,
    count() AS adjustment_rows,
    now64(3) AS published_at
FROM sonyliv.boundary_adjustments
WHERE adjustment_batch_id = {adjustment_batch_id:UUID}
SETTINGS insert_deduplication_token = {adjustment_ledger_dedup_token:String};
