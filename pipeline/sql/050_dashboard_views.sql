-- =====================================================================
-- 050 — Dashboard read surface
-- =====================================================================
--
-- The views a product UI calls. Nothing here computes concurrency; it all
-- reads concurrency_minute_current, which 040 built. This file exists so a
-- dashboard, a text-to-SQL layer, or a judge can ask the submission's two
-- mandatory questions without knowing the rollup-mask scheme.
--
-- What the SonyLIV track requires (SONYLIV_SUBMISSION_GUIDELINES.md):
--
--   1. A CONCURRENCY CURVE -- concurrent viewers/sessions over time, with
--      visible peaks and ramps, over at least one full window of interest.
--   2. DATASET FILTERS -- matching the dimensions the dataset actually
--      provides, applying to the curve AND to every other view.
--
-- dash_concurrency_curve answers (1). Every view here takes the same filter
-- parameters, which answers (2).
--
-- ---------------------------------------------------------------------
-- WHICH DATASET COLUMN BACKS WHICH FILTER
-- ---------------------------------------------------------------------
-- The guidelines ask for this mapping to be documented. It is also in
-- docs/TABLE-CONTRACT.md; this is the copy that sits next to the code.
--
--   filter        dataset column              carried how
--   ------------  --------------------------  --------------------------------
--   platform      raw CSV `platform`          rollup bit 1, materialised
--   country       raw CSV `country`           rollup bit 2, materialised
--   content       raw CSV `content_id`        rollup bit 4, materialised
--   video_type    catalogue `video_type`      rollup bit 8, materialised
--   title         catalogue `title`           via content_dict on content_id
--   category      catalogue `category`        via content_dict on content_id
--   show_name     catalogue `show_name`       via content_dict on content_id
--
-- NOT FILTERABLE on the curve, and this is a real limitation rather than an
-- oversight: app_version, audio_language, subtitle_language, player_version
-- and video_resolution exist in events_clean but were never given a rollup
-- bit. The mask is 4 bits wide by policy.yaml, and adding one means rebuilding
-- concurrency_deltas -- a SummingMergeTree, where a rebuild is the doubling
-- hazard this project has already been bitten by. They are queryable at the
-- event layer, not on the curve. Say so rather than shipping a filter that
-- silently returns the unfiltered number.
--
-- ---------------------------------------------------------------------
-- PARAMETERISED VIEWS, and how to call them
-- ---------------------------------------------------------------------
--   SELECT * FROM sonyliv.dash_concurrency_curve(
--       win_from = '2026-07-31 00:00:00',
--       win_to   = '2026-08-01 00:00:00',
--       platform = '', country = '', video_type = '', content_id = 0);
--
-- Pass '' (or 0 for content_id) for a dimension you are NOT filtering on.
-- That is not a convention -- it is how the rollup works. A row at mask 1
-- carries the real platform and a literal '' in every other dimension, so
-- "unfiltered" and "the empty string" are the same predicate by construction.
--
-- ---------------------------------------------------------------------
-- WHY THE MASK IS COMPUTED, NOT PASSED
-- ---------------------------------------------------------------------
-- Asking a dashboard to pass rollup_mask = 5 is asking it to know that
-- 5 = platform + content. Get it wrong and the query returns the WRONG GRAIN
-- silently -- filtering mask 15 by platform alone gives the busiest single
-- (platform, country, video_type, content) cell, not the platform's peak.
-- Measured on this data: platform JIO_ANDROID_TV peaks at 5,928 at mask 1, and
-- mask 15 filtered by that platform alone returns 1,982 -- a 66.6% under-report,
-- with no error and no empty result to notice.
--
-- So the mask is DERIVED from which filters are non-empty:
--     bit 1 platform | bit 2 country | bit 4 content_id | bit 8 video_type
--
-- Two masks are then remapped, using the functional dependency 040 proves
-- (content_id determines video_type; 0 catalogue rows carry two):
--     12 (content+video_type)          -> 4
--     13 (platform+content+video_type) -> 5
--
-- Five combinations remain unmaterialised: 6, 7, 10, 11, 14 -- every one of
-- them is country combined with content or video_type. dash_filter_support
-- lists them. They are NOT served from mask 15, because a peak cannot be
-- re-derived from a finer mask: two dimension values peak at different
-- minutes, so max() over the finer grain is not the coarser grain's peak.
-- Returning a wrong number is worse than returning none.
-- =====================================================================


