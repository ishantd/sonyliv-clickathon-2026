# ClickStack tile verification

Database `sonyliv_prod`, granularity 60s, generated 2026-08-01 20:49:32Z.

## hot-hour — `2026-07-26 10:00:00` .. `2026-07-26 11:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `0` |
| 01 Exact peak in window — all titles | number | OK | 1 | `0` |
| 01 Viewer-hours in window | number | OK | 1 | `0` |
| 01 Live layer lag (seconds) | number | OK | 1 | `3` |
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
| 02 Minute layer lag (seconds) | number | OK | 1 | `394` |
| 02 Peak minute in window | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Exact peak by platform | bar | OK | 10 | `ANDROID_PHONE1461` |
| 02 Exact peak by app version | table | OK | 25 | `6.34.81178444.21` |
| 02 Exact peak by category | table | OK | 25 | `cdbgg358128.71` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — cluster-wide | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 20:49:07.9882943301260sonyliv-active-v` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1114441110785665850.59090` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.11 million9.44 MiB25.1152` |
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
| 01 Live layer lag (seconds) | number | OK | 1 | `9` |
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
| 02 Minute layer lag (seconds) | number | OK | 1 | `400` |
| 02 Peak minute in window | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Exact peak by platform | bar | OK | 10 | `ANDROID_PHONE1461` |
| 02 Exact peak by app version | table | OK | 25 | `6.34.81178867.18` |
| 02 Exact peak by category | table | OK | 25 | `cdbgg358184.24` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — cluster-wide | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 20:49:17.9992543325251sonyliv-active-v` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1114757110817265850.59070` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.11 million9.42 MiB25.2112` |
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
| 01 Live layer lag (seconds) | number | OK | 1 | `4` |
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
| 02 Minute layer lag (seconds) | number | OK | 1 | `406` |
| 02 Peak minute in window | table | OK | 0 | `—` |
| 02 Exact peak by platform | bar | OK | 0 | `—` |
| 02 Exact peak by app version | table | OK | 0 | `—` |
| 02 Exact peak by category | table | OK | 0 | `—` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — cluster-wide | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 20:49:17.9993043325251sonyliv-active-v` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1115102110851465880.59080` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.11 million9.44 MiB25.1142` |
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
| 01 Live layer lag (seconds) | number | OK | 1 | `10` |
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
| 02 Minute layer lag (seconds) | number | OK | 1 | `412` |
| 02 Peak minute in window | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Exact peak by platform | bar | OK | 10 | `ANDROID_PHONE1461` |
| 02 Exact peak by app version | table | OK | 25 | `6.34.81178928.47` |
| 02 Exact peak by category | table | OK | 25 | `cdbgg358185.53` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — cluster-wide | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 20:49:27.9962643353250sonyliv-active-v` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1115448110885765910.59090` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.11 million9.44 MiB25.1132` |
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

