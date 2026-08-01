# ClickStack tile verification

Database `sonyliv_prod`, granularity 60s, generated 2026-08-01 20:41:55Z.

## hot-hour — `2026-07-26 10:00:00` .. `2026-07-26 11:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `0` |
| 01 Exact peak in window — all titles | number | OK | 1 | `0` |
| 01 Viewer-hours in window | number | OK | 1 | `0` |
| 01 Live layer lag (seconds) | number | OK | 1 | `6` |
| 01 Concurrent viewers — exact peak vs time-weighted average | line | OK | 0 | `—` |
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
| 02 Minute layer lag (seconds) | number | OK | 1 | `417` |
| 02 Peak minute in window | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Exact peak by platform | bar | OK | 10 | `ANDROID_PHONE1461` |
| 02 Exact peak by app version | table | OK | 25 | `6.34.81178444.21` |
| 02 Exact peak by category | table | OK | 25 | `cdbgg358128.71` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — this replica | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 20:41:49.4931042129245sonyliv-active-v` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1087874108143864360.59160` |
| 03 Storage and compression — this replica | table | OK | 10 | `events_clean1.08 million9.03 MiB25.610` |
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

38 passed, 0 failed.

## hot-day — `2026-07-26 00:00:00` .. `2026-07-27 00:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `0` |
| 01 Exact peak in window — all titles | number | OK | 1 | `0` |
| 01 Viewer-hours in window | number | OK | 1 | `0` |
| 01 Live layer lag (seconds) | number | OK | 1 | `1` |
| 01 Concurrent viewers — exact peak vs time-weighted average | line | OK | 0 | `—` |
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
| 02 Minute layer lag (seconds) | number | OK | 1 | `423` |
| 02 Peak minute in window | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Exact peak by platform | bar | OK | 10 | `ANDROID_PHONE1461` |
| 02 Exact peak by app version | table | OK | 25 | `6.34.81178867.18` |
| 02 Exact peak by category | table | OK | 25 | `cdbgg358184.24` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — this replica | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 20:41:59.493642148264sonyliv-active-v1` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1088221108178564360.59140` |
| 03 Storage and compression — this replica | table | OK | 10 | `events_clean1.08 million9.05 MiB25.614` |
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

38 passed, 0 failed.

## gap-no-data — `2026-07-16 00:00:00` .. `2026-07-18 00:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `0` |
| 01 Exact peak in window — all titles | number | OK | 1 | `0` |
| 01 Viewer-hours in window | number | OK | 1 | `0` |
| 01 Live layer lag (seconds) | number | OK | 1 | `8` |
| 01 Concurrent viewers — exact peak vs time-weighted average | line | OK | 0 | `—` |
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
| 02 Minute layer lag (seconds) | number | OK | 1 | `429` |
| 02 Peak minute in window | table | OK | 0 | `—` |
| 02 Exact peak by platform | bar | OK | 0 | `—` |
| 02 Exact peak by app version | table | OK | 0 | `—` |
| 02 Exact peak by category | table | OK | 0 | `—` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — this replica | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 20:42:09.493242173251sonyliv-active-v1` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1088572108213664360.59120` |
| 03 Storage and compression — this replica | table | OK | 10 | `events_clean1.08 million9.06 MiB25.615` |
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

38 passed, 0 failed.

## full-extract — `2026-07-14 00:00:00` .. `2026-07-27 00:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `0` |
| 01 Exact peak in window — all titles | number | OK | 1 | `0` |
| 01 Viewer-hours in window | number | OK | 1 | `0` |
| 01 Live layer lag (seconds) | number | OK | 1 | `3` |
| 01 Concurrent viewers — exact peak vs time-weighted average | line | OK | 0 | `—` |
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
| 02 Minute layer lag (seconds) | number | OK | 1 | `435` |
| 02 Peak minute in window | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Exact peak by platform | bar | OK | 10 | `ANDROID_PHONE1461` |
| 02 Exact peak by app version | table | OK | 25 | `6.34.81178928.47` |
| 02 Exact peak by category | table | OK | 25 | `cdbgg358185.53` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — this replica | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 20:42:09.493742173251sonyliv-active-v1` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1088890108245164390.59130` |
| 03 Storage and compression — this replica | table | OK | 10 | `events_clean1.08 million9.05 MiB25.611` |
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

