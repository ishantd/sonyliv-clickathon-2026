-- Atomic control-plane publication after step 40 succeeds. The manifest stores
-- only validated generations; failures stay in immutable processing events.

SELECT throwIf(
    count() != 1,
    'source delta snapshot is missing or duplicated'
)
FROM sonyliv.delta_snapshots
WHERE source_delta_snapshot = {source_delta_snapshot:UInt128}
  AND policy_version = {policy_version:String}
  AND pipeline_run_id = {pipeline_run_id:UUID};

SELECT throwIf(
    count() > 0,
    'generation already published for this day/entity/mask'
)
FROM sonyliv.serving_generation_manifest
WHERE service_date = {service_date:Date}
  AND entity = CAST({entity:String}, 'Enum8(\'session\' = 1, \'user\' = 2)')
  AND rollup_mask = {rollup_mask:UInt16}
  AND generation = {generation:UInt64};

SELECT throwIf(
    count() != uniqExact(
        tuple(
            minute_start,
            platform,
            country,
            video_type,
            content_id
        )
    ),
    'duplicate logical minute rows in candidate generation'
)
FROM sonyliv.concurrency_minute_versions
WHERE generation = {generation:UInt64}
  AND policy_version = {policy_version:String}
  AND pipeline_run_id = {pipeline_run_id:UUID}
  AND source_delta_snapshot = {source_delta_snapshot:UInt128}
  AND service_date = {service_date:Date}
  AND entity = CAST({entity:String}, 'Enum8(\'session\' = 1, \'user\' = 2)')
  AND rollup_mask = {rollup_mask:UInt16};

INSERT INTO sonyliv.serving_generation_manifest
WITH ordered_rows AS
(
    SELECT
        tuple(minute_start, platform, country, video_type, content_id) AS answer_key,
        concat(
            toString(minute_start), '|',
            platform, '|', country, '|', video_type, '|',
            toString(content_id), '|',
            toString(minute_peak), '|',
            toString(active_entity_ms), '|',
            toString(ending_concurrency)
        ) AS answer_row
    FROM sonyliv.concurrency_minute_versions
    WHERE generation = {generation:UInt64}
      AND policy_version = {policy_version:String}
      AND pipeline_run_id = {pipeline_run_id:UUID}
      AND source_delta_snapshot = {source_delta_snapshot:UInt128}
      AND service_date = {service_date:Date}
      AND entity = CAST({entity:String}, 'Enum8(\'session\' = 1, \'user\' = 2)')
      AND rollup_mask = {rollup_mask:UInt16}
), answer AS
(
    SELECT
        hex(
            SHA256(
                arrayStringConcat(
                    arrayMap(
                        item -> item.2,
                        arraySort(groupArray((answer_key, answer_row)))
                    ),
                    '\n'
                )
            )
        ) AS answer_hash,
        count() AS minute_rows
    FROM ordered_rows
)
SELECT
    {service_date:Date},
    CAST({entity:String}, 'Enum8(\'session\' = 1, \'user\' = 2)'),
    {rollup_mask:UInt16},
    {generation:UInt64},
    {policy_version:String},
    {pipeline_run_id:UUID},
    {source_delta_snapshot:UInt128},
    now64(3),
    answer_hash,
    minute_rows
FROM answer
SETTINGS insert_deduplication_token = {generation_manifest_dedup_token:String};

SELECT
    generation,
    answer_hash,
    minute_rows,
    source_delta_snapshot,
    published_at
FROM sonyliv.serving_generation_manifest
WHERE service_date = {service_date:Date}
  AND entity = CAST({entity:String}, 'Enum8(\'session\' = 1, \'user\' = 2)')
  AND rollup_mask = {rollup_mask:UInt16}
  AND generation = {generation:UInt64};
