# ClickStack tile verification

Database `sonyliv_prod`, granularity 60s, generated 2026-08-01 21:54:15Z.

## hot-hour — `2026-07-26 10:00:00` .. `2026-07-26 11:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `0` |
| 01 Exact peak in window — all titles | number | OK | 1 | `0` |
| 01 Viewer-hours in window | number | OK | 1 | `0` |
| 01 Live layer lag (seconds) | number | OK | 1 | `516` |
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
| 02 Minute layer lag (seconds) | number | OK | 1 | `857` |
| 02 Peak minute in window | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Exact peak by platform | bar | OK | 10 | `ANDROID_PHONE1461` |
| 02 Exact peak by app version | table | OK | 25 | `6.34.81178444.21` |
| 02 Exact peak by category | table | OK | 25 | `cdbgg358128.71` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — cluster-wide | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 21:45:39.91652048466298sonyliv-active-` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1234659122752571340.57780` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.23 million12.00 MiB21.9142` |
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
| 05 Exact peak concurrency in window | number | OK | 1 | `2305` |
| 05 Time-weighted average concurrency in window | number | OK | 1 | `855.603469` |
| 05 Minutes covered by the answer | number | OK | 1 | `60` |
| 05 Benchmark answer set — exact peak and average per grouping, with the minute each peaked | table | OK | 13 | `(ungrouped)023052026-07-26 10:55:00855.60346960` |
| 05 Peak and average per minute | line | OK | 60 | `2026-07-26 10:00:005048.042` |
| 05 Peak and average per hour | line | OK | 1 | `2026-07-26 10:00:002305855.603` |
| 05 Peak and average per day | table | OK | 1 | `2026-07-2623052026-07-26 10:55:0035.6501855.60360` |
| 05 Pipeline evidence — what these answers actually read | table | OK | 0 | `—` |

46 passed, 0 failed.

## hot-day — `2026-07-26 00:00:00` .. `2026-07-27 00:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `0` |
| 01 Exact peak in window — all titles | number | OK | 1 | `0` |
| 01 Viewer-hours in window | number | OK | 1 | `0` |
| 01 Live layer lag (seconds) | number | OK | 1 | `523` |
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
| 02 Minute layer lag (seconds) | number | OK | 1 | `865` |
| 02 Peak minute in window | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Exact peak by platform | bar | OK | 10 | `ANDROID_PHONE1461` |
| 02 Exact peak by app version | table | OK | 25 | `6.34.81178867.18` |
| 02 Exact peak by category | table | OK | 25 | `cdbgg358184.24` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — cluster-wide | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 21:45:39.91652748466298sonyliv-active-` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1234703122756971340.57780` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.23 million12.00 MiB21.9142` |
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
| 05 Exact peak concurrency in window | number | OK | 1 | `2305` |
| 05 Time-weighted average concurrency in window | number | OK | 1 | `147.290321` |
| 05 Minutes covered by the answer | number | OK | 1 | `637` |
| 05 Benchmark answer set — exact peak and average per grouping, with the minute each peaked | table | OK | 13 | `(ungrouped)023052026-07-26 10:55:00147.290321637` |
| 05 Peak and average per minute | line | OK | 637 | `2026-07-26 00:10:0010.445` |
| 05 Peak and average per hour | line | OK | 12 | `2026-07-26 00:00:0031.472` |
| 05 Peak and average per day | table | OK | 1 | `2026-07-2623052026-07-26 10:55:0069.656157.464637` |
| 05 Pipeline evidence — what these answers actually read | table | OK | 0 | `—` |

46 passed, 0 failed.

## gap-no-data — `2026-07-16 00:00:00` .. `2026-07-18 00:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `0` |
| 01 Exact peak in window — all titles | number | OK | 1 | `0` |
| 01 Viewer-hours in window | number | OK | 1 | `0` |
| 01 Live layer lag (seconds) | number | OK | 1 | `530` |
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
| 02 Minute layer lag (seconds) | number | OK | 1 | `872` |
| 02 Peak minute in window | table | OK | 0 | `—` |
| 02 Exact peak by platform | bar | OK | 0 | `—` |
| 02 Exact peak by app version | table | OK | 0 | `—` |
| 02 Exact peak by category | table | OK | 0 | `—` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — cluster-wide | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 21:45:39.91653448466298sonyliv-active-` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1234755122762171340.57780` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.23 million12.00 MiB21.9142` |
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
| 05 Exact peak concurrency in window | number | OK | 1 | `0` |
| 05 Time-weighted average concurrency in window | number | OK | 1 | `0` |
| 05 Minutes covered by the answer | number | OK | 1 | `0` |
| 05 Benchmark answer set — exact peak and average per grouping, with the minute each peaked | table | OK | 0 | `—` |
| 05 Peak and average per minute | line | OK | 0 | `—` |
| 05 Peak and average per hour | line | OK | 0 | `—` |
| 05 Peak and average per day | table | OK | 0 | `—` |
| 05 Pipeline evidence — what these answers actually read | table | OK | 0 | `—` |

46 passed, 0 failed.

## full-extract — `2026-07-14 00:00:00` .. `2026-07-27 00:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `0` |
| 01 Exact peak in window — all titles | number | OK | 1 | `0` |
| 01 Viewer-hours in window | number | OK | 1 | `0` |
| 01 Live layer lag (seconds) | number | OK | 1 | `537` |
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
| 02 Minute layer lag (seconds) | number | OK | 1 | `878` |
| 02 Peak minute in window | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Exact peak by platform | bar | OK | 10 | `ANDROID_PHONE1461` |
| 02 Exact peak by app version | table | OK | 25 | `6.34.81178928.47` |
| 02 Exact peak by category | table | OK | 25 | `cdbgg358185.53` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — cluster-wide | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 21:45:39.91654148466298sonyliv-active-` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1234795122766171340.57770` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.23 million12.00 MiB21.9142` |
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
| 05 Exact peak concurrency in window | number | OK | 1 | `2305` |
| 05 Time-weighted average concurrency in window | number | OK | 1 | `6.27036` |
| 05 Minutes covered by the answer | number | OK | 1 | `3662` |
| 05 Benchmark answer set — exact peak and average per grouping, with the minute each peaked | table | OK | 13 | `(ungrouped)023052026-07-26 10:55:006.270363662` |
| 05 Peak and average per minute | line | OK | 3662 | `2026-07-14 15:43:0010.014` |
| 05 Peak and average per hour | line | OK | 97 | `2026-07-14 15:00:0010.156` |
| 05 Peak and average per day | table | OK | 7 | `2026-07-1412026-07-14 15:43:000.0130.71926` |
| 05 Pipeline evidence — what these answers actually read | table | OK | 0 | `—` |

46 passed, 0 failed.

## live-30m — `2026-08-01 21:24:15` .. `2026-08-01 21:54:15`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `198` |
| 01 Exact peak in window — all titles | number | OK | 1 | `198` |
| 01 Viewer-hours in window | number | OK | 1 | `70.4` |
| 01 Live layer lag (seconds) | number | OK | 1 | `544` |
| 01 Concurrent viewers — exact peak vs time-weighted average | line | OK | 22 | `2026-08-01 21:24:00198132` |
| 01 Top titles — average concurrent viewers | line | OK | 22 | `2026-08-01 21:24:00zupop daj132` |
| 01 Title leaderboard | table | OK | 1 | `zupop dajvoddjfhp19819870.4` |
| 02 Time-weighted average concurrency | number | OK | 1 | `197.996666` |
| 02 Viewer-hours | number | OK | 1 | `49.5` |
| 02 Active intervals started | number | OK | 1 | `1` |
| 02 Average concurrency by platform | line | OK | 15 | `2026-08-01 21:25:00ANDROID_PHONE198` |
| 02 Average concurrency by content type | line | OK | 15 | `2026-08-01 21:25:00vod198` |
| 02 Viewer-hours by category | pie | OK | 1 | `djfhp49.5` |
| 02 Titles by viewer-hours | table | OK | 1 | `zupop dajvoddjfhp49.512969.9` |
| 02 Exact peak — all dimensions collapsed | number | OK | 1 | `198` |
| 02 Minute layer lag (seconds) | number | OK | 1 | `886` |
| 02 Peak minute in window | table | OK | 1 | `2026-08-01 21:25:00198198` |
| 02 Exact peak by platform | bar | OK | 1 | `ANDROID_PHONE198` |
| 02 Exact peak by app version | table | OK | 1 | `6.34.819849.5` |
| 02 Exact peak by category | table | OK | 1 | `djfhp19849.5` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 31 | `2026-08-01 21:24:000.5560.8140.815` |
| 03 Rows ingested per second, by producer | line | OK | 31 | `2026-08-01 21:24:00api5` |
| 03 Read volume per serving query — cluster-wide | table | OK | 30 | `2595868534908427675-- ====================================` |
| 03 Rollup build duration by layer (ms) | line | OK | 67 | `2026-08-01 21:24:00minute1342` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 31 | `2026-08-01 21:24:00200` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 21:45:39.91654848466298sonyliv-active-` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1234847122771371340.57770` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.23 million12.01 MiB21.9142` |
| 04 Average concurrent viewers by platform | stacked_bar | OK | 15 | `2026-08-01 21:25:00ANDROID_PHONE198` |
| 04 Platform totals | table | OK | 1 | `ANDROID_PHONE49.51001` |
| 04 Average concurrent viewers by content type | stacked_bar | OK | 15 | `2026-08-01 21:25:00vod198` |
| 04 Content type totals | table | OK | 1 | `vod49.51001` |
| 04 Average concurrent viewers by app version | stacked_bar | OK | 15 | `2026-08-01 21:25:006.34.8198` |
| 04 App version totals | table | OK | 1 | `6.34.849.51001` |
| 04 Average concurrent viewers by category | stacked_bar | OK | 15 | `2026-08-01 21:25:00djfhp198` |
| 04 Category totals | table | OK | 1 | `djfhp49.51001` |
| 04 Average concurrent viewers by title (top 10, rest folded into 'other') | stacked_bar | OK | 15 | `2026-08-01 21:25:00zupop daj198` |
| 04 Title totals | table | OK | 1 | `zupop dajvoddjfhp49.51001` |
| 05 Exact peak concurrency in window | number | OK | 1 | `198` |
| 05 Time-weighted average concurrency in window | number | OK | 1 | `197.996666` |
| 05 Minutes covered by the answer | number | OK | 1 | `15` |
| 05 Benchmark answer set — exact peak and average per grouping, with the minute each peaked | table | OK | 13 | `(ungrouped)01982026-08-01 21:25:00197.99666615` |
| 05 Peak and average per minute | line | OK | 15 | `2026-08-01 21:25:00198198` |
| 05 Peak and average per hour | line | OK | 1 | `2026-08-01 21:00:0019849.499` |
| 05 Peak and average per day | table | OK | 1 | `2026-08-011982026-08-01 21:25:002.0625197.99715` |
| 05 Pipeline evidence — what these answers actually read | table | OK | 20 | `9b89186c-9a54-4e71-be5a-f047995cfbc11836906734307236954154` |