-- ---------------------------------------------------------------------
-- dash_filter_support -- what the UI is allowed to offer
-- ---------------------------------------------------------------------
-- A dashboard should grey out a filter combination it cannot answer rather
-- than fire a query that returns nothing. This view is the source of that
-- decision, so the rule lives in one place instead of in dashboard JSON.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW sonyliv.dash_filter_support AS
SELECT
    m                                                        AS requested_mask,
    bitAnd(m, 1) = 1                                         AS filters_platform,
    bitAnd(m, 2) = 2                                         AS filters_country,
    bitAnd(m, 4) = 4                                         AS filters_content,
    bitAnd(m, 8) = 8                                         AS filters_video_type,
    multiIf(m = 12, toUInt16(4), m = 13, toUInt16(5), toUInt16(m)) AS served_by_mask,
    multiIf(m = 12, toUInt16(4), m = 13, toUInt16(5), toUInt16(m))
        IN (0, 1, 2, 3, 4, 5, 8, 9, 15)                      AS supported,
    multiIf(
        m IN (12, 13), 'derived: content_id functionally determines video_type',
        m IN (0, 1, 2, 3, 4, 5, 8, 9, 15), 'materialised',
        'NOT materialised -- country combined with content or video_type')  AS note
FROM (SELECT arrayJoin(range(16)) AS m);


-- ---------------------------------------------------------------------
-- dash_concurrency_curve -- REQUIREMENT 1, the mandatory curve
-- ---------------------------------------------------------------------
-- One row per minute in the window. Plot peak_concurrency against
-- minute_start and that is the deliverable.
--
-- THREE MEASURES, and they are different things. Conflating them is the
-- easiest way to publish a wrong headline:
--
--   peak_concurrency   the max INSTANTANEOUS level inside the minute. This is
--                      the one to plot and the one to quote as "peak".
--   ending_concurrency the level at the minute's closing edge. Always <= peak.
--                      Measured on the tuning extract: 2,305 vs 2,285.
--   avg_concurrency    time-weighted mean over the minute, from active_ms.
--                      This is the only one that is ADDITIVE across minutes.
--
-- Read shape: one range scan over a prefix-pruned key, no window function, no
-- FINAL, no join. Measured on the service against the real 1,295,876-row minute
-- tier, one day unfiltered: 44,924 rows read, 1.13 MiB, 50 ms -- a 28.8x prune.
-- The filter-option views read the COARSE masks instead of mask 15: 125,398 rows
-- for all three dropdowns, against 465,465 rows in mask 15 alone.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW sonyliv.dash_concurrency_curve AS
WITH
    -- Which dimensions the caller actually filtered on.
    (if({platform:String}   != '', 1, 0)
   + if({country:String}    != '', 2, 0)
   + if({content_id:Int64}  != 0,  4, 0)
   + if({video_type:String} != '', 8, 0))                       AS requested_mask,

    -- 12 and 13 are not materialised, but content_id functionally determines
    -- video_type (040: 0 catalogue rows carry two), so they are answerable from
    -- 4 and 5.
    multiIf(requested_mask = 12, 4,
            requested_mask = 13, 5,
            requested_mask)                                     AS served_mask,

    -- REMAPPING THE MASK IS NOT ENOUGH, and getting this wrong returns rows
    -- that should not exist. Mask 4 and 5 rows carry video_type = '', so the
    -- video_type predicate has to be neutralised when serving 12 or 13 from
    -- them -- otherwise the query matches nothing and the filter looks broken.
    served_mask != requested_mask                               AS remapped,
    if(remapped, '', {video_type:String})                       AS video_type_filter,

    -- But neutralising it would also make "content X AND video_type Y" return
    -- X's full curve even when X is not a Y. The dictionary settles that: the
    -- content's own video_type must equal the requested one, or the answer is
    -- legitimately empty. This is the check that keeps the remap honest.
    (NOT remapped)
      OR dictGetOrDefault(sonyliv.content_dict, 'video_type',
                          tuple({content_id:Int64}), '__unknown__')
         = {video_type:String}                                  AS remap_is_consistent
SELECT
    minute_start,
    minute_peak                                    AS peak_concurrency,
    ending_concurrency,
    active_entity_ms                               AS active_ms,
    active_entity_ms / 60000.0                     AS avg_concurrency,
    source_boundary_points                         AS boundary_points
