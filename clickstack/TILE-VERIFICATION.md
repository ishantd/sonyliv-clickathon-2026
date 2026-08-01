# ClickStack tile verification

Database `sonyliv_prod`, granularity 60s, generated 2026-08-01 23:09:39Z.

## hot-hour — `2026-07-26 10:00:00` .. `2026-07-26 11:00:00`

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
| 02 Average concurrency | number | OK | 1 | `855.603469` |
| 02 Viewer-hours | number | OK | 1 | `855.6` |
| 02 Intervals started | number | OK | 1 | `16173` |
| 02 By platform | line | OK | 407 | `2026-07-26 10:00:00ANDROID_TAB1` |
| 02 By content type | line | OK | 140 | `2026-07-26 10:00:00vod48.04` |
| 02 Viewer-hours by category | pie | OK | 12 | `cdbgg128.71` |
| 02 Titles | table | OK | 25 | `wekek kedlivecdbgg119.7225532.8` |
| 02 Peak (ungrouped) | number | OK | 1 | `2305` |
| 02 Layer lag (s) | number | OK | 1 | `401` |
| 02 Peak minute | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Peak by grouping | table | OK | 60 | `totalall23052026-07-26 10:55:00855.660` |
| 03 Ingest lag p50/p95/p99 (s) | line | OK | 0 | `—` |
| 03 Rows/s by producer | line | OK | 0 | `—` |
| 03 Read volume by query | table | OK | 0 | `—` |
| 03 Recent queries | table | OK | 0 | `—` |
| 03 Rollup duration (ms) | line | OK | 0 | `—` |
| 03 Sessions dirtied/min | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 23:09:41.179266273361sonyliv-active-v1` |
| 03 Dedup collapse | table | OK | 1 | `1639095163084382520.50340` |
| 03 Storage | table | OK | 11 | `events_clean1.63 million21.39 MiB16.4142` |
| 03 Query log coverage | table | OK | 1 | `2026-08-01 22:23:462026-08-01 23:09:23464821146 minutes an` |
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
| 06 Detector lag (s) | number | OK | 1 | `410` |
| 06 Slices breaching | number | OK | 1 | `0` |
| 06 Slices watched | number | OK | 1 | `1` |
| 06 Settled through | table | OK | 1 | `2026-08-01 23:03:00.000412140963` |
| 06 Retention by location (alert below 0.70) | line | OK | 60 | `2026-07-26 10:00:00india1` |
| 06 Observed vs baseline by location | line | OK | 120 | `2026-07-26 10:00:00india observed48.042383` |
| 06 Breaching slices, any dimension | table | OK | 0 | `—` |
| 06 Retention by platform | line | OK | 155 | `2026-07-26 10:00:00ANDROID_PHONE1` |
| 06 Retention by content type | line | OK | 97 | `2026-07-26 10:00:00vod1` |
| 06 Retention by category | line | OK | 200 | `2026-07-26 10:39:00cdbgg1` |

62 passed, 0 failed.

## hot-day — `2026-07-26 00:00:00` .. `2026-07-27 00:00:00`

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
| 02 Average concurrency | number | OK | 1 | `147.290321` |
| 02 Viewer-hours | number | OK | 1 | `1671.75` |
| 02 Intervals started | number | OK | 1 | `30706` |
| 02 By platform | line | OK | 1668 | `2026-07-26 00:10:00ANDROID_PHONE0.44` |
| 02 By content type | line | OK | 988 | `2026-07-26 00:10:00vod0.44` |
| 02 Viewer-hours by category | pie | OK | 12 | `cdbgg184.24` |
| 02 Titles | table | OK | 25 | `wekek kedlivecdbgg170.1346042.2` |
| 02 Peak (ungrouped) | number | OK | 1 | `2305` |
| 02 Layer lag (s) | number | OK | 1 | `416` |
| 02 Peak minute | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Peak by grouping | table | OK | 60 | `totalall23052026-07-26 10:55:001671.75637` |
| 03 Ingest lag p50/p95/p99 (s) | line | OK | 0 | `—` |
| 03 Rows/s by producer | line | OK | 0 | `—` |
| 03 Read volume by query | table | OK | 0 | `—` |
| 03 Recent queries | table | OK | 0 | `—` |
| 03 Rollup duration (ms) | line | OK | 0 | `—` |
| 03 Sessions dirtied/min | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 23:09:51.179766295399sonyliv-active-v1` |
| 03 Dedup collapse | table | OK | 1 | `1640864163260882560.50310` |
| 03 Storage | table | OK | 11 | `events_clean1.63 million21.42 MiB16.4142` |
| 03 Query log coverage | table | OK | 1 | `2026-08-01 22:23:462026-08-01 23:09:53464898146 minutes an` |
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
| 05 Peak by dimension value | table | OK | 50 | `totalall23052026-07-26 10:55:00147.2903211671.75` |
| 05 Peak per minute | line | OK | 255642 | `2026-07-26 00:10:00total: all1` |
| 05 Peak per hour | line | OK | 19646 | `2026-07-26 00:00:00category: dhddd1` |
| 05 Per day | table | OK | 12357 | `2026-07-26totalall23052026-07-26 10:55:0069.656157.464637` |
| 05 Query evidence | table | OK | 0 | `—` |
| 06 Worst retention — location | number | OK | 1 | `0` |
| 06 Worst retention — platform | number | OK | 1 | `0` |
| 06 Worst retention — content type | number | OK | 1 | `0` |
| 06 Worst retention — category | number | OK | 1 | `0` |
| 06 Detector lag (s) | number | OK | 1 | `310` |
| 06 Slices breaching | number | OK | 1 | `29` |
| 06 Slices watched | number | OK | 1 | `1` |
| 06 Settled through | table | OK | 1 | `2026-08-01 23:05:00.000311143505` |
| 06 Retention by location (alert below 0.70) | line | OK | 1440 | `2026-07-26 00:00:00india1` |
| 06 Observed vs baseline by location | line | OK | 2880 | `2026-07-26 00:00:00india observed0` |
| 06 Breaching slices, any dimension | table | OK | 29 | `categorycdbgg202026-07-26 11:01:002026-07-26 11:35:000100-` |
| 06 Retention by platform | line | OK | 455 | `2026-07-26 08:37:00ANDROID_PHONE1` |
| 06 Retention by content type | line | OK | 269 | `2026-07-26 08:37:00vod1` |
| 06 Retention by category | line | OK | 752 | `2026-07-26 10:39:00cdbgg1` |

