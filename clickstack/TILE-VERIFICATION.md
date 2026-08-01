# ClickStack tile verification

Database `sonyliv_prod`, granularity 60s, generated 2026-08-01 20:38:47Z.

## hot-hour — `2026-07-26 10:00:00` .. `2026-07-26 11:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `0` |
| 01 Exact peak in window — all titles | number | OK | 1 | `0` |
| 01 Viewer-hours in window | number | OK | 1 | `0` |
| 01 Live layer lag (seconds) | number | OK | 1 | `7` |
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
| 02 Minute layer lag (seconds) | number | OK | 1 | `409` |
| 02 Peak minute in window | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Exact peak by platform | bar | OK | 10 | `ANDROID_PHONE1461` |
| 02 Exact peak by app version | table | OK | 25 | `6.34.81178444.21` |
| 02 Exact peak by category | table | OK | 25 | `cdbgg358128.71` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — this replica | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 20:38:17.9883341634263sonyliv-active-v` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1077138107075663820.59250` |
| 03 Storage and compression — this replica | table | OK | 10 | `events_clean1.07 million8.86 MiB25.812` |

28 passed, 0 failed.

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
| 02 Minute layer lag (seconds) | number | OK | 1 | `851933` |
| 02 Peak minute in window | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Exact peak by platform | bar | OK | 10 | `ANDROID_PHONE1461` |
| 02 Exact peak by app version | table | OK | 25 | `6.34.81178867.18` |
| 02 Exact peak by category | table | OK | 25 | `cdbgg358184.24` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — this replica | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 20:38:27.9692741662245sonyliv-active-v` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1077383107100163820.59240` |
| 03 Storage and compression — this replica | table | OK | 10 | `events_clean1.07 million8.86 MiB25.811` |

28 passed, 0 failed.

## gap-no-data — `2026-07-16 00:00:00` .. `2026-07-18 00:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `0` |
| 01 Exact peak in window — all titles | number | OK | 1 | `0` |
| 01 Viewer-hours in window | number | OK | 1 | `0` |
| 01 Live layer lag (seconds) | number | OK | 1 | `5` |
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
| 02 Minute layer lag (seconds) | number | OK | 1 | `592737` |
| 02 Peak minute in window | table | OK | 0 | `—` |
| 02 Exact peak by platform | bar | OK | 0 | `—` |
| 02 Exact peak by app version | table | OK | 0 | `—` |
| 02 Exact peak by category | table | OK | 0 | `—` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — this replica | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 20:38:27.9693141662245sonyliv-active-v` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1077507107112463830.59240` |
| 03 Storage and compression — this replica | table | OK | 10 | `events_clean1.07 million8.87 MiB25.810` |

28 passed, 0 failed.

## full-extract — `2026-07-14 00:00:00` .. `2026-07-27 00:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `0` |
| 01 Exact peak in window — all titles | number | OK | 1 | `0` |
| 01 Viewer-hours in window | number | OK | 1 | `0` |
| 01 Live layer lag (seconds) | number | OK | 1 | `9` |
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
| 02 Minute layer lag (seconds) | number | OK | 1 | `361` |
| 02 Peak minute in window | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Exact peak by platform | bar | OK | 10 | `ANDROID_PHONE1461` |
| 02 Exact peak by app version | table | OK | 25 | `6.34.81178928.47` |
| 02 Exact peak by category | table | OK | 25 | `cdbgg358185.53` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — this replica | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 20:38:37.9232541684251sonyliv-active-v` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1077738107135463840.59240` |
| 03 Storage and compression — this replica | table | OK | 10 | `events_clean1.07 million8.89 MiB25.814` |

28 passed, 0 failed.

