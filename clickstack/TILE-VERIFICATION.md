# ClickStack tile verification

Database `sonyliv_prod`, granularity 60s, generated 2026-08-01 22:16:37Z.

## hot-hour — `2026-07-26 10:00:00` .. `2026-07-26 11:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `0` |
| 01 Exact peak in window — all titles | number | OK | 1 | `0` |
| 01 Viewer-hours in window | number | OK | 1 | `0` |
| 01 Live layer lag (seconds) | number | OK | 1 | `7` |
| 01 Average concurrent viewers — responds to the filters above | line | OK | 0 | `—` |
| 01 Exact peak vs average — all titles, NOT filtered | line | OK | 0 | `—` |
| 01 Top titles — average concurrent viewers | line | OK | 0 | `—` |
| 01 Title leaderboard | table | OK | 0 | `—` |
| 02 Time-weighted average concurrency | number | OK | 1 | `855.603469` |
| 02 Viewer-hours | number | OK | 1 | `855.6` |
| 02 Active intervals started | number | OK | 1 | `16173` |
| 02 Average concurrency by platform | line | OK | 407 | `2026-07-26 10:00:00ANDROID_TAB1` |
| 02 Average concurrency by content type | line | OK | 140 | `2026-07-26 10:00:00vod48.04` |
| 02 Viewer-hours by category | pie | OK | 12 | `cdbgg128.71` |
| 02 Titles by viewer-hours | table | OK | 25 | `wekek kedlivecdbgg119.7225532.8` |
| 02 Exact peak — all dimensions collapsed | number | OK | 1 | `2305` |
| 02 Minute layer lag (seconds) | number | OK | 1 | `339` |
| 02 Peak minute in window | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Exact peak by the selected grouping | table | OK | 60 | `totalall23052026-07-26 10:55:00855.660` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — cluster-wide | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 22:16:32.004953322275sonyliv-active-v1` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1297240128987373670.56790` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.29 million13.61 MiB20.3132` |
| 04 Average concurrent viewers by platform | stacked_bar | OK | 407 | `2026-07-26 10:00:00ANDROID_TAB1` |
| 04 Platform totals | table | OK | 10 | `ANDROID_PHONE552.4764.579979` |
| 04 Average concurrent viewers by content type | stacked_bar | OK | 140 | `2026-07-26 10:00:00vod48.04` |
| 04 Content type totals | table | OK | 3 | `vod700.1381.8312800` |
| 04 Average concurrent viewers by app version | stacked_bar | OK | 1648 | `2026-07-26 10:00:006.34.834.12` |
| 04 App version totals | table | OK | 30 | `6.34.8444.2151.927895` |
| 04 Average concurrent viewers by category | stacked_bar | OK | 610 | `2026-07-26 10:00:00dhddd1` |
| 04 Category totals | table | OK | 30 | `cdbgg128.7115.042700` |
| 04 Average concurrent viewers by title (top 10, rest folded into 'other') | stacked_bar | OK | 521 | `2026-07-26 10:00:00dijoj jeh1` |
| 04 Title totals | table | OK | 30 | `wekek kedlivecdbgg119.7213.992553` |
| 05 Exact peak concurrency — all dimensions collapsed | number | OK | 1 | `2305` |
| 05 Time-weighted average concurrency — all dimensions collapsed | number | OK | 1 | `855.603469` |
| 05 Viewer-hours — all dimensions collapsed | number | OK | 1 | `855.6` |
| 05 Rows this answer read — all dimensions collapsed | number | OK | 1 | `60` |
| 05 Exact peak per dimension value in the selected grouping | table | OK | 50 | `countryindia23052026-07-26 10:55:00855.603469855.6` |
| 05 Peak per minute | line | OK | 118972 | `2026-07-26 10:00:00total: all50` |
| 05 Peak per hour | line | OK | 9308 | `2026-07-26 10:00:00content: zigog gaj1` |
| 05 Peak and average per day | table | OK | 9308 | `2026-07-26countryindia23052026-07-26 10:55:0035.6501855.60` |
| 05 Pipeline evidence — what these answers actually read | table | OK | 0 | `—` |

46 passed, 0 failed.

## hot-day — `2026-07-26 00:00:00` .. `2026-07-27 00:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `0` |
| 01 Exact peak in window — all titles | number | OK | 1 | `0` |
| 01 Viewer-hours in window | number | OK | 1 | `0` |
| 01 Live layer lag (seconds) | number | OK | 1 | `6` |
| 01 Average concurrent viewers — responds to the filters above | line | OK | 0 | `—` |
| 01 Exact peak vs average — all titles, NOT filtered | line | OK | 0 | `—` |
| 01 Top titles — average concurrent viewers | line | OK | 0 | `—` |
| 01 Title leaderboard | table | OK | 0 | `—` |
| 02 Time-weighted average concurrency | number | OK | 1 | `147.290321` |
| 02 Viewer-hours | number | OK | 1 | `1671.75` |
| 02 Active intervals started | number | OK | 1 | `30706` |
| 02 Average concurrency by platform | line | OK | 1668 | `2026-07-26 00:10:00ANDROID_PHONE0.44` |
| 02 Average concurrency by content type | line | OK | 988 | `2026-07-26 00:10:00vod0.44` |
| 02 Viewer-hours by category | pie | OK | 12 | `cdbgg184.24` |
| 02 Titles by viewer-hours | table | OK | 25 | `wekek kedlivecdbgg170.1346042.2` |
| 02 Exact peak — all dimensions collapsed | number | OK | 1 | `2305` |
| 02 Minute layer lag (seconds) | number | OK | 1 | `348` |
| 02 Peak minute in window | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Exact peak by the selected grouping | table | OK | 60 | `countryindia23052026-07-26 10:55:001671.75637` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — cluster-wide | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 22:16:43.004753346264sonyliv-active-v1` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1298337129090274350.57270` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.29 million13.62 MiB20.3112` |
| 04 Average concurrent viewers by platform | stacked_bar | OK | 1668 | `2026-07-26 00:10:00ANDROID_PHONE0.44` |
| 04 Platform totals | table | OK | 10 | `ANDROID_PHONE1097.9465.6818991` |
| 04 Average concurrent viewers by content type | stacked_bar | OK | 988 | `2026-07-26 00:10:00vod0.44` |
| 04 Content type totals | table | OK | 3 | `vod1412.4984.4924097` |
| 04 Average concurrent viewers by app version | stacked_bar | OK | 5097 | `2026-07-26 00:10:006.28.140.44` |
| 04 App version totals | table | OK | 30 | `6.34.8867.1851.8714907` |
| 04 Average concurrent viewers by category | stacked_bar | OK | 2707 | `2026-07-26 00:10:00other0.44` |
| 04 Category totals | table | OK | 30 | `cdbgg184.2411.024824` |
| 04 Average concurrent viewers by title (top 10, rest folded into 'other') | stacked_bar | OK | 1945 | `2026-07-26 00:10:00other0.44` |
| 04 Title totals | table | OK | 30 | `wekek kedlivecdbgg170.1310.184604` |
| 05 Exact peak concurrency — all dimensions collapsed | number | OK | 1 | `2305` |
| 05 Time-weighted average concurrency — all dimensions collapsed | number | OK | 1 | `147.290321` |
| 05 Viewer-hours — all dimensions collapsed | number | OK | 1 | `1671.75` |
| 05 Rows this answer read — all dimensions collapsed | number | OK | 1 | `637` |
| 05 Exact peak per dimension value in the selected grouping | table | OK | 50 | `totalall23052026-07-26 10:55:00147.2903211671.75` |
| 05 Peak per minute | line | OK | 255642 | `2026-07-26 00:10:00total: all1` |
| 05 Peak per hour | line | OK | 19646 | `2026-07-26 00:00:00category: bgcfm2` |
| 05 Peak and average per day | table | OK | 12357 | `2026-07-26countryindia23052026-07-26 10:55:0069.656157.464` |
| 05 Pipeline evidence — what these answers actually read | table | OK | 0 | `—` |

46 passed, 0 failed.

## gap-no-data — `2026-07-16 00:00:00` .. `2026-07-18 00:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `0` |
| 01 Exact peak in window — all titles | number | OK | 1 | `0` |
| 01 Viewer-hours in window | number | OK | 1 | `0` |
| 01 Live layer lag (seconds) | number | OK | 1 | `7` |
| 01 Average concurrent viewers — responds to the filters above | line | OK | 0 | `—` |
| 01 Exact peak vs average — all titles, NOT filtered | line | OK | 0 | `—` |
| 01 Top titles — average concurrent viewers | line | OK | 0 | `—` |
| 01 Title leaderboard | table | OK | 0 | `—` |
| 02 Time-weighted average concurrency | number | OK | 1 | `0` |
| 02 Viewer-hours | number | OK | 1 | `0` |
| 02 Active intervals started | number | OK | 1 | `0` |
| 02 Average concurrency by platform | line | OK | 0 | `—` |
| 02 Average concurrency by content type | line | OK | 0 | `—` |
| 02 Viewer-hours by category | pie | OK | 0 | `—` |
| 02 Titles by viewer-hours | table | OK | 0 | `—` |
| 02 Exact peak — all dimensions collapsed | number | OK | 1 | `0` |
| 02 Minute layer lag (seconds) | number | OK | 1 | `359` |
| 02 Peak minute in window | table | OK | 0 | `—` |
| 02 Exact peak by the selected grouping | table | OK | 0 | `—` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — cluster-wide | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 22:16:52.004853376285sonyliv-active-v1` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1299510129213573750.56750` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.29 million13.65 MiB20.3132` |
| 04 Average concurrent viewers by platform | stacked_bar | OK | 0 | `—` |
| 04 Platform totals | table | OK | 0 | `—` |
| 04 Average concurrent viewers by content type | stacked_bar | OK | 0 | `—` |
| 04 Content type totals | table | OK | 0 | `—` |
| 04 Average concurrent viewers by app version | stacked_bar | OK | 0 | `—` |
| 04 App version totals | table | OK | 0 | `—` |
| 04 Average concurrent viewers by category | stacked_bar | OK | 0 | `—` |
| 04 Category totals | table | OK | 0 | `—` |
| 04 Average concurrent viewers by title (top 10, rest folded into 'other') | stacked_bar | OK | 0 | `—` |
| 04 Title totals | table | OK | 0 | `—` |
| 05 Exact peak concurrency — all dimensions collapsed | number | OK | 1 | `0` |
| 05 Time-weighted average concurrency — all dimensions collapsed | number | OK | 1 | `0` |
| 05 Viewer-hours — all dimensions collapsed | number | OK | 1 | `0` |
| 05 Rows this answer read — all dimensions collapsed | number | OK | 1 | `0` |
| 05 Exact peak per dimension value in the selected grouping | table | OK | 0 | `—` |
| 05 Peak per minute | line | OK | 0 | `—` |
| 05 Peak per hour | line | OK | 0 | `—` |
| 05 Peak and average per day | table | OK | 0 | `—` |
| 05 Pipeline evidence — what these answers actually read | table | OK | 0 | `—` |

46 passed, 0 failed.

## full-extract — `2026-07-14 00:00:00` .. `2026-07-27 00:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `0` |
| 01 Exact peak in window — all titles | number | OK | 1 | `0` |
| 01 Viewer-hours in window | number | OK | 1 | `0` |
| 01 Live layer lag (seconds) | number | OK | 1 | `4` |
| 01 Average concurrent viewers — responds to the filters above | line | OK | 0 | `—` |
| 01 Exact peak vs average — all titles, NOT filtered | line | OK | 0 | `—` |
| 01 Top titles — average concurrent viewers | line | OK | 0 | `—` |
| 01 Title leaderboard | table | OK | 0 | `—` |
| 02 Time-weighted average concurrency | number | OK | 1 | `6.27036` |
| 02 Viewer-hours | number | OK | 1 | `1779.53` |
| 02 Active intervals started | number | OK | 1 | `31948` |
| 02 Average concurrency by platform | line | OK | 5073 | `2026-07-14 15:43:00IPHONE0.01` |
| 02 Average concurrency by content type | line | OK | 4187 | `2026-07-14 15:43:00vod0.01` |
| 02 Viewer-hours by category | pie | OK | 12 | `cdbgg185.53` |
| 02 Titles by viewer-hours | table | OK | 25 | `wekek kedlivecdbgg170.1346042.2` |
| 02 Exact peak — all dimensions collapsed | number | OK | 1 | `2305` |
| 02 Minute layer lag (seconds) | number | OK | 1 | `367` |
| 02 Peak minute in window | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Exact peak by the selected grouping | table | OK | 60 | `countryindia23052026-07-26 10:55:001779.533662` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — cluster-wide | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 22:17:02.004653402262sonyliv-active-v1` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1300500129312373770.56720` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.29 million13.66 MiB20.3122` |
| 04 Average concurrent viewers by platform | stacked_bar | OK | 5073 | `2026-07-14 15:43:00IPHONE0.01` |
| 04 Platform totals | table | OK | 10 | `ANDROID_PHONE1198.9267.3720134` |
| 04 Average concurrent viewers by content type | stacked_bar | OK | 4187 | `2026-07-14 15:43:00vod0.01` |
| 04 Content type totals | table | OK | 3 | `vod1517.3685.2725304` |
| 04 Average concurrent viewers by app version | stacked_bar | OK | 10065 | `2026-07-14 15:43:008.9.50.01` |
| 04 App version totals | table | OK | 30 | `6.34.8928.4752.1815573` |
| 04 Average concurrent viewers by category | stacked_bar | OK | 6833 | `2026-07-14 15:43:00other0.01` |
| 04 Category totals | table | OK | 30 | `cdbgg185.5310.434831` |
| 04 Average concurrent viewers by title (top 10, rest folded into 'other') | stacked_bar | OK | 5295 | `2026-07-14 15:43:00other0.01` |
| 04 Title totals | table | OK | 30 | `wekek kedlivecdbgg170.139.564604` |
| 05 Exact peak concurrency — all dimensions collapsed | number | OK | 1 | `2305` |
| 05 Time-weighted average concurrency — all dimensions collapsed | number | OK | 1 | `6.27036` |
| 05 Viewer-hours — all dimensions collapsed | number | OK | 1 | `1779.53` |
| 05 Rows this answer read — all dimensions collapsed | number | OK | 1 | `3662` |
| 05 Exact peak per dimension value in the selected grouping | table | OK | 50 | `countryindia23052026-07-26 10:55:006.270361779.53` |
| 05 Peak per minute | line | OK | 308913 | `2026-07-14 15:43:00total: all1` |
| 05 Peak per hour | line | OK | 22484 | `2026-07-14 15:00:00all dimensions: IPHONE  india  vod  bhb` |
| 05 Peak and average per day | table | OK | 13548 | `2026-07-14platform + countryIPHONE  india12026-07-14 15:43` |
| 05 Pipeline evidence — what these answers actually read | table | OK | 0 | `—` |

46 passed, 0 failed.

## live-30m — `2026-08-01 21:46:37` .. `2026-08-01 22:16:37`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `2586` |
| 01 Exact peak in window — all titles | number | OK | 1 | `2806` |
| 01 Viewer-hours in window | number | OK | 1 | `291.32` |
| 01 Live layer lag (seconds) | number | OK | 1 | `5` |
| 01 Average concurrent viewers — responds to the filters above | line | OK | 31 | `2026-08-01 21:46:0066` |
| 01 Exact peak vs average — all titles, NOT filtered | line | OK | 31 | `2026-08-01 21:46:0019866` |
| 01 Top titles — average concurrent viewers | line | OK | 120 | `2026-08-01 21:46:00zupop daj66` |
| 01 Title leaderboard | table | OK | 25 | `nivev jadvodcdbgg2000200070.54` |
| 02 Time-weighted average concurrency | number | OK | 1 | `375.403342` |
| 02 Viewer-hours | number | OK | 1 | `150.16` |
| 02 Active intervals started | number | OK | 1 | `2085` |
| 02 Average concurrency by platform | line | OK | 87 | `2026-08-01 21:47:00ANDROID_PHONE198` |
| 02 Average concurrency by content type | line | OK | 31 | `2026-08-01 21:47:00vod198` |
| 02 Viewer-hours by category | pie | OK | 12 | `djfhp80.41` |
| 02 Titles by viewer-hours | table | OK | 25 | `zupop dajvoddjfhp79.327679.9` |
| 02 Exact peak — all dimensions collapsed | number | OK | 1 | `977` |
| 02 Minute layer lag (seconds) | number | OK | 1 | `377` |
| 02 Peak minute in window | table | OK | 1 | `2026-08-01 22:05:00977942.44` |
| 02 Exact peak by the selected grouping | table | OK | 60 | `countryindia9772026-08-01 22:05:00150.1624` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 31 | `2026-08-01 21:46:000.3150.8130.814` |
| 03 Rows ingested per second, by producer | line | OK | 45 | `2026-08-01 21:46:00api2.4` |
| 03 Read volume per serving query — cluster-wide | table | OK | 30 | `2595868534908427675-- ====================================` |
| 03 Rollup build duration by layer (ms) | line | OK | 35 | `2026-08-01 22:05:00live231` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 31 | `2026-08-01 21:46:00146` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 22:17:13.004653431271sonyliv-active-v1` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1301975129459573800.56680` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.29 million13.70 MiB20.3152` |
| 04 Average concurrent viewers by platform | stacked_bar | OK | 87 | `2026-08-01 21:47:00ANDROID_PHONE198` |
| 04 Platform totals | table | OK | 10 | `ANDROID_PHONE129.1586.011472` |
| 04 Average concurrent viewers by content type | stacked_bar | OK | 31 | `2026-08-01 21:47:00vod198` |
| 04 Content type totals | table | OK | 2 | `vod148.9399.182053` |
| 04 Average concurrent viewers by app version | stacked_bar | OK | 73 | `2026-08-01 21:47:006.34.8198` |
| 04 App version totals | table | OK | 8 | `6.34.8123.7182.381287` |
| 04 Average concurrent viewers by category | stacked_bar | OK | 94 | `2026-08-01 21:47:00djfhp198` |
| 04 Category totals | table | OK | 30 | `djfhp80.4153.5541` |
| 04 Average concurrent viewers by title (top 10, rest folded into 'other') | stacked_bar | OK | 94 | `2026-08-01 21:47:00zupop daj198` |
| 04 Title totals | table | OK | 30 | `zupop dajvoddjfhp79.3252.827` |
| 05 Exact peak concurrency — all dimensions collapsed | number | OK | 1 | `977` |
| 05 Time-weighted average concurrency — all dimensions collapsed | number | OK | 1 | `375.403342` |
| 05 Viewer-hours — all dimensions collapsed | number | OK | 1 | `150.16` |
| 05 Rows this answer read — all dimensions collapsed | number | OK | 1 | `24` |
| 05 Exact peak per dimension value in the selected grouping | table | OK | 50 | `countryindia9772026-08-01 22:05:00375.403342150.16` |
| 05 Peak per minute | line | OK | 14528 | `2026-08-01 21:47:00platform: ANDROID_PHONE198` |
| 05 Peak per hour | line | OK | 2412 | `2026-08-01 21:00:00platform: ANDROID_PHONE198` |
| 05 Peak and average per day | table | OK | 2399 | `2026-08-01totalall9772026-08-01 22:05:006.2567375.40324` |
| 05 Pipeline evidence — what these answers actually read | table | OK | 20 | `dbc4d780-d48d-4dcf-9acd-bb83ed22af5d5545575551425257160128` |