38 passed, 0 failed.

## live-30m — `2026-08-01 20:11:55` .. `2026-08-01 20:41:55`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `559` |
| 01 Exact peak in window — all titles | number | OK | 1 | `600` |
| 01 Viewer-hours in window | number | OK | 1 | `282.09` |
| 01 Live layer lag (seconds) | number | OK | 1 | `10` |
| 01 Concurrent viewers — exact peak vs time-weighted average | line | OK | 30 | `2026-08-01 20:12:00564557.12` |
| 01 Top titles — average concurrent viewers | line | OK | 240 | `2026-08-01 20:12:00wofif fih30.39` |
| 01 Title leaderboard | table | OK | 25 | `necec cegvodcgdgn35328.17` |
| 02 Time-weighted average concurrency | number | OK | 1 | `560.826078` |
| 02 Viewer-hours | number | OK | 1 | `214.98` |
| 02 Active intervals started | number | OK | 1 | `3414` |
| 02 Average concurrency by platform | line | OK | 230 | `2026-08-01 20:12:00LG_HTML_TV5.97` |
| 02 Average concurrency by content type | line | OK | 23 | `2026-08-01 20:12:00vod557.12` |
| 02 Viewer-hours by category | pie | OK | 12 | `chbgg17.57` |
| 02 Titles by viewer-hours | table | OK | 25 | `wofif fihvodchbgg9.941414.2` |
| 02 Exact peak — all dimensions collapsed | number | OK | 1 | `586` |
| 02 Minute layer lag (seconds) | number | OK | 1 | `441` |
| 02 Peak minute in window | table | OK | 1 | `2026-08-01 20:22:00586575.44` |
| 02 Exact peak by platform | bar | OK | 10 | `ANDROID_PHONE422` |
| 02 Exact peak by app version | table | OK | 8 | `6.34.8387136.51` |
| 02 Exact peak by category | table | OK | 25 | `chbgg5717.57` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 31 | `2026-08-01 20:11:0021.97229.06286.275` |
| 03 Rows ingested per second, by producer | line | OK | 32 | `2026-08-01 20:11:00generator4.2` |
| 03 Read volume per serving query — this replica | table | OK | 30 | `17704518813321872408-- ===================================` |
| 03 Rollup build duration by layer (ms) | line | OK | 70 | `2026-08-01 20:11:00live249` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 31 | `2026-08-01 20:11:00124` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 20:42:19.243342198252sonyliv-active-v1` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1089273108283464390.59110` |
| 03 Storage and compression — this replica | table | OK | 10 | `events_clean1.08 million9.06 MiB25.612` |
| 04 Average concurrent viewers by platform | stacked_bar | OK | 230 | `2026-08-01 20:12:00LG_HTML_TV5.97` |
| 04 Platform totals | table | OK | 10 | `ANDROID_PHONE147.9268.812329` |
| 04 Average concurrent viewers by content type | stacked_bar | OK | 23 | `2026-08-01 20:12:00vod557.12` |
| 04 Content type totals | table | OK | 1 | `vod214.981003414` |
| 04 Average concurrent viewers by app version | stacked_bar | OK | 184 | `2026-08-01 20:12:006.25.141.65` |
| 04 App version totals | table | OK | 8 | `6.34.8136.5163.52159` |
| 04 Average concurrent viewers by category | stacked_bar | OK | 253 | `2026-08-01 20:12:00bgbbb29.2` |
| 04 Category totals | table | OK | 27 | `chbgg17.578.17254` |
| 04 Average concurrent viewers by title (top 10, rest folded into 'other') | stacked_bar | OK | 253 | `2026-08-01 20:12:00nogeg gid18.64` |
| 04 Title totals | table | OK | 30 | `wofif fihvodchbgg9.944.62141` |

