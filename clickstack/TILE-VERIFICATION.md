# ClickStack tile verification

Database `sonyliv_prod`, granularity 60s, generated 2026-08-01 22:52:04Z.

## hot-hour — `2026-07-26 10:00:00` .. `2026-07-26 11:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent now | number | OK | 1 | `0` |
| 01 Peak (ungrouped) | number | OK | 1 | `0` |
| 01 Viewer-hours | number | OK | 1 | `0` |
| 01 Layer lag (s) | number | OK | 1 | `5` |
| 01 Concurrent viewers | line | OK | 0 | `—` |
| 01 Peak vs average (ungrouped) | line | OK | 0 | `—` |
| 01 Top titles | line | OK | 0 | `—` |
| 01 Title leaderboard | table | OK | 0 | `—` |
| 02 Average concurrency | number | OK | 1 | `855.603469` |
| 02 Viewer-hours | number | OK | 1 | `855.6` |
| 02 Intervals started | number | OK | 1 | `16173` |
| 02 By platform | line | OK | 407 | `2026-07-26 10:00:00ANDROID_TAB1` |
| 02 By content type | line | OK | 140 | `2026-07-26 10:00:00vod48.04` |
| 02 Viewer-hours by category | pie | OK | 12 | `cdbgg128.71` |
| 02 Titles | table | OK | 25 | `wekek kedlivecdbgg119.7225532.8` |
| 02 Peak (ungrouped) | number | OK | 1 | `2305` |
| 02 Layer lag (s) | number | OK | 1 | `427` |
| 02 Peak minute | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Peak by grouping | table | OK | 60 | `totalall23052026-07-26 10:55:00855.660` |
| 03 Ingest lag p50/p95/p99 (s) | line | OK | 0 | `—` |
| 03 Rows/s by producer | line | OK | 0 | `—` |
| 03 Read volume by query | table | OK | 0 | `—` |
| 03 Rollup duration (ms) | line | OK | 0 | `—` |
| 03 Sessions dirtied/min | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 22:51:05.9906358911296sonyliv-active-v` |
| 03 Dedup collapse | table | OK | 1 | `1522072151410479680.52350` |
| 03 Storage | table | OK | 11 | `events_clean1.51 million18.75 MiB17.4152` |
| 04 By platform | stacked_bar | OK | 407 | `2026-07-26 10:00:00ANDROID_TAB1` |
| 04 Platform totals | table | OK | 10 | `ANDROID_PHONE552.4764.579979` |
| 04 By content type | stacked_bar | OK | 140 | `2026-07-26 10:00:00vod48.04` |
| 04 Content type totals | table | OK | 3 | `vod700.1381.8312800` |
| 04 By app version | stacked_bar | OK | 1648 | `2026-07-26 10:00:006.34.834.12` |
| 04 App version totals | table | OK | 30 | `6.34.8444.2151.927895` |
| 04 By category | stacked_bar | OK | 610 | `2026-07-26 10:00:00dhddd1` |
| 04 Category totals | table | OK | 30 | `cdbgg128.7115.042700` |
| 04 By title (top 10) | stacked_bar | OK | 521 | `2026-07-26 10:00:00dijoj jeh1` |
| 04 Title totals | table | OK | 30 | `wekek kedlivecdbgg119.7213.992553` |
| 05 Peak (ungrouped) | number | OK | 1 | `2305` |
| 05 Average (ungrouped) | number | OK | 1 | `855.603469` |
| 05 Viewer-hours (ungrouped) | number | OK | 1 | `855.6` |
| 05 Rows read | number | OK | 1 | `60` |
| 05 Peak by dimension value | table | OK | 50 | `countryindia23052026-07-26 10:55:00855.603469855.6` |
| 05 Peak per minute | line | OK | 118972 | `2026-07-26 10:00:00total: all50` |
| 05 Peak per hour | line | OK | 9308 | `2026-07-26 10:00:00content: zigog gaj1` |
| 05 Per day | table | OK | 9308 | `2026-07-26countryindia23052026-07-26 10:55:0035.6501855.60` |
| 05 Query evidence | table | OK | 0 | `—` |
| 06 Worst retention — location | number | OK | 1 | `0.974403` |
| 06 Worst retention — platform | number | OK | 1 | `0.898311` |
| 06 Worst retention — content type | number | OK | 1 | `0.864345` |
| 06 Worst retention — category | number | OK | 1 | `0.776935` |
| 06 Detector lag (s) | number | OK | 1 | `433` |
| 06 Slices breaching | number | OK | 1 | `0` |
| 06 Slices watched | number | OK | 1 | `1` |
| 06 Settled through | table | OK | 1 | `2026-08-01 22:45:00.000434117837` |
| 06 Retention by location (alert below 0.70) | line | OK | 60 | `2026-07-26 10:00:00india1` |
| 06 Observed vs baseline by location | line | OK | 120 | `2026-07-26 10:00:00india observed48.042383` |
| 06 Breaching slices, any dimension | table | OK | 0 | `—` |
| 06 Retention by platform | line | OK | 155 | `2026-07-26 10:00:00ANDROID_PHONE1` |
| 06 Retention by content type | line | OK | 97 | `2026-07-26 10:00:00vod1` |
| 06 Retention by category | line | OK | 200 | `2026-07-26 10:39:00cdbgg1` |

60 passed, 0 failed.

## hot-day — `2026-07-26 00:00:00` .. `2026-07-27 00:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent now | number | OK | 1 | `0` |
| 01 Peak (ungrouped) | number | OK | 1 | `0` |
| 01 Viewer-hours | number | OK | 1 | `0` |
| 01 Layer lag (s) | number | OK | 1 | `6` |
| 01 Concurrent viewers | line | OK | 0 | `—` |
| 01 Peak vs average (ungrouped) | line | OK | 0 | `—` |
| 01 Top titles | line | OK | 0 | `—` |
| 01 Title leaderboard | table | OK | 0 | `—` |
| 02 Average concurrency | number | OK | 1 | `147.290321` |
| 02 Viewer-hours | number | OK | 1 | `1671.75` |
| 02 Intervals started | number | OK | 1 | `30706` |
| 02 By platform | line | OK | 1668 | `2026-07-26 00:10:00ANDROID_PHONE0.44` |
| 02 By content type | line | OK | 988 | `2026-07-26 00:10:00vod0.44` |
| 02 Viewer-hours by category | pie | OK | 12 | `cdbgg184.24` |
| 02 Titles | table | OK | 25 | `wekek kedlivecdbgg170.1346042.2` |
| 02 Peak (ungrouped) | number | OK | 1 | `2305` |
| 02 Layer lag (s) | number | OK | 1 | `438` |
| 02 Peak minute | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Peak by grouping | table | OK | 60 | `countryindia23052026-07-26 10:55:001671.75637` |
| 03 Ingest lag p50/p95/p99 (s) | line | OK | 0 | `—` |
| 03 Rows/s by producer | line | OK | 0 | `—` |
| 03 Read volume by query | table | OK | 0 | `—` |
| 03 Rollup duration (ms) | line | OK | 0 | `—` |
| 03 Sessions dirtied/min | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 22:51:15.8686458932288sonyliv-active-v` |
| 03 Dedup collapse | table | OK | 1 | `1522672151469679760.52380` |
| 03 Storage | table | OK | 11 | `events_clean1.51 million18.74 MiB17.4112` |
| 04 By platform | stacked_bar | OK | 1668 | `2026-07-26 00:10:00ANDROID_PHONE0.44` |
| 04 Platform totals | table | OK | 10 | `ANDROID_PHONE1097.9465.6818991` |
| 04 By content type | stacked_bar | OK | 988 | `2026-07-26 00:10:00vod0.44` |
| 04 Content type totals | table | OK | 3 | `vod1412.4984.4924097` |
| 04 By app version | stacked_bar | OK | 5097 | `2026-07-26 00:10:006.28.140.44` |
| 04 App version totals | table | OK | 30 | `6.34.8867.1851.8714907` |
| 04 By category | stacked_bar | OK | 2707 | `2026-07-26 00:10:00other0.44` |
| 04 Category totals | table | OK | 30 | `cdbgg184.2411.024824` |
| 04 By title (top 10) | stacked_bar | OK | 1945 | `2026-07-26 00:10:00other0.44` |
| 04 Title totals | table | OK | 30 | `wekek kedlivecdbgg170.1310.184604` |
| 05 Peak (ungrouped) | number | OK | 1 | `2305` |
| 05 Average (ungrouped) | number | OK | 1 | `147.290321` |
| 05 Viewer-hours (ungrouped) | number | OK | 1 | `1671.75` |
| 05 Rows read | number | OK | 1 | `637` |
| 05 Peak by dimension value | table | OK | 50 | `countryindia23052026-07-26 10:55:00147.2903211671.75` |
| 05 Peak per minute | line | OK | 255642 | `2026-07-26 00:10:00total: all1` |
| 05 Peak per hour | line | OK | 19646 | `2026-07-26 00:00:00all dimensions: ANDROID_PHONE  india  v` |
| 05 Per day | table | OK | 12357 | `2026-07-26totalall23052026-07-26 10:55:0069.656157.464637` |
| 05 Query evidence | table | OK | 0 | `—` |
| 06 Worst retention — location | number | OK | 1 | `0` |
| 06 Worst retention — platform | number | OK | 1 | `0` |
| 06 Worst retention — content type | number | OK | 1 | `0` |
| 06 Worst retention — category | number | OK | 1 | `0` |
| 06 Detector lag (s) | number | OK | 1 | `446` |
| 06 Slices breaching | number | OK | 1 | `29` |
| 06 Slices watched | number | OK | 1 | `1` |
| 06 Settled through | table | OK | 1 | `2026-08-01 22:45:00.000447117837` |
| 06 Retention by location (alert below 0.70) | line | OK | 1440 | `2026-07-26 00:00:00india1` |
| 06 Observed vs baseline by location | line | OK | 2880 | `2026-07-26 00:00:00india observed0` |
| 06 Breaching slices, any dimension | table | OK | 29 | `categorycdbgg202026-07-26 11:01:002026-07-26 11:35:000100-` |
| 06 Retention by platform | line | OK | 455 | `2026-07-26 08:37:00ANDROID_PHONE1` |
| 06 Retention by content type | line | OK | 269 | `2026-07-26 08:37:00vod1` |
| 06 Retention by category | line | OK | 752 | `2026-07-26 10:39:00cdbgg1` |

60 passed, 0 failed.

## gap-no-data — `2026-07-16 00:00:00` .. `2026-07-18 00:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent now | number | OK | 1 | `0` |
| 01 Peak (ungrouped) | number | OK | 1 | `0` |
| 01 Viewer-hours | number | OK | 1 | `0` |
| 01 Layer lag (s) | number | OK | 1 | `9` |
| 01 Concurrent viewers | line | OK | 0 | `—` |
| 01 Peak vs average (ungrouped) | line | OK | 0 | `—` |
| 01 Top titles | line | OK | 0 | `—` |
| 01 Title leaderboard | table | OK | 0 | `—` |
| 02 Average concurrency | number | OK | 1 | `0` |
| 02 Viewer-hours | number | OK | 1 | `0` |
| 02 Intervals started | number | OK | 1 | `0` |
| 02 By platform | line | OK | 0 | `—` |
| 02 By content type | line | OK | 0 | `—` |
| 02 Viewer-hours by category | pie | OK | 0 | `—` |
| 02 Titles | table | OK | 0 | `—` |
| 02 Peak (ungrouped) | number | OK | 1 | `0` |
| 02 Layer lag (s) | number | OK | 1 | `451` |
| 02 Peak minute | table | OK | 0 | `—` |
| 02 Peak by grouping | table | OK | 0 | `—` |
| 03 Ingest lag p50/p95/p99 (s) | line | OK | 0 | `—` |
| 03 Rows/s by producer | line | OK | 0 | `—` |
| 03 Read volume by query | table | OK | 0 | `—` |
| 03 Rollup duration (ms) | line | OK | 0 | `—` |
| 03 Sessions dirtied/min | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 22:51:25.9776758953319sonyliv-active-v` |
| 03 Dedup collapse | table | OK | 1 | `1523449151541580340.52740` |
| 03 Storage | table | OK | 11 | `events_clean1.52 million18.77 MiB17.4142` |
| 04 By platform | stacked_bar | OK | 0 | `—` |
| 04 Platform totals | table | OK | 0 | `—` |
| 04 By content type | stacked_bar | OK | 0 | `—` |
| 04 Content type totals | table | OK | 0 | `—` |
| 04 By app version | stacked_bar | OK | 0 | `—` |
| 04 App version totals | table | OK | 0 | `—` |
| 04 By category | stacked_bar | OK | 0 | `—` |
| 04 Category totals | table | OK | 0 | `—` |
| 04 By title (top 10) | stacked_bar | OK | 0 | `—` |
| 04 Title totals | table | OK | 0 | `—` |
| 05 Peak (ungrouped) | number | OK | 1 | `0` |
| 05 Average (ungrouped) | number | OK | 1 | `0` |
| 05 Viewer-hours (ungrouped) | number | OK | 1 | `0` |
| 05 Rows read | number | OK | 1 | `0` |
| 05 Peak by dimension value | table | OK | 0 | `—` |
| 05 Peak per minute | line | OK | 0 | `—` |
| 05 Peak per hour | line | OK | 0 | `—` |
| 05 Per day | table | OK | 0 | `—` |
| 05 Query evidence | table | OK | 0 | `—` |
| 06 Worst retention — location | number | OK | 1 | `1` |
| 06 Worst retention — platform | number | OK | 1 | `1` |
| 06 Worst retention — content type | number | OK | 1 | `1` |
| 06 Worst retention — category | number | OK | 1 | `1` |
| 06 Detector lag (s) | number | OK | 1 | `396` |
| 06 Slices breaching | number | OK | 1 | `0` |
| 06 Slices watched | number | OK | 1 | `0` |
| 06 Settled through | table | OK | 1 | `2026-08-01 22:46:00.000396119150` |
| 06 Retention by location (alert below 0.70) | line | OK | 0 | `—` |
| 06 Observed vs baseline by location | line | OK | 0 | `—` |
| 06 Breaching slices, any dimension | table | OK | 0 | `—` |
| 06 Retention by platform | line | OK | 0 | `—` |
| 06 Retention by content type | line | OK | 0 | `—` |
| 06 Retention by category | line | OK | 0 | `—` |

60 passed, 0 failed.

## full-extract — `2026-07-14 00:00:00` .. `2026-07-27 00:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent now | number | OK | 1 | `0` |
| 01 Peak (ungrouped) | number | OK | 1 | `0` |
| 01 Viewer-hours | number | OK | 1 | `0` |
| 01 Layer lag (s) | number | OK | 1 | `8` |
| 01 Concurrent viewers | line | OK | 0 | `—` |
| 01 Peak vs average (ungrouped) | line | OK | 0 | `—` |
| 01 Top titles | line | OK | 0 | `—` |
| 01 Title leaderboard | table | OK | 0 | `—` |
| 02 Average concurrency | number | OK | 1 | `6.27036` |
| 02 Viewer-hours | number | OK | 1 | `1779.53` |
| 02 Intervals started | number | OK | 1 | `31948` |
| 02 By platform | line | OK | 5073 | `2026-07-14 15:43:00IPHONE0.01` |
| 02 By content type | line | OK | 4187 | `2026-07-14 15:43:00vod0.01` |
| 02 Viewer-hours by category | pie | OK | 12 | `cdbgg185.53` |
| 02 Titles | table | OK | 25 | `wekek kedlivecdbgg170.1346042.2` |
| 02 Peak (ungrouped) | number | OK | 1 | `2305` |
| 02 Layer lag (s) | number | OK | 1 | `401` |
| 02 Peak minute | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Peak by grouping | table | OK | 60 | `totalall23052026-07-26 10:55:001779.533662` |
| 03 Ingest lag p50/p95/p99 (s) | line | OK | 0 | `—` |
| 03 Rows/s by producer | line | OK | 0 | `—` |
| 03 Read volume by query | table | OK | 0 | `—` |
| 03 Rollup duration (ms) | line | OK | 0 | `—` |
| 03 Sessions dirtied/min | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 22:51:45.9435859006283sonyliv-active-v` |
| 03 Dedup collapse | table | OK | 1 | `1524037151605179860.5240` |
| 03 Storage | table | OK | 11 | `events_clean1.52 million18.76 MiB17.4102` |
| 04 By platform | stacked_bar | OK | 5073 | `2026-07-14 15:43:00IPHONE0.01` |
| 04 Platform totals | table | OK | 10 | `ANDROID_PHONE1198.9267.3720134` |
| 04 By content type | stacked_bar | OK | 4187 | `2026-07-14 15:43:00vod0.01` |
| 04 Content type totals | table | OK | 3 | `vod1517.3685.2725304` |
| 04 By app version | stacked_bar | OK | 10065 | `2026-07-14 15:43:008.9.50.01` |
| 04 App version totals | table | OK | 30 | `6.34.8928.4752.1815573` |
| 04 By category | stacked_bar | OK | 6833 | `2026-07-14 15:43:00other0.01` |
| 04 Category totals | table | OK | 30 | `cdbgg185.5310.434831` |
| 04 By title (top 10) | stacked_bar | OK | 5295 | `2026-07-14 15:43:00other0.01` |
| 04 Title totals | table | OK | 30 | `wekek kedlivecdbgg170.139.564604` |
| 05 Peak (ungrouped) | number | OK | 1 | `2305` |
| 05 Average (ungrouped) | number | OK | 1 | `6.27036` |
| 05 Viewer-hours (ungrouped) | number | OK | 1 | `1779.53` |
| 05 Rows read | number | OK | 1 | `3662` |
| 05 Peak by dimension value | table | OK | 50 | `countryindia23052026-07-26 10:55:006.270361779.53` |
| 05 Peak per minute | line | OK | 308913 | `2026-07-14 15:43:00total: all1` |
| 05 Peak per hour | line | OK | 22484 | `2026-07-14 15:00:00country: india1` |
| 05 Per day | table | OK | 13548 | `2026-07-14platform + video typeIPHONE  vod12026-07-14 15:4` |
| 05 Query evidence | table | OK | 0 | `—` |
| 06 Worst retention — location | number | OK | 1 | `0` |
| 06 Worst retention — platform | number | OK | 1 | `0` |
| 06 Worst retention — content type | number | OK | 1 | `0` |
| 06 Worst retention — category | number | OK | 1 | `0` |
| 06 Detector lag (s) | number | OK | 1 | `412` |
| 06 Slices breaching | number | OK | 1 | `29` |
| 06 Slices watched | number | OK | 1 | `1` |
| 06 Settled through | table | OK | 1 | `2026-08-01 22:46:00.000413119150` |
| 06 Retention by location (alert below 0.70) | line | OK | 18720 | `2026-07-14 00:00:00india1` |
| 06 Observed vs baseline by location | line | OK | 37440 | `2026-07-14 00:00:00india observed0` |
| 06 Breaching slices, any dimension | table | OK | 29 | `platformJIO_ANDROID_TV152026-07-26 11:20:002026-07-26 11:3` |
| 06 Retention by platform | line | OK | 455 | `2026-07-26 08:37:00ANDROID_PHONE1` |
| 06 Retention by content type | line | OK | 269 | `2026-07-26 08:37:00vod1` |
| 06 Retention by category | line | OK | 752 | `2026-07-26 10:39:00cdbgg1` |

60 passed, 0 failed.

## live-30m — `2026-08-01 22:22:04` .. `2026-08-01 22:52:04`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent now | number | OK | 1 | `547` |
| 01 Peak (ungrouped) | number | OK | 1 | `2597` |
| 01 Viewer-hours | number | OK | 1 | `1042.93` |
| 01 Layer lag (s) | number | OK | 1 | `6` |
| 01 Concurrent viewers | line | OK | 31 | `2026-08-01 22:22:002145.35` |
| 01 Peak vs average (ungrouped) | line | OK | 31 | `2026-08-01 22:22:0025832140.85` |
| 01 Top titles | line | OK | 248 | `2026-08-01 22:22:00mupop dij4.17` |
| 01 Title leaderboard | table | OK | 25 | `nivev jadvodcdbgg20021758.24` |
| 02 Average concurrency | number | OK | 1 | `2473.129251` |
| 02 Viewer-hours | number | OK | 1 | `948.03` |
| 02 Intervals started | number | OK | 1 | `3630` |
| 02 By platform | line | OK | 230 | `2026-08-01 22:23:00ANDROID_PHONE2383.98` |
| 02 By content type | line | OK | 46 | `2026-08-01 22:23:00unknown9.68` |
| 02 Viewer-hours by category | pie | OK | 12 | `cdbgg733.73` |
| 02 Titles | table | OK | 25 | `nivev jadvodcdbgg730.3158763.7` |
| 02 Peak (ungrouped) | number | OK | 1 | `2597` |
| 02 Layer lag (s) | number | OK | 1 | `418` |
| 02 Peak minute | table | OK | 1 | `2026-08-01 22:30:0025972589.5` |
| 02 Peak by grouping | table | OK | 60 | `totalall25972026-08-01 22:30:00948.0323` |
| 03 Ingest lag p50/p95/p99 (s) | line | OK | 31 | `2026-08-01 22:22:000.81456.44492.078` |
| 03 Rows/s by producer | line | OK | 57 | `2026-08-01 22:22:00generator52.3` |
| 03 Read volume by query | table | OK | 30 | `470813130237996833-- =====================================` |
| 03 Rollup duration (ms) | line | OK | 88 | `2026-08-01 22:22:00live254` |
| 03 Sessions dirtied/min | line | OK | 31 | `2026-08-01 22:22:002774` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 22:51:55.9326459036284sonyliv-active-v` |
| 03 Dedup collapse | table | OK | 1 | `1524949151695879910.5240` |
| 03 Storage | table | OK | 11 | `events_clean1.52 million18.77 MiB17.4112` |
| 04 By platform | stacked_bar | OK | 230 | `2026-08-01 22:23:00ANDROID_PHONE2383.98` |
| 04 Platform totals | table | OK | 10 | `ANDROID_PHONE876.1792.422501` |
| 04 By content type | stacked_bar | OK | 46 | `2026-08-01 22:23:00unknown9.68` |
| 04 Content type totals | table | OK | 2 | `vod944.2199.63575` |
| 04 By app version | stacked_bar | OK | 184 | `2026-08-01 22:23:008.9.533.24` |
| 04 App version totals | table | OK | 8 | `6.34.8868.1891.582321` |
| 04 By category | stacked_bar | OK | 253 | `2026-08-01 22:23:00other431.43` |
| 04 Category totals | table | OK | 30 | `cdbgg733.7377.455` |
| 04 By title (top 10) | stacked_bar | OK | 253 | `2026-08-01 22:23:00fizoz lag7.16` |
| 04 Title totals | table | OK | 30 | `nivev jadvodcdbgg730.3177.035` |
| 05 Peak (ungrouped) | number | OK | 1 | `2597` |
| 05 Average (ungrouped) | number | OK | 1 | `2473.129251` |
| 05 Viewer-hours (ungrouped) | number | OK | 1 | `948.03` |
| 05 Rows read | number | OK | 1 | `23` |
| 05 Peak by dimension value | table | OK | 50 | `countryindia25972026-08-01 22:30:002473.129251948.03` |
| 05 Peak per minute | line | OK | 30316 | `2026-08-01 22:23:00total: all2587` |
| 05 Peak per hour | line | OK | 2265 | `2026-08-01 22:00:00all dimensions: ANDROID_PHONE  india  v` |
| 05 Per day | table | OK | 2265 | `2026-08-01totalall25972026-08-01 22:30:0039.50142473.12923` |
| 05 Query evidence | table | OK | 20 | `709033c5-4816-4e13-8e57-6814e6b8ca696218009060501198122318` |
| 06 Worst retention — location | number | OK | 1 | `0.898855` |
| 06 Worst retention — platform | number | OK | 1 | `0.780024` |
| 06 Worst retention — content type | number | OK | 1 | `0.897402` |
| 06 Worst retention — category | number | OK | 1 | `0.054028` |
| 06 Detector lag (s) | number | OK | 1 | `425` |
| 06 Slices breaching | number | OK | 1 | `1` |
| 06 Slices watched | number | OK | 1 | `1` |
| 06 Settled through | table | OK | 1 | `2026-08-01 22:46:00.000425119150` |
| 06 Retention by location (alert below 0.70) | line | OK | 24 | `2026-08-01 22:22:00india1` |
| 06 Observed vs baseline by location | line | OK | 48 | `2026-08-01 22:22:00india observed2569.345` |
| 06 Breaching slices, any dimension | table | OK | 1 | `categorydjfhp12026-08-01 22:22:002026-08-01 22:22:000.0549` |
| 06 Retention by platform | line | OK | 96 | `2026-08-01 22:22:00IPHONE0.997254` |
| 06 Retention by content type | line | OK | 24 | `2026-08-01 22:22:00vod1` |
| 06 Retention by category | line | OK | 25 | `2026-08-01 22:22:00cdbgg1` |