62 passed, 0 failed.

## gap-no-data — `2026-07-16 00:00:00` .. `2026-07-18 00:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent now | number | OK | 1 | `0` |
| 01 Peak (ungrouped) | number | OK | 1 | `0` |
| 01 Viewer-hours | number | OK | 1 | `0` |
| 01 Layer lag (s) | number | OK | 1 | `3` |
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
| 02 Layer lag (s) | number | OK | 1 | `316` |
| 02 Peak minute | table | OK | 0 | `—` |
| 02 Peak by grouping | table | OK | 0 | `—` |
| 03 Ingest lag p50/p95/p99 (s) | line | OK | 0 | `—` |
| 03 Rows/s by producer | line | OK | 0 | `—` |
| 03 Read volume by query | table | OK | 0 | `—` |
| 03 Recent queries | table | OK | 0 | `—` |
| 03 Rollup duration (ms) | line | OK | 0 | `—` |
| 03 Sessions dirtied/min | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 23:10:11.179766341365sonyliv-active-v1` |
| 03 Dedup collapse | table | OK | 1 | `1642939163467782620.50290` |
| 03 Storage | table | OK | 11 | `events_clean1.63 million21.45 MiB16.4132` |
| 03 Query log coverage | table | OK | 1 | `2026-08-01 22:23:462026-08-01 23:09:53464898146 minutes an` |
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
| 06 Detector lag (s) | number | OK | 1 | `323` |
| 06 Slices breaching | number | OK | 1 | `0` |
| 06 Slices watched | number | OK | 1 | `0` |
| 06 Settled through | table | OK | 1 | `2026-08-01 23:05:00.000324143505` |
| 06 Retention by location (alert below 0.70) | line | OK | 0 | `—` |
| 06 Observed vs baseline by location | line | OK | 0 | `—` |
| 06 Breaching slices, any dimension | table | OK | 0 | `—` |
| 06 Retention by platform | line | OK | 0 | `—` |
| 06 Retention by content type | line | OK | 0 | `—` |
| 06 Retention by category | line | OK | 0 | `—` |

62 passed, 0 failed.

## full-extract — `2026-07-14 00:00:00` .. `2026-07-27 00:00:00`

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
| 02 Average concurrency | number | OK | 1 | `6.27036` |
| 02 Viewer-hours | number | OK | 1 | `1779.53` |
| 02 Intervals started | number | OK | 1 | `31948` |
| 02 By platform | line | OK | 5073 | `2026-07-14 15:43:00IPHONE0.01` |
| 02 By content type | line | OK | 4187 | `2026-07-14 15:43:00vod0.01` |
| 02 Viewer-hours by category | pie | OK | 12 | `cdbgg185.53` |
| 02 Titles | table | OK | 25 | `wekek kedlivecdbgg170.1346042.2` |
| 02 Peak (ungrouped) | number | OK | 1 | `2305` |
| 02 Layer lag (s) | number | OK | 1 | `329` |
| 02 Peak minute | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Peak by grouping | table | OK | 60 | `totalall23052026-07-26 10:55:001779.533662` |
| 03 Ingest lag p50/p95/p99 (s) | line | OK | 0 | `—` |
| 03 Rows/s by producer | line | OK | 0 | `—` |
| 03 Read volume by query | table | OK | 0 | `—` |
| 03 Recent queries | table | OK | 0 | `—` |
| 03 Rollup duration (ms) | line | OK | 0 | `—` |
| 03 Sessions dirtied/min | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 23:10:21.1781066367368sonyliv-active-v` |
| 03 Dedup collapse | table | OK | 1 | `1644249163598382660.50270` |
| 03 Storage | table | OK | 11 | `events_clean1.64 million21.48 MiB16.4152` |
| 03 Query log coverage | table | OK | 1 | `2026-08-01 22:23:462026-08-01 23:10:24474988946 minutes an` |
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
| 05 Peak by dimension value | table | OK | 50 | `totalall23052026-07-26 10:55:006.270361779.53` |
| 05 Peak per minute | line | OK | 308913 | `2026-07-14 15:43:00total: all1` |
| 05 Peak per hour | line | OK | 22484 | `2026-07-14 15:00:00all dimensions: IPHONE  india  vod  bhb` |
| 05 Per day | table | OK | 13548 | `2026-07-14contentjipep dih12026-07-14 15:43:000.0130.71926` |
| 05 Query evidence | table | OK | 0 | `—` |
| 06 Worst retention — location | number | OK | 1 | `0` |
| 06 Worst retention — platform | number | OK | 1 | `0` |
| 06 Worst retention — content type | number | OK | 1 | `0` |
| 06 Worst retention — category | number | OK | 1 | `0` |
| 06 Detector lag (s) | number | OK | 1 | `341` |
| 06 Slices breaching | number | OK | 1 | `29` |
| 06 Slices watched | number | OK | 1 | `1` |
| 06 Settled through | table | OK | 1 | `2026-08-01 23:05:00.000342143505` |
| 06 Retention by location (alert below 0.70) | line | OK | 18720 | `2026-07-14 00:00:00india1` |
| 06 Observed vs baseline by location | line | OK | 37440 | `2026-07-14 00:00:00india observed0` |
| 06 Breaching slices, any dimension | table | OK | 29 | `platformIPHONE162026-07-26 11:20:002026-07-26 11:35:000100` |
| 06 Retention by platform | line | OK | 455 | `2026-07-26 08:37:00ANDROID_PHONE1` |
| 06 Retention by content type | line | OK | 269 | `2026-07-26 08:37:00vod1` |
| 06 Retention by category | line | OK | 752 | `2026-07-26 10:39:00cdbgg1` |

