-- =============================================================================
-- 030_rollup_minute.sql — session_intervals -> serving_concurrency_minute_staging
--
-- The corrected layer. Rebuilds ONE whole UTC day into the staging table; the
-- driver then swaps it in with ALTER TABLE ... REPLACE PARTITION, which is what
-- lets a rebuild remove rows a recompute no longer produces. See the header of
-- ingest/sql/007_serving_concurrency.sql for why replacement alone cannot.
--
-- The core — clip, fan out over masks, span the buckets, zero-delta at each
-- bucket edge, prefix sum — is the same shape as 020_rollup_live.sql and the
-- reasoning is documented there rather than repeated here. Three things differ:
--
--   * 60-second buckets instead of 10;
--   * seven dimension masks instead of two, so every single-dimension exact peak
--     is available and mask 63 carries the full grain that arbitrary dashboard
--     filters compose against;
--   * session counts, which the live layer has no use for.
--
-- concurrency/sql/090_validate_serving.sql cross-checks the two layers against
-- each other on an overlapping window, so the duplicated core cannot drift
-- silently.
--
-- Parameters (textual {{db}}; the rest bound server-side):
--   {service_date:String}   the UTC day to rebuild, 'YYYY-MM-DD'
--   {lookback_days:UInt16}  how far back to scan session_intervals partitions
--
-- No {version:UInt64}: the target is a plain MergeTree replaced by partition
-- swap, so there is nothing to version against.
-- =============================================================================

INSERT INTO {{db}}.serving_concurrency_minute_staging
    (minute_start, dim_mask, content_id, platform, country, app_version, video_type, category,
     minute_peak, ending_concurrency, active_ms, sessions_active, sessions_started, sessions_ended)