46 passed, 0 failed.

## live-6h — `2026-08-01 16:16:37` .. `2026-08-01 22:16:37`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `2586` |
| 01 Exact peak in window — all titles | number | OK | 1 | `2806` |
| 01 Viewer-hours in window | number | OK | 1 | `1285.16` |
| 01 Live layer lag (seconds) | number | OK | 1 | `13` |
| 01 Average concurrent viewers — responds to the filters above | line | OK | 149 | `2026-08-01 19:48:00157.62` |
| 01 Exact peak vs average — all titles, NOT filtered | line | OK | 149 | `2026-08-01 19:48:00328157.62` |
| 01 Top titles — average concurrent viewers | line | OK | 792 | `2026-08-01 19:49:00cegeg gef0.57` |
| 01 Title leaderboard | table | OK | 25 | `nivev jadvodcdbgg2000200097.18` |
| 02 Time-weighted average concurrency | number | OK | 1 | `213.058409` |
| 02 Viewer-hours | number | OK | 1 | `1154.07` |
| 02 Active intervals started | number | OK | 1 | `18603` |
| 02 Average concurrency by platform | line | OK | 1162 | `2026-08-01 16:46:00ANDROID_PHONE0.4` |
| 02 Average concurrency by content type | line | OK | 186 | `2026-08-01 16:46:00vod0.4` |
| 02 Viewer-hours by category | pie | OK | 12 | `djfhp172.69` |
| 02 Titles by viewer-hours | table | OK | 25 | `zupop dajvoddjfhp170.8720849.3` |
| 02 Exact peak — all dimensions collapsed | number | OK | 1 | `1161` |
| 02 Minute layer lag (seconds) | number | OK | 1 | `385` |
| 02 Peak minute in window | table | OK | 1 | `2026-08-01 19:53:0011611000.83` |
| 02 Exact peak by the selected grouping | table | OK | 60 | `countryindia11612026-08-01 19:53:001154.07163` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 157 | `2026-08-01 16:46:00-1.620.180.34` |
| 03 Rows ingested per second, by producer | line | OK | 189 | `2026-08-01 16:22:00csv:ch-hackathon-raw-data.csv15092.6` |
| 03 Read volume per serving query — cluster-wide | table | OK | 30 | `2595868534908427675-- ====================================` |
| 03 Rollup build duration by layer (ms) | line | OK | 343 | `2026-08-01 19:45:00live177` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 158 | `2026-08-01 16:22:0010866` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 22:17:23.004453462277sonyliv-active-v1` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1302939129555573840.56670` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.30 million13.72 MiB20.3152` |
| 04 Average concurrent viewers by platform | stacked_bar | OK | 1162 | `2026-08-01 16:46:00ANDROID_PHONE0.4` |
| 04 Platform totals | table | OK | 12 | `ANDROID_PHONE847.873.4612894` |
| 04 Average concurrent viewers by content type | stacked_bar | OK | 186 | `2026-08-01 16:46:00vod0.4` |
| 04 Content type totals | table | OK | 3 | `vod1151.2399.7518521` |
| 04 Average concurrent viewers by app version | stacked_bar | OK | 968 | `2026-08-01 16:46:000.4` |
| 04 App version totals | table | OK | 10 | `6.34.8787.7568.2611622` |
| 04 Average concurrent viewers by category | stacked_bar | OK | 1152 | `2026-08-01 16:46:00other0.4` |
| 04 Category totals | table | OK | 30 | `djfhp172.6914.96263` |
| 04 Average concurrent viewers by title (top 10, rest folded into 'other') | stacked_bar | OK | 1100 | `2026-08-01 16:46:00other0.4` |
| 04 Title totals | table | OK | 30 | `zupop dajvoddjfhp170.8714.81208` |
| 05 Exact peak concurrency — all dimensions collapsed | number | OK | 1 | `1161` |
| 05 Time-weighted average concurrency — all dimensions collapsed | number | OK | 1 | `213.058409` |
| 05 Viewer-hours — all dimensions collapsed | number | OK | 1 | `1154.07` |
| 05 Rows this answer read — all dimensions collapsed | number | OK | 1 | `163` |
| 05 Exact peak per dimension value in the selected grouping | table | OK | 50 | `totalall11612026-08-01 19:53:00213.0584091154.07` |
| 05 Peak per minute | line | OK | 101826 | `2026-08-01 16:46:00total: all1` |
| 05 Peak per hour | line | OK | 11116 | `2026-08-01 16:00:00platform + content: JIO_ANDROID_TV  vub` |
| 05 Peak and average per day | table | OK | 7751 | `2026-08-01totalall11612026-08-01 19:53:0048.0861424.81163` |
| 05 Pipeline evidence — what these answers actually read | table | OK | 20 | `9b89186c-9a54-4e71-be5a-f047995cfbc11836906734307236954154` |

46 passed, 0 failed.

---

**Total: 276 passed, 0 failed.**