38 passed, 0 failed.

## live-6h — `2026-08-01 14:41:55` .. `2026-08-01 20:41:55`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `566` |
| 01 Exact peak in window — all titles | number | OK | 1 | `1161` |
| 01 Viewer-hours in window | number | OK | 1 | `519.82` |
| 01 Live layer lag (seconds) | number | OK | 1 | `5` |
| 01 Concurrent viewers — exact peak vs time-weighted average | line | OK | 54 | `2026-08-01 19:48:00328157.62` |
| 01 Top titles — average concurrent viewers | line | OK | 400 | `2026-08-01 19:52:00taziz lic11.06` |
| 01 Title leaderboard | table | OK | 25 | `vosus gajvodbjfff371314.98` |
| 02 Time-weighted average concurrency | number | OK | 1 | `121.103558` |
| 02 Viewer-hours | number | OK | 1 | `462.21` |
| 02 Active intervals started | number | OK | 1 | `9170` |
| 02 Average concurrency by platform | line | OK | 553 | `2026-08-01 16:46:00ANDROID_PHONE0.4` |
| 02 Average concurrency by content type | line | OK | 83 | `2026-08-01 16:46:00vod0.4` |
| 02 Viewer-hours by category | pie | OK | 12 | `chbgg33.14` |
| 02 Titles by viewer-hours | table | OK | 25 | `wofif fihvodchbgg18.663143.6` |
| 02 Exact peak — all dimensions collapsed | number | OK | 1 | `1161` |
| 02 Minute layer lag (seconds) | number | OK | 1 | `592946` |
| 02 Peak minute in window | table | OK | 1 | `2026-08-01 19:53:0011611000.83` |
| 02 Exact peak by platform | bar | OK | 10 | `ANDROID_PHONE807` |
| 02 Exact peak by app version | table | OK | 9 | `6.34.8718289.02` |
| 02 Exact peak by category | table | OK | 25 | `chbgg6533.14` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 62 | `2026-08-01 16:46:00-1.620.180.34` |
| 03 Rows ingested per second, by producer | line | OK | 65 | `2026-08-01 16:22:00csv:ch-hackathon-raw-data.csv15092.6` |
| 03 Read volume per serving query — this replica | table | OK | 30 | `17704518813321872408-- ===================================` |
| 03 Rollup build duration by layer (ms) | line | OK | 120 | `2026-08-01 19:45:00live177` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 63 | `2026-08-01 16:22:0010866` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 20:42:19.243942198252sonyliv-active-v1` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1089593108315264410.59110` |
| 03 Storage and compression — this replica | table | OK | 10 | `events_clean1.08 million9.07 MiB25.513` |
| 04 Average concurrent viewers by platform | stacked_bar | OK | 573 | `2026-08-01 16:46:00ANDROID_PHONE0.4` |
| 04 Platform totals | table | OK | 10 | `ANDROID_PHONE333.7969.326519` |
| 04 Average concurrent viewers by content type | stacked_bar | OK | 85 | `2026-08-01 16:46:00vod0.4` |
| 04 Content type totals | table | OK | 3 | `vod479.9599.679439` |
| 04 Average concurrent viewers by app version | stacked_bar | OK | 492 | `2026-08-01 16:46:000.4` |
| 04 App version totals | table | OK | 9 | `6.34.8301.2262.555884` |
| 04 Average concurrent viewers by category | stacked_bar | OK | 619 | `2026-08-01 16:46:00other0.4` |
| 04 Category totals | table | OK | 30 | `chbgg34.887.24636` |
| 04 Average concurrent viewers by title (top 10, rest folded into 'other') | stacked_bar | OK | 566 | `2026-08-01 16:46:00other0.4` |
| 04 Title totals | table | OK | 30 | `wofif fihvodchbgg19.54.05326` |

38 passed, 0 failed.

---

**Total: 228 passed, 0 failed.**