60 passed, 0 failed.

## live-6h — `2026-08-01 16:52:04` .. `2026-08-01 22:52:04`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent now | number | OK | 1 | `549` |
| 01 Peak (ungrouped) | number | OK | 1 | `2803` |
| 01 Viewer-hours | number | OK | 1 | `2564.78` |
| 01 Layer lag (s) | number | OK | 1 | `7` |
| 01 Concurrent viewers | line | OK | 185 | `2026-08-01 19:48:00157.62` |
| 01 Peak vs average (ungrouped) | line | OK | 185 | `2026-08-01 19:48:00328157.62` |
| 01 Top titles | line | OK | 1074 | `2026-08-01 19:49:00cegeg gef0.57` |
| 01 Title leaderboard | table | OK | 25 | `nivev jadvodcdbgg200211038.75` |
| 02 Average concurrency | number | OK | 1 | `433.151757` |
| 02 Viewer-hours | number | OK | 1 | `2512.28` |
| 02 Intervals started | number | OK | 1 | `26217` |
| 02 By platform | line | OK | 1509 | `2026-08-01 16:58:00ANDROID_TAB0.31` |
| 02 By content type | line | OK | 252 | `2026-08-01 16:58:00unknown2.7` |
| 02 Viewer-hours by category | pie | OK | 12 | `cdbgg1073.37` |
| 02 Titles | table | OK | 25 | `nivev jadvodcdbgg1038.64249924.9` |
| 02 Peak (ungrouped) | number | OK | 1 | `2797` |
| 02 Layer lag (s) | number | OK | 1 | `429` |
| 02 Peak minute | table | OK | 1 | `2026-08-01 22:14:0027972596.51` |
| 02 Peak by grouping | table | OK | 60 | `totalall27972026-08-01 22:14:002512.28194` |
| 03 Ingest lag p50/p95/p99 (s) | line | OK | 191 | `2026-08-01 16:58:00-8.16838.72141.521` |
| 03 Rows/s by producer | line | OK | 253 | `2026-08-01 16:58:00mock-dashboard21.4` |
| 03 Read volume by query | table | OK | 30 | `470813130237996833-- =====================================` |
| 03 Rollup duration (ms) | line | OK | 445 | `2026-08-01 19:45:00live177` |
| 03 Sessions dirtied/min | line | OK | 191 | `2026-08-01 16:58:00152` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 22:52:05.9196659063286sonyliv-active-v` |
| 03 Dedup collapse | table | OK | 1 | `1525554151755679980.52430` |
| 03 Storage | table | OK | 11 | `events_clean1.52 million18.79 MiB17.4132` |
| 04 By platform | stacked_bar | OK | 1509 | `2026-08-01 16:58:00ANDROID_TAB0.31` |
| 04 Platform totals | table | OK | 12 | `ANDROID_PHONE2096.8383.4618732` |
| 04 By content type | stacked_bar | OK | 252 | `2026-08-01 16:58:00unknown2.7` |
| 04 Content type totals | table | OK | 3 | `vod2503.2599.6426036` |
| 04 By app version | stacked_bar | OK | 1244 | `2026-08-01 16:58:006.33.22.12` |
| 04 App version totals | table | OK | 9 | `6.34.82021.4380.4617161` |
| 04 By category | stacked_bar | OK | 1522 | `2026-08-01 16:58:00djfhp1.77` |
| 04 Category totals | table | OK | 30 | `cdbgg1073.3742.723086` |
| 04 By title (top 10) | stacked_bar | OK | 1466 | `2026-08-01 16:58:00tifif feh0.87` |
| 04 Title totals | table | OK | 30 | `nivev jadvodcdbgg1038.6441.342499` |
| 05 Peak (ungrouped) | number | OK | 1 | `2797` |
| 05 Average (ungrouped) | number | OK | 1 | `433.151757` |
| 05 Viewer-hours (ungrouped) | number | OK | 1 | `2512.28` |
| 05 Rows read | number | OK | 1 | `194` |
| 05 Peak by dimension value | table | OK | 50 | `countryindia27972026-08-01 22:14:00433.1517572512.28` |
| 05 Peak per minute | line | OK | 119106 | `2026-08-01 16:58:00total: all145` |
| 05 Peak per hour | line | OK | 8771 | `2026-08-01 16:00:00platform + content: JIO_ANDROID_TV  vub` |
| 05 Per day | table | OK | 6163 | `2026-08-01totalall27972026-08-01 22:14:00104.6783776.99419` |
| 05 Query evidence | table | OK | 20 | `709033c5-4816-4e13-8e57-6814e6b8ca696218009060501198122318` |
| 06 Worst retention — location | number | OK | 1 | `0.354622` |
| 06 Worst retention — platform | number | OK | 1 | `0` |
| 06 Worst retention — content type | number | OK | 1 | `0.354622` |
| 06 Worst retention — category | number | OK | 1 | `0` |
| 06 Detector lag (s) | number | OK | 1 | `437` |
| 06 Slices breaching | number | OK | 1 | `12` |
| 06 Slices watched | number | OK | 1 | `1` |
| 06 Settled through | table | OK | 1 | `2026-08-01 22:46:00.000438119150` |
| 06 Retention by location (alert below 0.70) | line | OK | 354 | `2026-08-01 16:52:00india1` |
| 06 Observed vs baseline by location | line | OK | 708 | `2026-08-01 16:52:00india observed0` |
| 06 Breaching slices, any dimension | table | OK | 12 | `platformJIO_ANDROID_TV62026-08-01 21:25:002026-08-01 21:30` |
| 06 Retention by platform | line | OK | 555 | `2026-08-01 19:56:00ANDROID_PHONE1` |
| 06 Retention by content type | line | OK | 170 | `2026-08-01 19:56:00vod1` |
| 06 Retention by category | line | OK | 443 | `2026-08-01 20:00:00chbgg1` |

60 passed, 0 failed.

---

**Total: 360 passed, 0 failed.**