## live-30m — `2026-08-01 20:08:47` .. `2026-08-01 20:38:47`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `584` |
| 01 Exact peak in window — all titles | number | OK | 1 | `597` |
| 01 Viewer-hours in window | number | OK | 1 | `281.76` |
| 01 Live layer lag (seconds) | number | OK | 1 | `3` |
| 01 Concurrent viewers — exact peak vs time-weighted average | line | OK | 31 | `2026-08-01 20:08:0056292.45` |
| 01 Top titles — average concurrent viewers | line | OK | 248 | `2026-08-01 20:08:00tifif feh3.05` |
| 01 Title leaderboard | table | OK | 25 | `vamem befvodbfcfm332612.7` |
| 02 Time-weighted average concurrency | number | OK | 1 | `559.782397` |
| 02 Viewer-hours | number | OK | 1 | `223.91` |
| 02 Active intervals started | number | OK | 1 | `3598` |
| 02 Average concurrency by platform | line | OK | 240 | `2026-08-01 20:09:00SONY_ANDROID_TV49.64` |
| 02 Average concurrency by content type | line | OK | 24 | `2026-08-01 20:09:00vod564.37` |
| 02 Viewer-hours by category | pie | OK | 12 | `chbgg17.95` |
| 02 Titles by viewer-hours | table | OK | 25 | `wofif fihvodchbgg10.591444.4` |
| 02 Exact peak — all dimensions collapsed | number | OK | 1 | `586` |
| 02 Minute layer lag (seconds) | number | OK | 1 | `365` |
| 02 Peak minute in window | table | OK | 1 | `2026-08-01 20:22:00586572.9` |
| 02 Exact peak by platform | bar | OK | 10 | `ANDROID_PHONE422` |
| 02 Exact peak by app version | table | OK | 8 | `6.34.8387142.01` |
| 02 Exact peak by category | table | OK | 25 | `chbgg5717.95` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 31 | `2026-08-01 20:08:0021.99527.62876.902` |
| 03 Rows ingested per second, by producer | line | OK | 31 | `2026-08-01 20:08:00generator12.1` |
| 03 Read volume per serving query — this replica | table | OK | 30 | `17704518813321872408-- ===================================` |
| 03 Rollup build duration by layer (ms) | line | OK | 67 | `2026-08-01 20:08:00intervals273` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 31 | `2026-08-01 20:08:00325` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 20:38:37.9232941684251sonyliv-active-v` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1078029107164463850.59230` |
| 03 Storage and compression — this replica | table | OK | 10 | `events_clean1.07 million8.90 MiB25.713` |

28 passed, 0 failed.

## live-6h — `2026-08-01 14:38:47` .. `2026-08-01 20:38:47`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `584` |
| 01 Exact peak in window — all titles | number | OK | 1 | `1161` |
| 01 Viewer-hours in window | number | OK | 1 | `489.88` |
| 01 Live layer lag (seconds) | number | OK | 1 | `7` |
| 01 Concurrent viewers — exact peak vs time-weighted average | line | OK | 51 | `2026-08-01 19:48:00328157.62` |
| 01 Top titles — average concurrent viewers | line | OK | 376 | `2026-08-01 19:52:00taziz lic11.06` |
| 01 Title leaderboard | table | OK | 25 | `vosus gajvodbjfff371314.31` |
| 02 Time-weighted average concurrency | number | OK | 1 | `117.12443` |
| 02 Viewer-hours | number | OK | 1 | `443.12` |
| 02 Active intervals started | number | OK | 1 | `8885` |
| 02 Average concurrency by platform | line | OK | 533 | `2026-08-01 16:46:00ANDROID_PHONE0.4` |
| 02 Average concurrency by content type | line | OK | 81 | `2026-08-01 16:46:00vod0.4` |
| 02 Viewer-hours by category | pie | OK | 12 | `chbgg31.41` |
| 02 Titles by viewer-hours | table | OK | 25 | `wofif fihvodchbgg17.832993.6` |
| 02 Exact peak — all dimensions collapsed | number | OK | 1 | `1161` |
| 02 Minute layer lag (seconds) | number | OK | 1 | `369` |
| 02 Peak minute in window | table | OK | 1 | `2026-08-01 19:53:0011611000.83` |
| 02 Exact peak by platform | bar | OK | 10 | `ANDROID_PHONE807` |
| 02 Exact peak by app version | table | OK | 9 | `6.34.8718277.01` |
| 02 Exact peak by category | table | OK | 25 | `chbgg6531.41` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 59 | `2026-08-01 16:46:00-1.620.180.34` |
| 03 Rows ingested per second, by producer | line | OK | 61 | `2026-08-01 16:22:00csv:ch-hackathon-raw-data.csv15092.6` |
| 03 Read volume per serving query — this replica | table | OK | 30 | `17704518813321872408-- ===================================` |
| 03 Rollup build duration by layer (ms) | line | OK | 111 | `2026-08-01 19:45:00minute1647` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 60 | `2026-08-01 16:22:0010866` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 20:38:37.9233341684251sonyliv-active-v` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1078265107187663890.59250` |
| 03 Storage and compression — this replica | table | OK | 10 | `events_clean1.07 million8.90 MiB25.712` |

28 passed, 0 failed.

---

**Total: 168 passed, 0 failed.**