46 passed, 0 failed.

## live-6h — `2026-08-01 15:54:15` .. `2026-08-01 21:54:15`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `198` |
| 01 Exact peak in window — all titles | number | OK | 1 | `1161` |
| 01 Viewer-hours in window | number | OK | 1 | `990.54` |
| 01 Live layer lag (seconds) | number | OK | 1 | `550` |
| 01 Concurrent viewers — exact peak vs time-weighted average | line | OK | 118 | `2026-08-01 19:48:00328157.62` |
| 01 Top titles — average concurrent viewers | line | OK | 674 | `2026-08-01 19:49:00cegeg gef0.57` |
| 01 Title leaderboard | table | OK | 25 | `zupop dajvoddjfhp20019887.15` |
| 02 Time-weighted average concurrency | number | OK | 1 | `200.164295` |
| 02 Viewer-hours | number | OK | 1 | `980.81` |
| 02 Active intervals started | number | OK | 1 | `16518` |
| 02 Average concurrency by platform | line | OK | 1068 | `2026-08-01 16:46:00ANDROID_PHONE0.4` |
| 02 Average concurrency by content type | line | OK | 148 | `2026-08-01 16:46:00vod0.4` |
| 02 Viewer-hours by category | pie | OK | 12 | `djfhp69.19` |
| 02 Titles by viewer-hours | table | OK | 25 | `zupop dajvoddjfhp68.4520120.4` |
| 02 Exact peak — all dimensions collapsed | number | OK | 1 | `1161` |
| 02 Minute layer lag (seconds) | number | OK | 1 | `892` |
| 02 Peak minute in window | table | OK | 1 | `2026-08-01 19:53:0011611000.83` |
| 02 Exact peak by platform | bar | OK | 12 | `ANDROID_PHONE807` |
| 02 Exact peak by app version | table | OK | 10 | `6.34.8718640.94` |
| 02 Exact peak by category | table | OK | 25 | `djfhp20069.19` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 135 | `2026-08-01 16:46:00-1.620.180.34` |
| 03 Rows ingested per second, by producer | line | OK | 153 | `2026-08-01 16:22:00csv:ch-hackathon-raw-data.csv15092.6` |
| 03 Read volume per serving query — cluster-wide | table | OK | 30 | `2595868534908427675-- ====================================` |
| 03 Rollup build duration by layer (ms) | line | OK | 308 | `2026-08-01 19:45:00live177` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 136 | `2026-08-01 16:22:0010866` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 21:45:39.91655548466298sonyliv-active-` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1234887122775371340.57770` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.23 million12.01 MiB21.9142` |
| 04 Average concurrent viewers by platform | stacked_bar | OK | 1068 | `2026-08-01 16:46:00ANDROID_PHONE0.4` |
| 04 Platform totals | table | OK | 12 | `ANDROID_PHONE695.5570.9211422` |
| 04 Average concurrent viewers by content type | stacked_bar | OK | 148 | `2026-08-01 16:46:00vod0.4` |
| 04 Content type totals | table | OK | 3 | `vod979.299.8416468` |
| 04 Average concurrent viewers by app version | stacked_bar | OK | 888 | `2026-08-01 16:46:000.4` |
| 04 App version totals | table | OK | 10 | `6.34.8640.9465.3510335` |
| 04 Average concurrent viewers by category | stacked_bar | OK | 1051 | `2026-08-01 16:46:00other0.4` |
| 04 Category totals | table | OK | 30 | `djfhp69.197.05222` |
| 04 Average concurrent viewers by title (top 10, rest folded into 'other') | stacked_bar | OK | 1006 | `2026-08-01 16:46:00other0.4` |
| 04 Title totals | table | OK | 30 | `zupop dajvoddjfhp68.456.98201` |
| 05 Exact peak concurrency in window | number | OK | 1 | `1161` |
| 05 Time-weighted average concurrency in window | number | OK | 1 | `200.164295` |
| 05 Minutes covered by the answer | number | OK | 1 | `132` |
| 05 Benchmark answer set — exact peak and average per grouping, with the minute each peaked | table | OK | 13 | `(ungrouped)011612026-08-01 19:53:00200.164295132` |
| 05 Peak and average per minute | line | OK | 132 | `2026-08-01 16:46:0010.395` |
| 05 Peak and average per hour | line | OK | 5 | `2026-08-01 16:00:001453.839` |
| 05 Peak and average per day | table | OK | 1 | `2026-08-0111612026-08-01 19:53:0040.8669445.82132` |
| 05 Pipeline evidence — what these answers actually read | table | OK | 20 | `9b89186c-9a54-4e71-be5a-f047995cfbc11836906734307236954154` |

46 passed, 0 failed.

---

**Total: 276 passed, 0 failed.**
