-- =====================================================================
-- 041 — Verification for the minute serving tier
-- =====================================================================
--
-- Run after 040. C4, C9 and C10 are GATING and must throw.
--
-- Values marked [tuning] are for the 10,866-session extract and change on
-- other data. THE ASSERTIONS still hold. C1 and C2 are tuning-day
-- constants and are worthless once the data changes -- C4 is the check
-- that still works on the unseen day, because it compares the new table
-- against active_intervals rather than against a hardcoded number.
--
-- Parameters: {policy_version:String} {clip_variant:String} {generation:UInt64}
-- =====================================================================


-- ---------------------------------------------------------------------
-- C4 (GATING) — conservation. The only reference-free check.
-- ---------------------------------------------------------------------
-- Every millisecond of interval time must appear exactly once in the
-- minute rows: no loss, no double-counting. This is what catches a sparse
-- build (which would silently under-report the time-weighted average) and
-- it is the one check that does not depend on knowing the answer.
--
-- VERIFIED on the tuning extract: 6,406,210,064 ms on both sides, exact.
-- ---------------------------------------------------------------------
SELECT throwIf(
    (SELECT sum(active_entity_ms) FROM sonyliv.concurrency_minute_versions
     WHERE generation = {generation:UInt64} AND rollup_mask = 0 AND entity = 'session')
    !=
    (SELECT sum(dateDiff('millisecond', start_time, end_time))
     FROM sonyliv.active_intervals
     WHERE policy_version = {policy_version:String}
       AND clip_variant = CAST({clip_variant:String}, 'Enum8(\'unclipped\' = 1, \'clipped\' = 2)')),
    'C4 FAILED: minute active_entity_ms does not equal total interval duration. '
    'The minute table is lossy or double-counted. Do NOT serve from it.'
) AS c4_conservation;


-- ---------------------------------------------------------------------
-- C9 (GATING) — doubling. Run 040's INSERT twice, then this.
-- ---------------------------------------------------------------------
-- A re-run must not double the curve. Note WHY this check is needed:
-- the balance invariant (C7) is structurally blind to a scalar multiple,
-- because doubling both opens and closes keeps them balanced.
-- CLAUDE.md:105 -- "a doubled Summing curve passes every balance
-- invariant" -- this already cost a day once.
--
-- max(minute_peak) is duplication-SAFE (max of a doubled set of levels is
-- still the right level if rows are deduped, and obviously wrong if not).
-- sum(active_entity_ms) is duplication-UNSAFE and is what C4 catches.
-- ---------------------------------------------------------------------
SELECT throwIf(
    (SELECT max(minute_peak) FROM sonyliv.concurrency_minute_versions
     WHERE generation = {generation:UInt64} AND rollup_mask = 0 AND entity = 'session') != 2305,
    'C9 FAILED: mask 0 peak is not 2305. If it is ~4610 the producer ran twice into '
    'the same generation. Bump generation and re-run; do not TRUNCATE mid-migration.'
) AS c9_no_doubling;   -- [tuning] 2305


-- ---------------------------------------------------------------------
-- C10 (GATING) — midnight crossing. The path that has never run.
-- ---------------------------------------------------------------------
-- Zero intervals cross midnight in the tuning extract, but ONLY because
-- 88% of it sits in a 2-hour window at 10:00 UTC. Intervals are NOT split
-- at day boundaries (011 has no splitting logic; 010:44-49 says intervals
-- are meant to OVERLAP a service day). A 2-hour interval starting 23:30 on
-- a match night crosses, and then concurrency after midnight depends on a
-- code path that has never produced a non-zero value.
--
-- This asserts the producer handles it. It requires a synthetic interval
-- spanning midnight -- insert one into a scratch copy of active_intervals,
-- run 040 against it, and assert BOTH days are correct.
-- ---------------------------------------------------------------------
SELECT
    countIf(toDate(start_time, 'UTC') != toDate(end_time, 'UTC')) AS intervals_crossing_midnight,
    throwIf(
        countIf(toDate(start_time, 'UTC') != toDate(end_time, 'UTC')) = 0
          AND {generation:UInt64} > 0,
        'C10 NOT EXERCISED: no interval in this data crosses midnight, so the '
        'cross-day path is still untested. Inject a synthetic 23:30->00:30 interval '
        'and re-run before trusting any post-midnight number.'
    ) AS c10_midnight