## live-30m — `2026-08-01 20:19:32` .. `2026-08-01 20:49:32`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `560` |
| 01 Exact peak in window — all titles | number | OK | 1 | `600` |
| 01 Viewer-hours in window | number | OK | 1 | `285.53` |
| 01 Live layer lag (seconds) | number | OK | 1 | `6` |
| 01 Concurrent viewers — exact peak vs time-weighted average | line | OK | 31 | `2026-08-01 20:19:00579191.46` |
| 01 Top titles — average concurrent viewers | line | OK | 248 | `2026-08-01 20:19:00tifif feh7.54` |
| 01 Title leaderboard | table | OK | 25 | `necec cegvodcgdgn39169.48` |
| 02 Time-weighted average concurrency | number | OK | 1 | `568.734559` |
| 02 Viewer-hours | number | OK | 1 | `218.01` |
| 02 Active intervals started | number | OK | 1 | `3502` |
| 02 Average concurrency by platform | line | OK | 230 | `2026-08-01 20:20:00XIAOMI_ANDROID_TV2` |
| 02 Average concurrency by content type | line | OK | 23 | `2026-08-01 20:20:00vod569.07` |
| 02 Viewer-hours by category | pie | OK | 12 | `chbgg17.83` |
| 02 Titles by viewer-hours | table | OK | 25 | `tifif fehvoddhddd9.611344.3` |
| 02 Exact peak — all dimensions collapsed | number | OK | 1 | `600` |
| 02 Minute layer lag (seconds) | number | OK | 1 | `418` |
| 02 Peak minute in window | table | OK | 1 | `2026-08-01 20:38:00600589.46` |
| 02 Exact peak by platform | bar | OK | 10 | `ANDROID_PHONE422` |
| 02 Exact peak by app version | table | OK | 8 | `6.34.8389138.14` |
| 02 Exact peak by category | table | OK | 25 | `chbgg5817.83` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 31 | `2026-08-01 20:19:0021.9833.47983.33` |
| 03 Rows ingested per second, by producer | line | OK | 38 | `2026-08-01 20:19:00generator25.3` |
| 03 Read volume per serving query — cluster-wide | table | OK | 30 | `17704518813321872408-- ===================================` |
| 03 Rollup build duration by layer (ms) | line | OK | 77 | `2026-08-01 20:19:00intervals271` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 31 | `2026-08-01 20:19:00578` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 20:49:27.9963243353250sonyliv-active-v` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1115767110917565920.59080` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.11 million9.45 MiB25.1142` |
| 04 Average concurrent viewers by platform | stacked_bar | OK | 230 | `2026-08-01 20:20:00XIAOMI_ANDROID_TV2` |
| 04 Platform totals | table | OK | 10 | `ANDROID_PHONE150.5469.052402` |
| 04 Average concurrent viewers by content type | stacked_bar | OK | 23 | `2026-08-01 20:20:00vod569.07` |
| 04 Content type totals | table | OK | 1 | `vod218.011003502` |
| 04 Average concurrent viewers by app version | stacked_bar | OK | 184 | `2026-08-01 20:20:002.14.09.04` |
| 04 App version totals | table | OK | 8 | `6.34.8138.1463.362234` |
| 04 Average concurrent viewers by category | stacked_bar | OK | 253 | `2026-08-01 20:20:00cfccc19.99` |
| 04 Category totals | table | OK | 27 | `chbgg17.838.18278` |
| 04 Average concurrent viewers by title (top 10, rest folded into 'other') | stacked_bar | OK | 253 | `2026-08-01 20:20:00wofif fih24.85` |
| 04 Title totals | table | OK | 30 | `tifif fehvoddhddd9.614.41134` |

38 passed, 0 failed.

## live-6h — `2026-08-01 14:49:32` .. `2026-08-01 20:49:32`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `559` |
| 01 Exact peak in window — all titles | number | OK | 1 | `1161` |
| 01 Viewer-hours in window | number | OK | 1 | `593.74` |
| 01 Live layer lag (seconds) | number | OK | 1 | `2` |
| 01 Concurrent viewers — exact peak vs time-weighted average | line | OK | 62 | `2026-08-01 19:48:00328157.62` |
| 01 Top titles — average concurrent viewers | line | OK | 464 | `2026-08-01 19:52:00taziz lic11.06` |
| 01 Title leaderboard | table | OK | 25 | `necec cegvodcgdgn391719.68` |
| 02 Time-weighted average concurrency | number | OK | 1 | `136.441983` |
| 02 Viewer-hours | number | OK | 1 | `538.95` |
| 02 Active intervals started | number | OK | 1 | `10431` |
| 02 Average concurrency by platform | line | OK | 633 | `2026-08-01 16:46:00ANDROID_PHONE0.4` |
| 02 Average concurrency by content type | line | OK | 91 | `2026-08-01 16:46:00vod0.4` |
| 02 Viewer-hours by category | pie | OK | 12 | `chbgg39.41` |
| 02 Titles by viewer-hours | table | OK | 25 | `wofif fihvodchbgg21.953633.6` |
| 02 Exact peak — all dimensions collapsed | number | OK | 1 | `1161` |
| 02 Minute layer lag (seconds) | number | OK | 1 | `424` |
| 02 Peak minute in window | table | OK | 1 | `2026-08-01 19:53:0011611000.83` |
| 02 Exact peak by platform | bar | OK | 10 | `ANDROID_PHONE807` |
| 02 Exact peak by app version | table | OK | 9 | `6.34.8718338.07` |
| 02 Exact peak by category | table | OK | 25 | `chbgg6539.41` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 70 | `2026-08-01 16:46:00-1.620.180.34` |
| 03 Rows ingested per second, by producer | line | OK | 79 | `2026-08-01 16:22:00csv:ch-hackathon-raw-data.csv15092.6` |
| 03 Read volume per serving query — cluster-wide | table | OK | 30 | `17970580568159697991-- ===================================` |
| 03 Rollup build duration by layer (ms) | line | OK | 143 | `2026-08-01 19:45:00live177` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 71 | `2026-08-01 16:22:0010866` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 20:49:37.9802843376246sonyliv-active-v` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1116107110951465930.59070` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.11 million9.45 MiB25.1142` |
| 04 Average concurrent viewers by platform | stacked_bar | OK | 633 | `2026-08-01 16:46:00ANDROID_PHONE0.4` |
| 04 Platform totals | table | OK | 10 | `ANDROID_PHONE373.1369.237164` |
| 04 Average concurrent viewers by content type | stacked_bar | OK | 91 | `2026-08-01 16:46:00vod0.4` |
| 04 Content type totals | table | OK | 3 | `vod537.3499.710381` |
| 04 Average concurrent viewers by app version | stacked_bar | OK | 540 | `2026-08-01 16:46:000.4` |
| 04 App version totals | table | OK | 9 | `6.34.8338.0762.736515` |
| 04 Average concurrent viewers by category | stacked_bar | OK | 698 | `2026-08-01 16:46:00other0.4` |
| 04 Category totals | table | OK | 30 | `chbgg39.417.31716` |
| 04 Average concurrent viewers by title (top 10, rest folded into 'other') | stacked_bar | OK | 632 | `2026-08-01 16:46:00other0.4` |
| 04 Title totals | table | OK | 30 | `wofif fihvodchbgg21.954.07363` |

38 passed, 0 failed.

---

**Total: 228 passed, 0 failed.**
