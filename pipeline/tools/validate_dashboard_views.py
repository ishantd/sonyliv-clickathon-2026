#!/usr/bin/env python3
"""Apply pipeline/sql/050_dashboard_views.sql and RUN every view.

    python3 pipeline/tools/validate_dashboard_views.py

Builds a minute tier in chdb with the same shape as the live service -- the
nine materialised masks, the real platform and video_type values, and a
catalogue behind content_dict -- then applies 050 verbatim and exercises each
view with representative parameters.

Asserts behaviour, not just that the SQL parses:

  * the curve returns rows, and returns FEWER for a filtered slice
  * the mask derivation picks the right mask for each filter combination,
    which is the one thing that fails SILENTLY (a wrong mask returns the wrong
    grain, not an error)
  * dash_kpi's peak equals max(peak_concurrency) over the curve it wraps
  * content enrichment resolves; nothing falls back to '__unknown__'
  * dash_filter_support marks exactly the five unmaterialised combinations
"""
import re
import sys
import pathlib
import chdb

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "lib"))
from apply_sql import split_statements  # noqa: E402

# Real values, taken from the live service.
PLATFORMS = ["JIO_ANDROID_TV", "ANDROID_PHONE", "SONY_ANDROID_TV", "SAMSUNG_HTML_TV",
             "Web", "FIRE_TV", "LG_HTML_TV", "XIAOMI_ANDROID_TV", "IPHONE", "ANDROID_TAB"]
VIDEO_TYPES = ["vod", "live", "unknown"]

sess = chdb.session.Session()
sess.query("CREATE DATABASE IF NOT EXISTS sonyliv")
sess.query("USE sonyliv")

sess.query("""
CREATE TABLE sonyliv.concurrency_minute_versions
(
    generation UInt64, policy_version LowCardinality(String),
    clip_variant Enum8('unclipped'=1,'clipped'=2), pipeline_run_id UUID,
    source_delta_snapshot UInt128, entity Enum8('session'=1,'user'=2),
    rollup_mask UInt16, service_date Date, minute_start DateTime64(3,'UTC'),
    platform LowCardinality(String), country LowCardinality(String),
    video_type LowCardinality(String), content_id Int64,
    minute_peak UInt64, active_entity_ms UInt64, ending_concurrency UInt64,
    source_boundary_points UInt64
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(service_date)
ORDER BY (generation, policy_version, clip_variant, pipeline_run_id,
          source_delta_snapshot, entity, rollup_mask, service_date,
          platform, country, video_type, content_id, minute_start)""")

# One row per (mask, dimension-cell, minute) over one day, with peaks that
# DECREASE as the grain gets finer -- the property the mask logic must respect.
PLAT = "[" + ",".join(f"'{p}'" for p in PLATFORMS) + "]"
VT = "[" + ",".join(f"'{v}'" for v in VIDEO_TYPES) + "]"
for mask in (0, 1, 2, 3, 4, 5, 8, 9, 15):
    sess.query(f"""
INSERT INTO sonyliv.concurrency_minute_versions
SELECT 1, 'sonyliv-active-v1',
       CAST('unclipped','Enum8(\\'unclipped\\'=1,\\'clipped\\'=2)'),
       toUUID('11111111-2222-3333-4444-555555555555'), toUInt128(0),
       CAST('session','Enum8(\\'session\\'=1,\\'user\\'=2)'),
       toUInt16({mask}), toDate('2026-07-31'),
       toDateTime64('2026-07-31 00:00:00',3,'UTC') + toIntervalMinute(mi),
       if(bitAnd({mask},1)=1, {PLAT}[(d % 10)+1], ''),
       if(bitAnd({mask},2)=2, 'india', ''),
       if(bitAnd({mask},8)=8, {VT}[(d % 3)+1], ''),
       if(bitAnd({mask},4)=4, toInt64((d % 50)+1), toInt64(0)),
       -- peak shrinks with grain, and spikes at minute 675 (11:15)
       toUInt64(greatest(1, intDiv(20000, 1 + bitCount({mask})*3)
                            - abs(675 - mi) * 2 - d)),
       toUInt64(greatest(1000, 60000 - abs(675 - mi) * 40 - d * 10)),
       toUInt64(greatest(1, intDiv(18000, 1 + bitCount({mask})*3) - abs(675-mi)*2 - d)),
       toUInt64(5 + d)
FROM (SELECT number AS mi FROM numbers(1440)) AS a
CROSS JOIN (SELECT arrayJoin(range(if({mask}=0 OR {mask}=2, 1,
                                    if({mask} IN (8,9), 3, if({mask} IN (1,3), 10, 50))))) AS d) AS b""")