62 passed, 0 failed.

## live-30m — `2026-08-01 22:39:38` .. `2026-08-01 23:09:39`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent now | number | OK | 1 | `571` |
| 01 Peak (ungrouped) | number | OK | 1 | `5287` |
| 01 Viewer-hours | number | OK | 1 | `750.58` |
| 01 Layer lag (s) | number | OK | 1 | `6` |
| 01 Concurrent viewers | line | OK | 31 | `2026-08-01 22:39:00854.78` |
| 01 Peak vs average (ungrouped) | line | OK | 31 | `2026-08-01 22:39:002562852.11` |
| 01 Top titles | line | OK | 240 | `2026-08-01 22:39:00dijij jeb1.66` |
| 01 Title leaderboard | table | OK | 25 | `necec cegvodcgdgn2503464.38` |
| 02 Average concurrency | number | OK | 1 | `1142.590041` |
| 02 Viewer-hours | number | OK | 1 | `476.08` |
| 02 Intervals started | number | OK | 1 | `5958` |
| 02 By platform | line | OK | 252 | `2026-08-01 22:40:00SONY_ANDROID_TV48.28` |
| 02 By content type | line | OK | 50 | `2026-08-01 22:40:00vod2551.57` |
| 02 Viewer-hours by category | pie | OK | 12 | `cdbgg167.29` |
| 02 Titles | table | OK | 25 | `nivev jadvodcdbgg163.9814702.8` |
| 02 Peak (ungrouped) | number | OK | 1 | `2768` |
| 02 Layer lag (s) | number | OK | 1 | `349` |
| 02 Peak minute | table | OK | 1 | `2026-08-01 23:04:0027682757.61` |
| 02 Peak by grouping | table | OK | 60 | `totalall27682026-08-01 23:04:00476.0825` |
| 03 Ingest lag p50/p95/p99 (s) | line | OK | 31 | `2026-08-01 22:39:000.81356.44585.46` |
| 03 Rows/s by producer | line | OK | 52 | `2026-08-01 22:39:00api24` |
| 03 Read volume by query | table | OK | 30 | `470813130237996833-- =====================================` |
| 03 Recent queries | table | OK | 200 | `2026-08-01 23:09:3820582144.8176113.1SELECT now64(?) as sc` |
| 03 Rollup duration (ms) | line | OK | 88 | `2026-08-01 22:39:00intervals407` |
| 03 Sessions dirtied/min | line | OK | 31 | `2026-08-01 22:39:001942` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 23:10:41.179966423318sonyliv-active-v1` |
| 03 Dedup collapse | table | OK | 1 | `1646312163803982730.50250` |
| 03 Storage | table | OK | 11 | `events_clean1.64 million21.51 MiB16.4152` |
| 03 Query log coverage | table | OK | 1 | `2026-08-01 22:23:462026-08-01 23:10:24474988947 minutes an` |
| 04 By platform | stacked_bar | OK | 252 | `2026-08-01 22:40:00SONY_ANDROID_TV48.28` |
| 04 Platform totals | table | OK | 11 | `ANDROID_PHONE346.2172.722825` |
| 04 By content type | stacked_bar | OK | 50 | `2026-08-01 22:40:00vod2551.57` |
| 04 Content type totals | table | OK | 2 | `vod471.8699.115894` |
| 04 By app version | stacked_bar | OK | 202 | `2026-08-01 22:40:008.9.530.94` |
| 04 App version totals | table | OK | 9 | `6.34.8332.0569.752525` |
| 04 By category | stacked_bar | OK | 275 | `2026-08-01 22:40:00bgfff12.4` |
| 04 Category totals | table | OK | 30 | `cdbgg167.2935.1470` |
| 04 By title (top 10) | stacked_bar | OK | 264 | `2026-08-01 22:40:00zotat hac4.33` |
| 04 Title totals | table | OK | 30 | `nivev jadvodcdbgg163.9834.4414` |
| 05 Peak (ungrouped) | number | OK | 1 | `2768` |
| 05 Average (ungrouped) | number | OK | 1 | `1142.590041` |
| 05 Viewer-hours (ungrouped) | number | OK | 1 | `476.08` |
| 05 Rows read | number | OK | 1 | `25` |
| 05 Peak by dimension value | table | OK | 50 | `totalall27682026-08-01 23:04:001142.590041476.08` |
| 05 Peak per minute | line | OK | 32127 | `2026-08-01 22:40:00total: all2570` |
| 05 Peak per hour | line | OK | 3612 | `2026-08-01 22:00:00all dimensions: ANDROID_PHONE  india  v` |
| 05 Per day | table | OK | 2254 | `2026-08-01totalall27682026-08-01 23:04:0019.83661142.5925` |
| 05 Query evidence | table | OK | 20 | `719e5d14-6c86-41f6-81b6-207649d44adc2171875668550170428152` |
| 06 Worst retention — location | number | OK | 1 | `0.211258` |
| 06 Worst retention — platform | number | OK | 1 | `0.15428` |
| 06 Worst retention — content type | number | OK | 1 | `0.208036` |
| 06 Worst retention — category | number | OK | 1 | `0.004216` |
| 06 Detector lag (s) | number | OK | 1 | `357` |
| 06 Slices breaching | number | OK | 1 | `4` |
| 06 Slices watched | number | OK | 1 | `1` |
| 06 Settled through | table | OK | 1 | `2026-08-01 23:05:00.000357143505` |
| 06 Retention by location (alert below 0.70) | line | OK | 26 | `2026-08-01 22:39:00india0.993648` |
| 06 Observed vs baseline by location | line | OK | 52 | `2026-08-01 22:39:00india observed2559.045783` |
| 06 Breaching slices, any dimension | table | OK | 4 | `categorycdbgg82026-08-01 22:46:002026-08-01 22:53:000.0042` |
| 06 Retention by platform | line | OK | 104 | `2026-08-01 22:39:00SONY_ANDROID_TV0.821528` |
| 06 Retention by content type | line | OK | 26 | `2026-08-01 22:39:00vod0.994119` |
| 06 Retention by category | line | OK | 15 | `2026-08-01 22:39:00cdbgg1` |

62 passed, 0 failed.

## live-6h — `2026-08-01 17:09:39` .. `2026-08-01 23:09:39`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent now | number | OK | 1 | `574` |
| 01 Peak (ungrouped) | number | OK | 1 | `5287` |
| 01 Viewer-hours | number | OK | 1 | `3024.8` |
| 01 Layer lag (s) | number | OK | 1 | `10` |
| 01 Concurrent viewers | line | OK | 202 | `2026-08-01 19:48:00157.62` |
| 01 Peak vs average (ungrouped) | line | OK | 202 | `2026-08-01 19:48:00328157.62` |
| 01 Top titles | line | OK | 1193 | `2026-08-01 19:49:00cegeg gef0.57` |
| 01 Title leaderboard | table | OK | 25 | `necec cegvodcgdgn2503493.98` |
| 02 Average concurrency | number | OK | 1 | `470.816368` |
| 02 Viewer-hours | number | OK | 1 | `2762.12` |
| 02 Intervals started | number | OK | 1 | `31033` |
| 02 By platform | line | OK | 1654 | `2026-08-01 17:13:00SONY_ANDROID_TV0.95` |
| 02 By content type | line | OK | 278 | `2026-08-01 17:13:00vod16.71` |
| 02 Viewer-hours by category | pie | OK | 12 | `cdbgg1075.85` |
| 02 Titles | table | OK | 25 | `nivev jadvodcdbgg1038.97250924.8` |
| 02 Peak (ungrouped) | number | OK | 1 | `2797` |
| 02 Layer lag (s) | number | OK | 1 | `362` |
| 02 Peak minute | table | OK | 1 | `2026-08-01 22:14:0027972757.61` |
| 02 Peak by grouping | table | OK | 60 | `totalall27972026-08-01 22:14:002762.12205` |
| 03 Ingest lag p50/p95/p99 (s) | line | OK | 205 | `2026-08-01 17:13:0011.99452.15652.948` |
| 03 Rows/s by producer | line | OK | 282 | `2026-08-01 17:13:00api1.7` |
| 03 Read volume by query | table | OK | 30 | `470813130237996833-- =====================================` |
| 03 Recent queries | table | OK | 200 | `2026-08-01 23:09:3820582144.8176113.1SELECT now64(?) as sc` |
| 03 Rollup duration (ms) | line | OK | 494 | `2026-08-01 19:45:00live177` |
| 03 Sessions dirtied/min | line | OK | 205 | `2026-08-01 17:13:0020` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 23:11:01.179366475324sonyliv-active-v1` |
| 03 Dedup collapse | table | OK | 1 | `1647617163934182760.50230` |
| 03 Storage | table | OK | 11 | `events_clean1.64 million21.52 MiB16.4152` |
| 03 Query log coverage | table | OK | 1 | `2026-08-01 22:23:462026-08-01 23:10:54475073647 minutes an` |
| 04 By platform | stacked_bar | OK | 1654 | `2026-08-01 17:13:00SONY_ANDROID_TV0.95` |
| 04 Platform totals | table | OK | 13 | `ANDROID_PHONE2236.4980.9720740` |
| 04 By content type | stacked_bar | OK | 278 | `2026-08-01 17:13:00vod16.71` |
| 04 Content type totals | table | OK | 3 | `vod2750.1299.5730811` |
| 04 By app version | stacked_bar | OK | 1347 | `2026-08-01 17:13:003.11.10.9` |
| 04 App version totals | table | OK | 10 | `6.34.82150.0277.8418967` |
| 04 By category | stacked_bar | OK | 1708 | `2026-08-01 17:13:00other14.23` |
| 04 Category totals | table | OK | 30 | `cdbgg1075.8538.953135` |
| 04 By title (top 10) | stacked_bar | OK | 1629 | `2026-08-01 17:13:00other14.23` |
| 04 Title totals | table | OK | 30 | `nivev jadvodcdbgg1038.9737.612509` |
| 05 Peak (ungrouped) | number | OK | 1 | `2797` |
| 05 Average (ungrouped) | number | OK | 1 | `470.816368` |
| 05 Viewer-hours (ungrouped) | number | OK | 1 | `2762.12` |
| 05 Rows read | number | OK | 1 | `205` |
| 05 Peak by dimension value | table | OK | 50 | `countryindia27972026-08-01 22:14:00470.8163682762.12` |
| 05 Peak per minute | line | OK | 141416 | `2026-08-01 17:13:00total: all20` |
| 05 Peak per hour | line | OK | 9707 | `2026-08-01 17:00:00app version: 2.14.02` |
| 05 Per day | table | OK | 6339 | `2026-08-01totalall27972026-08-01 22:14:00115.0884808.42620` |
| 05 Query evidence | table | OK | 20 | `9bc5671e-e2f4-47fb-872e-44c6fe5cc6822171875668550170421116` |
| 06 Worst retention — location | number | OK | 1 | `0.211258` |
| 06 Worst retention — platform | number | OK | 1 | `0` |
| 06 Worst retention — content type | number | OK | 1 | `0.208036` |
| 06 Worst retention — category | number | OK | 1 | `0` |
| 06 Detector lag (s) | number | OK | 1 | `372` |
| 06 Slices breaching | number | OK | 1 | `12` |
| 06 Slices watched | number | OK | 1 | `1` |
| 06 Settled through | table | OK | 1 | `2026-08-01 23:05:00.000373143505` |
| 06 Retention by location (alert below 0.70) | line | OK | 356 | `2026-08-01 17:09:00india1` |
| 06 Observed vs baseline by location | line | OK | 712 | `2026-08-01 17:09:00india observed0` |
| 06 Breaching slices, any dimension | table | OK | 12 | `platformJIO_ANDROID_TV62026-08-01 21:25:002026-08-01 21:30` |
| 06 Retention by platform | line | OK | 631 | `2026-08-01 19:56:00ANDROID_PHONE1` |
| 06 Retention by content type | line | OK | 189 | `2026-08-01 19:56:00vod1` |
| 06 Retention by category | line | OK | 451 | `2026-08-01 20:00:00chbgg1` |

62 passed, 0 failed.

---

**Total: 372 passed, 0 failed.**