FROM sonyliv.concurrency_minute_current
WHERE remap_is_consistent
  AND entity = CAST({entity:String}, 'Enum8(\'session\' = 1, \'user\' = 2)')
  AND clip_variant = CAST({clip_variant:String}, 'Enum8(\'unclipped\' = 1, \'clipped\' = 2)')
  AND rollup_mask = served_mask
  AND platform   = {platform:String}
  AND country    = {country:String}
  AND video_type = video_type_filter
  AND content_id = {content_id:Int64}
  AND minute_start >= parseDateTimeBestEffort({win_from:String}, 'UTC')
  AND minute_start <  parseDateTimeBestEffort({win_to:String},   'UTC')
ORDER BY minute_start;


-- dash_kpi -- the headline numbers for the same window and filters
-- ---------------------------------------------------------------------
-- avg_concurrency divides by the WINDOW, not by the number of minutes that
-- have rows. A quiet minute with no interval produces no row, so dividing by
-- count() would silently inflate the average by skipping the zeros.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW sonyliv.dash_kpi AS
SELECT
    -- NOT `max(peak_concurrency) AS peak_concurrency`: the alias then shadows
    -- the column and argMax below resolves to it, giving ILLEGAL_AGGREGATION
    -- ("aggregate function found inside another aggregate function").
    max(peak_concurrency)                                          AS peak_concurrency_max,
    argMax(minute_start, peak_concurrency)                         AS peak_minute,
    sum(active_ms) / greatest(dateDiff('millisecond',
        parseDateTimeBestEffort({win_from:String}, 'UTC'),
        parseDateTimeBestEffort({win_to:String},   'UTC')), 1)     AS avg_concurrency,
    sum(active_ms) / 3600000.0                                     AS total_viewing_hours,
    count()                                                        AS minutes_with_activity,
    min(minute_start)                                              AS first_active_minute,
    max(minute_start)                                              AS last_active_minute
FROM sonyliv.dash_concurrency_curve(
        win_from     = {win_from:String},
        win_to       = {win_to:String},
        platform     = {platform:String},
        country      = {country:String},
        video_type   = {video_type:String},
        content_id   = {content_id:Int64},
        clip_variant = {clip_variant:String},
        entity       = {entity:String});


-- ---------------------------------------------------------------------
-- dash_filter_options -- populate the dropdowns
-- ---------------------------------------------------------------------
-- Reads the COARSE single-dimension masks (1, 2, 8), not mask 15, so the cost
-- is thousands of rows rather than hundreds of thousands. Measured on this
-- data: mask 1 holds 8,053 rows and mask 15 holds 465,465, for the same
-- answer on platform.
--
-- Ordered by peak so the busiest values surface first in the UI.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW sonyliv.dash_filter_options AS
SELECT 'platform' AS dimension, platform AS value, max(minute_peak) AS peak_concurrency,
       sum(active_entity_ms) / 3600000.0 AS viewing_hours
FROM sonyliv.concurrency_minute_current
WHERE rollup_mask = 1 AND entity = 'session' AND platform != ''
GROUP BY platform
UNION ALL
SELECT 'country', country, max(minute_peak), sum(active_entity_ms) / 3600000.0
FROM sonyliv.concurrency_minute_current
WHERE rollup_mask = 2 AND entity = 'session' AND country != ''
GROUP BY country
UNION ALL
SELECT 'video_type', video_type, max(minute_peak), sum(active_entity_ms) / 3600000.0
FROM sonyliv.concurrency_minute_current
WHERE rollup_mask = 8 AND entity = 'session' AND video_type != ''
GROUP BY video_type;


-- ---------------------------------------------------------------------
-- dash_content -- the content filter, enriched, searchable, ranked
-- ---------------------------------------------------------------------
-- Mask 4 is one row per (content, minute), so this aggregates to one row per
-- title. content_dict is a DICTIONARY lookup, not a join: 33K rows, in memory,
-- and the enrichment happens per output row rather than per minute row.
--
-- '__unknown__' is the fallback, NOT 'unknown'. 'unknown' is a REAL catalogue
-- value, so using it would make a cold-replica dictionary miss look like data.
-- With '__unknown__', `countIf(title = '__unknown__') > 0` is a valid alarm --
-- and it is worth wiring, because a dictionary that loaded zero rows still
-- reports status = 'LOADED'.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW sonyliv.dash_content AS
SELECT
    content_id,
    dictGetOrDefault(sonyliv.content_dict, 'title',      tuple(content_id), '__unknown__') AS title,
    dictGetOrDefault(sonyliv.content_dict, 'show_name',  tuple(content_id), '__unknown__') AS show_name,
    dictGetOrDefault(sonyliv.content_dict, 'category',   tuple(content_id), '__unknown__') AS category,
    dictGetOrDefault(sonyliv.content_dict, 'video_type', tuple(content_id), '__unknown__') AS video_type,
    max(minute_peak)                       AS peak_concurrency,
    argMax(minute_start, minute_peak)      AS peak_minute,
    sum(active_entity_ms) / 3600000.0      AS viewing_hours,
    min(minute_start)                      AS first_seen,
    max(minute_start)                      AS last_seen