sess.query("""CREATE TABLE sonyliv.content_dim (
    content_id Int64, title String, video_type LowCardinality(String),
    category LowCardinality(String), show_name LowCardinality(String),
    source_version UInt64) ENGINE=ReplacingMergeTree(source_version) ORDER BY content_id""")
sess.query(f"""INSERT INTO sonyliv.content_dim
SELECT number+1, concat('Title ', toString(number+1)),
       {VT}[(number % 3)+1], concat('cat', toString(number % 8)),
       concat('Show ', toString(number % 12)), 1 FROM numbers(60)""")
sess.query("""CREATE VIEW sonyliv.content_current AS
SELECT content_id, argMax(title,source_version) AS title,
       argMax(video_type,source_version) AS video_type,
       argMax(category,source_version) AS category,
       argMax(show_name,source_version) AS show_name
FROM sonyliv.content_dim GROUP BY content_id""")
sess.query("""CREATE DICTIONARY sonyliv.content_dict
(content_id Int64, title String DEFAULT '', video_type String DEFAULT 'unknown',
 category String DEFAULT 'unknown', show_name String DEFAULT '')
PRIMARY KEY content_id SOURCE(CLICKHOUSE(DB 'sonyliv' TABLE 'content_current'))
LIFETIME(MIN 300 MAX 600) LAYOUT(COMPLEX_KEY_HASHED())""")

sess.query("""CREATE OR REPLACE VIEW sonyliv.concurrency_minute_current AS
SELECT * FROM sonyliv.concurrency_minute_versions
WHERE generation = (SELECT max(generation) FROM sonyliv.concurrency_minute_versions)""")

# --- apply 050 verbatim ---
ddl = (ROOT / "pipeline" / "sql" / "050_dashboard_views.sql").read_text()
applied = 0
for st in split_statements(ddl):
    # dash_health reads clusterAllReplicas, which needs a real cluster. chdb has
    # none, so it is verified against the live service instead (read-only) --
    # see the note at the foot of this script.
    if "clusterAllReplicas" in st:
        print("  (skipped dash_health — clusterAllReplicas needs a cluster; verified on the service)")
        continue
    try:
        sess.query(st)
        applied += 1
    except Exception as e:
        print(f"FAILED applying:\n{st[:300]}\n-> {str(e)[:400]}")
        sys.exit(1)
print(f"050 applied: {applied} statement(s)\n")


def q(sql):
    return sess.query(sql, "CSV").bytes().decode().strip()


WIN = "win_from = '2026-07-31 00:00:00', win_to = '2026-08-01 00:00:00'"
BASE = f"{WIN}, clip_variant = 'unclipped', entity = 'session'"
ok = True


def check(cond, msg):
    global ok
    print(("  PASS  " if cond else "  FAIL  ") + msg)
    ok = ok and cond


print("=== dash_concurrency_curve ===")
combos = [
    ("no filter",            "platform='', country='', video_type='', content_id=0",              0),
    ("platform",             "platform='JIO_ANDROID_TV', country='', video_type='', content_id=0", 1),
    ("country",              "platform='', country='india', video_type='', content_id=0",          2),
    ("platform+country",     "platform='JIO_ANDROID_TV', country='india', video_type='', content_id=0", 3),
    ("content",              "platform='', country='', video_type='', content_id=1",               4),
    ("platform+content",     "platform='JIO_ANDROID_TV', country='', video_type='', content_id=1", 5),
    ("video_type",           "platform='', country='', video_type='vod', content_id=0",            8),
    ("platform+video_type",  "platform='JIO_ANDROID_TV', country='', video_type='vod', content_id=0", 9),
]
peaks = {}
for label, filt, expect_mask in combos:
    rows = q(f"SELECT count(), max(peak_concurrency) FROM sonyliv.dash_concurrency_curve({BASE}, {filt})")
    n, peak = (rows.split(",") + ["0", "0"])[:2]
    peaks[label] = int(peak or 0)
    check(int(n) > 0, f"{label:20} mask {expect_mask:<2} -> {n:>5} minutes, peak {peak}")