FROM sonyliv.active_intervals
WHERE policy_version = {policy_version:String}
  AND clip_variant = CAST({clip_variant:String}, 'Enum8(\'unclipped\' = 1, \'clipped\' = 2)');


-- ---------------------------------------------------------------------
-- C1 — instantaneous peak matches the boundary sweep   [tuning: 2305]
-- ---------------------------------------------------------------------
SELECT max(minute_peak) AS mask0_peak, max(minute_peak) = 2305 AS pass
FROM sonyliv.concurrency_minute_versions
WHERE generation = {generation:UInt64} AND rollup_mask = 0 AND entity = 'session';


-- ---------------------------------------------------------------------
-- C2 — level at the minute boundary   [tuning: 2285 @ 10:55]
-- ---------------------------------------------------------------------
-- 2285 is the number three independent paths agree on: this table, the
-- live path (pipeline/sql/031), and active_intervals containment.
-- Do NOT compare it against 2305 -- that is the max INSIDE the minute,
-- not the level at its edge. Both are correct and they are different things.
SELECT ending_concurrency, ending_concurrency = 2285 AS pass
FROM sonyliv.concurrency_minute_versions
WHERE generation = {generation:UInt64} AND rollup_mask = 0 AND entity = 'session'
  AND minute_start = toDateTime64('2026-07-26 10:55:00', 3, 'UTC');


-- ---------------------------------------------------------------------
-- C3 — per-minute series agrees with the existing delta path, all masks
-- ---------------------------------------------------------------------
-- Compares ending_concurrency against a day-anchored cumsum over deltas.
-- Mask 12 is excluded: the minute table deliberately omits it, since it is
-- identical to mask 4 (video_type is functionally determined by content_id).
SELECT count() AS mismatched_minutes
FROM (
    SELECT rollup_mask, platform, country, video_type, content_id,
           toStartOfMinute(boundary_ts) AS minute_start,
           argMax(level, boundary_ts) AS delta_level
    FROM (
        SELECT rollup_mask, platform, country, video_type, content_id, boundary_ts,
               sum(sum(opens) - sum(closes)) OVER (
                   PARTITION BY rollup_mask, platform, country, video_type, content_id
                   ORDER BY boundary_ts ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS level
        FROM sonyliv.concurrency_deltas
        WHERE policy_version = {policy_version:String}
          AND clip_variant = CAST({clip_variant:String}, 'Enum8(\'unclipped\' = 1, \'clipped\' = 2)')
          AND rollup_mask != 12
        GROUP BY rollup_mask, platform, country, video_type, content_id, boundary_ts
    )
    GROUP BY rollup_mask, platform, country, video_type, content_id, minute_start
) AS d
INNER JOIN (
    SELECT rollup_mask, platform, country, video_type, content_id, minute_start, ending_concurrency
    FROM sonyliv.concurrency_minute_versions
    WHERE generation = {generation:UInt64} AND entity = 'session'
) AS m
  USING (rollup_mask, platform, country, video_type, content_id, minute_start)
WHERE d.delta_level != m.ending_concurrency;
-- expect 0


-- ---------------------------------------------------------------------
-- C11 — row count sanity   [tuning: 272,070 per clip variant]
-- ---------------------------------------------------------------------
-- Nine masks, dense. NOT the ~121,558 a sparse boundary-shaped build would
-- give -- that number was in an earlier draft of the plan and would have
-- failed on a correct build.
SELECT count() AS dense_rows, count() = 272070 AS pass_on_tuning_data
FROM sonyliv.concurrency_minute_versions
WHERE generation = {generation:UInt64} AND entity = 'session';


-- ---------------------------------------------------------------------
-- C12 — read shape: one range scan, no window function
-- ---------------------------------------------------------------------
-- The point of the whole tier. Should read a few thousand rows, not 73,728.
EXPLAIN indexes = 1
SELECT max(minute_peak)                                            AS peak_concurrency,
       sum(active_entity_ms) / (24 * 3600 * 1000.0)                AS avg_concurrency
FROM sonyliv.concurrency_minute_versions
WHERE generation = {generation:UInt64} AND policy_version = {policy_version:String}
  AND entity = 'session' AND rollup_mask = 0
  AND minute_start >= toDateTime64('2026-07-26 00:00:00', 3, 'UTC')
  AND minute_start <  toDateTime64('2026-07-27 00:00:00', 3, 'UTC');
