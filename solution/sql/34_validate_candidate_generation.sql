-- Full per-minute parity gate for one candidate generation. This independently
-- recomputes exact minute rows from the sealed signed-point snapshot and rejects
-- any missing, duplicate, shifted, or numerically different cache row.

WITH
    {service_date:Date} AS selected_date,
    toDateTime64(selected_date, 3, 'UTC') AS day_start,
    toDateTime64(addDays(selected_date, 1), 3, 'UTC') AS day_end,
    toUnixTimestamp64Milli(day_start) AS day_start_ms,
    toUInt64(60000) AS minute_ms,
    (
        SELECT any(cutoff)
        FROM sonyliv.delta_snapshots
        WHERE source_delta_snapshot = {source_delta_snapshot:UInt128}
          AND policy_version = {policy_version:String}
          AND pipeline_run_id = {pipeline_run_id:UUID}
    ) AS snapshot_cutoff,

    snapshot_guard AS
    (
        SELECT throwIf(
            count() != 1,
            'candidate source_delta_snapshot is missing or duplicated'
        ) AS ok
        FROM sonyliv.delta_snapshots
        WHERE source_delta_snapshot = {source_delta_snapshot:UInt128}
          AND policy_version = {policy_version:String}
          AND pipeline_run_id = {pipeline_run_id:UUID}
    ),

    points AS
    (
        SELECT
            platform,
            country,
            video_type,
            content_id,
            boundary_time,
            sum(delta) AS point_delta
        FROM sonyliv.boundary_adjustments AS a
        INNER JOIN
        (
            SELECT adjustment_batch_id
            FROM sonyliv.published_adjustment_batches
            WHERE policy_version = {policy_version:String}
              AND pipeline_run_id = {pipeline_run_id:UUID}
              AND published_at <= snapshot_cutoff
            GROUP BY adjustment_batch_id
        ) AS b USING (adjustment_batch_id)
        WHERE a.service_date = selected_date
          AND a.entity = CAST({entity:String}, 'Enum8(\'session\' = 1, \'user\' = 2)')
          AND a.rollup_mask = {rollup_mask:UInt16}
          AND a.boundary_time < day_end
        GROUP BY platform, country, video_type, content_id, boundary_time
        HAVING point_delta != 0
    ),

    curve AS
    (
        SELECT
            *,
            sum(point_delta) OVER point_window AS concurrency,
            leadInFrame(boundary_time, 1, day_end) OVER full_window AS next_boundary_time
        FROM points
        WINDOW
            point_window AS
            (
                PARTITION BY platform, country, video_type, content_id
                ORDER BY boundary_time
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ),
            full_window AS
            (
                PARTITION BY platform, country, video_type, content_id
                ORDER BY boundary_time
                ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
            )
    ),

    minute_overlaps AS
    (
        SELECT
            platform,
            country,
            video_type,
            content_id,
            minute_number,
            if(
                concurrency < 0,
                toInt64(throwIf(1, 'negative concurrency invariant breach')),
                toInt64(concurrency)
            ) AS concurrency,
            least(
                toUnixTimestamp64Milli(next_boundary_time),
                day_start_ms + toInt64((minute_number + 1) * minute_ms)
            ) - greatest(
                toUnixTimestamp64Milli(boundary_time),
                day_start_ms + toInt64(minute_number * minute_ms)
            ) AS overlap_ms,
            least(
                toUnixTimestamp64Milli(next_boundary_time),
                day_start_ms + toInt64((minute_number + 1) * minute_ms)
            ) AS overlap_end_ms
        FROM curve
        ARRAY JOIN range(
            toUInt64(intDiv(toUnixTimestamp64Milli(boundary_time) - day_start_ms, toInt64(minute_ms))),
            toUInt64(intDiv(toUnixTimestamp64Milli(next_boundary_time) - day_start_ms - 1, toInt64(minute_ms)) + 1)
        ) AS minute_number
        WHERE next_boundary_time > boundary_time
          AND boundary_time < day_end
    ),

    expected AS
    (
        SELECT
            fromUnixTimestamp64Milli(
                day_start_ms + toInt64(minute_number * minute_ms),
                'UTC'
            ) AS minute_start,
            platform,
            country,
            video_type,
            content_id,
            toUInt64(max(concurrency)) AS minute_peak,
            toUInt64(sum(toInt128(concurrency) * toInt128(overlap_ms))) AS active_entity_ms,
            toUInt64(argMax(concurrency, overlap_end_ms)) AS ending_concurrency
        FROM minute_overlaps
        WHERE overlap_ms > 0
        GROUP BY platform, country, video_type, content_id, minute_number
        HAVING minute_peak > 0 OR active_entity_ms > 0 OR ending_concurrency > 0
    ),

    actual AS
    (
        SELECT
            minute_start,
            platform,
            country,
            video_type,
            content_id,
            any(minute_peak) AS minute_peak,
            any(active_entity_ms) AS active_entity_ms,
            any(ending_concurrency) AS ending_concurrency,
            count() AS physical_rows
        FROM sonyliv.concurrency_minute_versions
        WHERE generation = {generation:UInt64}
          AND policy_version = {policy_version:String}
          AND pipeline_run_id = {pipeline_run_id:UUID}
          AND source_delta_snapshot = {source_delta_snapshot:UInt128}
          AND service_date = selected_date
          AND entity = CAST({entity:String}, 'Enum8(\'session\' = 1, \'user\' = 2)')
          AND rollup_mask = {rollup_mask:UInt16}
        GROUP BY minute_start, platform, country, video_type, content_id
    ),

    differences AS
    (
        SELECT
            coalesce(e.minute_start, a.minute_start) AS minute_start,
            coalesce(e.platform, a.platform) AS platform,
            coalesce(e.country, a.country) AS country,
            coalesce(e.video_type, a.video_type) AS video_type,
            coalesce(e.content_id, a.content_id) AS content_id
        FROM expected AS e
        FULL OUTER JOIN actual AS a
            ON e.minute_start = a.minute_start
           AND e.platform = a.platform
           AND e.country = a.country
           AND e.video_type = a.video_type
           AND e.content_id = a.content_id
        WHERE a.physical_rows != 1
           OR e.minute_peak != a.minute_peak
           OR e.active_entity_ms != a.active_entity_ms
           OR e.ending_concurrency != a.ending_concurrency
    )

SELECT throwIf(
    count() > 0,
    'candidate minute generation differs from exact sealed-point recomputation'
) AS candidate_generation_parity
FROM differences
CROSS JOIN snapshot_guard
SETTINGS
    join_use_nulls = 0,
    max_execution_time = 60,
    max_rows_to_read = 100000000,
    max_bytes_to_read = 20000000000;