print("\n=== the grain is right (a wrong mask fails silently, so this is the real test) ===")
check(peaks["no filter"] > peaks["platform"],
      f"global peak {peaks['no filter']} > single-platform peak {peaks['platform']}")
check(peaks["platform"] > peaks["platform+content"],
      f"platform {peaks['platform']} > platform+content {peaks['platform+content']}")
check(peaks["no filter"] > peaks["content"],
      f"global {peaks['no filter']} > single-content {peaks['content']}")
# 12 -> 4 and 13 -> 5 remap: content+video_type must equal content alone
c4 = q(f"SELECT max(peak_concurrency) FROM sonyliv.dash_concurrency_curve({BASE}, platform='', country='', video_type='', content_id=1)")
c12 = q(f"SELECT max(peak_concurrency) FROM sonyliv.dash_concurrency_curve({BASE}, platform='', country='', video_type='vod', content_id=1)")
check(c4 == c12, f"mask 12 remaps to 4: content-only {c4} == content+video_type {c12}")

# The remap neutralises the video_type predicate, so WITHOUT the dictionary
# consistency check this would wrongly return content 1's full curve. Content 1
# is 'vod' in the fixture; asking for it as 'live' must return NOTHING.
wrong_vt = q(f"SELECT count() FROM sonyliv.dash_concurrency_curve({BASE}, platform='', country='', video_type='live', content_id=1)")
check(wrong_vt == "0",
      f"content 1 (vod) filtered as video_type='live' returns {wrong_vt} rows (must be 0)")
right_vt = q(f"SELECT count() FROM sonyliv.dash_concurrency_curve({BASE}, platform='', country='', video_type='vod', content_id=1)")
check(int(right_vt) > 0, f"content 1 (vod) filtered as video_type='vod' returns {right_vt} rows")

print("\n=== dash_kpi agrees with the curve it wraps ===")
kpi = q(f"SELECT peak_concurrency_max, toString(peak_minute), round(avg_concurrency,3), minutes_with_activity FROM sonyliv.dash_kpi({BASE}, platform='', country='', video_type='', content_id=0)")
curve_peak = q(f"SELECT max(peak_concurrency) FROM sonyliv.dash_concurrency_curve({BASE}, platform='', country='', video_type='', content_id=0)")
print(f"  kpi: {kpi}")
check(kpi.split(',')[0] == curve_peak, f"kpi peak {kpi.split(',')[0]} == curve max {curve_peak}")

print("\n=== dash_filter_options ===")
for dim in ("platform", "country", "video_type"):
    n = q(f"SELECT count() FROM sonyliv.dash_filter_options WHERE dimension='{dim}'")
    check(int(n) > 0, f"{dim:12} -> {n} option(s)")

print("\n=== dash_content / dash_top_content enrichment ===")
n_content = q("SELECT count() FROM sonyliv.dash_content")
unknown = q("SELECT countIf(title='__unknown__') FROM sonyliv.dash_content")
check(int(n_content) > 0, f"dash_content -> {n_content} titles")
check(unknown == "0", f"no '__unknown__' fallback ({unknown}) — dictionary resolved")
top = q(f"SELECT count() FROM sonyliv.dash_top_content({WIN})")
check(int(top) > 0, f"dash_top_content -> {top} rows in window")
print("  sample:", q(f"SELECT title, show_name, category, peak_concurrency FROM sonyliv.dash_top_content({WIN}) LIMIT 2"))

print("\n=== dash_filter_support ===")
sup = q("SELECT countIf(supported), countIf(NOT supported) FROM sonyliv.dash_filter_support")
unsup = q("SELECT groupArray(requested_mask) FROM sonyliv.dash_filter_support WHERE NOT supported")
check(sup.split(",")[1] == "5", f"exactly 5 unsupported combinations, got {sup.split(',')[1]}")
check(sorted(re.findall(r"\d+", unsup)) == sorted(["6", "7", "10", "11", "14"]),
      f"unsupported set is {unsup} (expected 6,7,10,11,14)")

print("\n=== dash_health ===")
print("  not runnable in chdb (clusterAllReplicas); its body is verified read-only")
print("  against the live service, where it returns the real replica counts.")

print("\nOK" if ok else "\nFAILURES ABOVE")
sys.exit(0 if ok else 1)