FROM sonyliv.concurrency_minute_current
WHERE rollup_mask = 4 AND entity = 'session' AND content_id != 0
GROUP BY content_id;


-- ---------------------------------------------------------------------
-- dash_top_content -- "what was big in this window", windowed
-- ---------------------------------------------------------------------
-- Same shape as dash_content but bounded to a window, for the leaderboard
-- tile next to the curve. Enrichment is applied AFTER the GROUP BY, so the
-- dictionary is consulted once per title rather than once per minute row.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW sonyliv.dash_top_content AS
SELECT
    content_id,
    dictGetOrDefault(sonyliv.content_dict, 'title',      tuple(content_id), '__unknown__') AS title,
    dictGetOrDefault(sonyliv.content_dict, 'show_name',  tuple(content_id), '__unknown__') AS show_name,
    dictGetOrDefault(sonyliv.content_dict, 'category',   tuple(content_id), '__unknown__') AS category,
    peak_concurrency,
    peak_minute,
    viewing_hours
FROM (
    SELECT
        content_id,
        max(minute_peak)                  AS peak_concurrency,
        argMax(minute_start, minute_peak) AS peak_minute,
        sum(active_entity_ms) / 3600000.0 AS viewing_hours
    FROM sonyliv.concurrency_minute_current
    WHERE rollup_mask = 4 AND entity = 'session' AND content_id != 0
      AND minute_start >= parseDateTimeBestEffort({win_from:String}, 'UTC')
      AND minute_start <  parseDateTimeBestEffort({win_to:String},   'UTC')
    GROUP BY content_id
)
ORDER BY peak_concurrency DESC;


-- ---------------------------------------------------------------------
-- dash_health -- is the surface trustworthy right now?
-- ---------------------------------------------------------------------
-- A dashboard that renders a confident chart over a cold dictionary or an
-- empty generation is the failure mode this project exists to avoid. This is
-- one cheap row the UI can poll and show as a banner.
--
-- dictionary_cold_replicas is the important one: an empty dictionary reports
-- status = 'LOADED' with no exception, so element_count is the only signal.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW sonyliv.dash_health AS
SELECT
    (SELECT max(generation) FROM sonyliv.concurrency_minute_versions)      AS serving_generation,
    (SELECT count() FROM sonyliv.concurrency_minute_current)               AS serving_rows,
    -- NOT currentDatabase(). Inside a VIEW that resolves to the CALLER's session
    -- database, not the view's -- so a dashboard connected as `default` querying
    -- sonyliv.dash_health would silently get 0 replicas and a green banner.
    -- Measured exactly that.
    --
    -- splitByChar on a 'sonyliv.<name>' literal instead, because apply_sql.py's
    -- --rewrite-db rewrites the `sonyliv.` PREFIX -- so this string tracks the
    -- target database automatically and still cannot be fooled by the caller's
    -- session. sonyliv_prod also owns a content_dict, so matching on name alone
    -- would be ambiguous rather than merely imprecise.
    (SELECT countIf(element_count = 0)
       FROM clusterAllReplicas(default, system.dictionaries)
      WHERE database = splitByChar('.', 'sonyliv.content_dict')[1]
        AND name = 'content_dict')                                         AS dictionary_cold_replicas,
    (SELECT count() FROM clusterAllReplicas(default, system.dictionaries)
      WHERE database = splitByChar('.', 'sonyliv.content_dict')[1]
        AND name = 'content_dict')                                         AS dictionary_replicas,
    (SELECT arraySort(groupUniqArray(rollup_mask))
       FROM sonyliv.concurrency_minute_current)                            AS masks_available,
    (SELECT groupUniqArray(toString(clip_variant))
       FROM sonyliv.concurrency_minute_current)                            AS clip_variants_loaded,
    (SELECT min(minute_start) FROM sonyliv.concurrency_minute_current)     AS data_from,
    (SELECT max(minute_start) FROM sonyliv.concurrency_minute_current)     AS data_to;