WITH
    toDateTime64(concat({service_date:String}, ' 00:00:00.000'), 3, 'UTC') AS win_start,
    win_start + toIntervalDay(1)                                          AS win_end,
    60000 AS bucket_ms,

    bounds AS
    (
        SELECT
            session_key,
            content_id,
            platform,
            country,
            app_version,
            video_type,
            -- category is not on session_intervals; it is catalogue metadata and
            -- is resolved here from the same dictionary the recompute used for
            -- video_type, with the same 'unknown' default so a catalogue miss and
            -- a blank value share a bucket instead of splitting the GROUP BY.
            dictGetOrDefault({{db}}.content_dict, 'category', tuple(content_id), 'unknown') AS category,
            toInt64(toUnixTimestamp64Milli(greatest(ivl.1, win_start))) AS s_ms,
            toInt64(toUnixTimestamp64Milli(least(ivl.2, win_end)))      AS e_ms,
            -- Whether the interval genuinely opened/closed inside this day, as
            -- opposed to being clipped at midnight. Without this an interval
            -- spanning midnight would be counted as a start on both days.
            ivl.1 >= win_start AS opened_here,
            ivl.2 <  win_end   AS closed_here
        FROM
        (
            SELECT session_key, content_id, platform, country, app_version, video_type,
                   arrayJoin(intervals) AS ivl
            FROM {{db}}.session_intervals FINAL
            WHERE session_start_date >= toDate(win_start) - {lookback_days:UInt16}
              AND session_start_date <= toDate(win_end)
        )
        WHERE ivl.1 < win_end AND ivl.2 > win_start
    ),

    -- One row per (interval, mask), with every dimension the mask does not select
    -- blanked so it collapses in the GROUP BY. Bits: platform=1, country=2,
    -- content_id=4, video_type=8, app_version=16, category=32.
    masked AS
    (
        SELECT
            m AS dim_mask,
            session_key,
            if(bitAnd(m, 4)  > 0, content_id,  toInt64(0)) AS g_content,
            if(bitAnd(m, 1)  > 0, platform,    '')         AS g_platform,
            if(bitAnd(m, 2)  > 0, country,     '')         AS g_country,
            if(bitAnd(m, 16) > 0, app_version, '')         AS g_app_version,
            if(bitAnd(m, 8)  > 0, video_type,  '')         AS g_video_type,
            if(bitAnd(m, 32) > 0, category,    '')         AS g_category,
            s_ms,
            e_ms,
            opened_here,
            closed_here
        FROM bounds
        ARRAY JOIN [toUInt16(0), toUInt16(1), toUInt16(4), toUInt16(8),
                    toUInt16(16), toUInt16(32), toUInt16(63)] AS m
        WHERE e_ms > s_ms
    ),

    spans AS
    (
        SELECT
            dim_mask, g_content, g_platform, g_country, g_app_version, g_video_type, g_category,
            session_key, s_ms, e_ms,
            toInt64(arrayJoin(range(
                toUInt64(intDiv(s_ms, bucket_ms) * bucket_ms),
                toUInt64(intDiv(e_ms - 1, bucket_ms) * bucket_ms + bucket_ms),
                toUInt64(bucket_ms)
            ))) AS bkt_ms
        FROM masked
    ),

    events AS
    (
        SELECT dim_mask, g_content, g_platform, g_country, g_app_version, g_video_type, g_category,
               s_ms AS t_ms, toInt64(1) AS d
        FROM masked
        UNION ALL
        SELECT dim_mask, g_content, g_platform, g_country, g_app_version, g_video_type, g_category,
               e_ms AS t_ms, toInt64(-1) AS d
        FROM masked
        UNION ALL
        SELECT DISTINCT dim_mask, g_content, g_platform, g_country, g_app_version, g_video_type, g_category,
               bkt_ms AS t_ms, toInt64(0) AS d
        FROM spans
    ),

    net AS
    (
        SELECT dim_mask, g_content, g_platform, g_country, g_app_version, g_video_type, g_category,
               t_ms, sum(d) AS d
        FROM events
        GROUP BY dim_mask, g_content, g_platform, g_country, g_app_version, g_video_type, g_category, t_ms
    ),

    running AS
    (
        SELECT
            dim_mask, g_content, g_platform, g_country, g_app_version, g_video_type, g_category,
            t_ms,
            sum(d) OVER (
                PARTITION BY dim_mask, g_content, g_platform, g_country, g_app_version, g_video_type, g_category
                ORDER BY t_ms
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS c
        FROM net
    ),

    agg_peak AS
    (
        SELECT
            dim_mask, g_content, g_platform, g_country, g_app_version, g_video_type, g_category,
            intDiv(t_ms, bucket_ms) * bucket_ms    AS bkt_ms,
            toUInt32(greatest(max(c), 0))          AS minute_peak,
            toUInt32(greatest(argMax(c, t_ms), 0)) AS ending_concurrency
        FROM running
        GROUP BY dim_mask, g_content, g_platform, g_country, g_app_version, g_video_type, g_category, bkt_ms
    ),

    agg_time AS
    (
        SELECT
            dim_mask, g_content, g_platform, g_country, g_app_version, g_video_type, g_category, bkt_ms,
            sum(least(e_ms, bkt_ms + bucket_ms) - greatest(s_ms, bkt_ms)) AS active_ms,
            uniqExact(session_key)                                       AS sessions_active
        FROM spans
        GROUP BY dim_mask, g_content, g_platform, g_country, g_app_version, g_video_type, g_category, bkt_ms
    ),

    agg_edges AS
    (
        SELECT
            dim_mask, g_content, g_platform, g_country, g_app_version, g_video_type, g_category,
            intDiv(s_ms, bucket_ms) * bucket_ms AS bkt_ms,
            countIf(opened_here)                AS sessions_started
        FROM masked
        GROUP BY dim_mask, g_content, g_platform, g_country, g_app_version, g_video_type, g_category, bkt_ms
    ),

    agg_closes AS
    (
        SELECT
            dim_mask, g_content, g_platform, g_country, g_app_version, g_video_type, g_category,
            -- e_ms - 1 so an interval closing exactly on a minute edge is counted
            -- in the minute it was actually present in, matching the half-open
            -- convention used for spans.
            intDiv(e_ms - 1, bucket_ms) * bucket_ms AS bkt_ms,
            countIf(closed_here)                    AS sessions_ended
        FROM masked
        GROUP BY dim_mask, g_content, g_platform, g_country, g_app_version, g_video_type, g_category, bkt_ms
    )

SELECT
    toDateTime(intDiv(p.bkt_ms, 1000), 'UTC') AS minute_start,
    p.dim_mask,
    p.g_content     AS content_id,
    p.g_platform    AS platform,
    p.g_country     AS country,
    p.g_app_version AS app_version,
    p.g_video_type  AS video_type,
    p.g_category    AS category,
    p.minute_peak,
    p.ending_concurrency,
    toUInt64(t.active_ms)        AS active_ms,
    toUInt32(t.sessions_active)  AS sessions_active,
    toUInt32(s.sessions_started) AS sessions_started,
    toUInt32(c.sessions_ended)   AS sessions_ended
FROM agg_peak AS p
LEFT JOIN agg_time   AS t USING (dim_mask, g_content, g_platform, g_country, g_app_version, g_video_type, g_category, bkt_ms)
LEFT JOIN agg_edges  AS s USING (dim_mask, g_content, g_platform, g_country, g_app_version, g_video_type, g_category, bkt_ms)
LEFT JOIN agg_closes AS c USING (dim_mask, g_content, g_platform, g_country, g_app_version, g_video_type, g_category, bkt_ms)
-- Guard against the day's trailing edge: an interval closing exactly at midnight
-- puts its -1 in the first minute of the next day, which is outside this
-- partition and must not be written.
WHERE p.bkt_ms >= toInt64(toUnixTimestamp64Milli(win_start))
  AND p.bkt_ms <  toInt64(toUnixTimestamp64Milli(win_end))
  AND (p.minute_peak > 0 OR t.active_ms > 0)
SETTINGS join_use_nulls = 0;
