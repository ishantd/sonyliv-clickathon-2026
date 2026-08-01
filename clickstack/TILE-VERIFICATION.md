# ClickStack tile verification

Database `sonyliv_prod`, granularity 60s, generated 2026-08-01 21:05:59Z.

## hot-hour — `2026-07-26 10:00:00` .. `2026-07-26 11:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `0` |
| 01 Exact peak in window — all titles | number | OK | 1 | `0` |
| 01 Viewer-hours in window | number | OK | 1 | `0` |
| 01 Live layer lag (seconds) | number | OK | 1 | `11` |
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
| 02 Minute layer lag (seconds) | number | OK | 1 | `425` |
| 02 Peak minute in window | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Exact peak by platform | bar | OK | 10 | `ANDROID_PHONE1461` |
| 02 Exact peak by app version | table | OK | 25 | `6.34.81178444.21` |
| 02 Exact peak by category | table | OK | 25 | `cdbgg358128.71` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — cluster-wide | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 21:05:37.9543245801288sonyliv-active-v` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1167871116100968620.58760` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.16 million10.40 MiB23.9132` |
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
| 01 Live layer lag (seconds) | number | OK | 1 | `4` |
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
| 02 Minute layer lag (seconds) | number | OK | 1 | `439` |
| 02 Peak minute in window | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Exact peak by platform | bar | OK | 10 | `ANDROID_PHONE1461` |
| 02 Exact peak by app version | table | OK | 25 | `6.34.81178867.18` |
| 02 Exact peak by category | table | OK | 25 | `cdbgg358184.24` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — cluster-wide | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 21:05:57.9232545862300sonyliv-active-v` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1168568116170468640.58740` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.16 million10.40 MiB23.9112` |
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
| 01 Live layer lag (seconds) | number | OK | 1 | `7` |
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
| 02 Minute layer lag (seconds) | number | OK | 1 | `390` |
| 02 Peak minute in window | table | OK | 0 | `—` |
| 02 Exact peak by platform | bar | OK | 0 | `—` |
| 02 Exact peak by app version | table | OK | 0 | `—` |
| 02 Exact peak by category | table | OK | 0 | `—` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — cluster-wide | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 21:06:07.8812745888274sonyliv-active-v` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1169212116234668660.58720` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.16 million10.41 MiB23.9132` |
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
| 02 Minute layer lag (seconds) | number | OK | 1 | `404` |
| 02 Peak minute in window | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Exact peak by platform | bar | OK | 10 | `ANDROID_PHONE1461` |
| 02 Exact peak by app version | table | OK | 25 | `6.34.81178928.47` |
| 02 Exact peak by category | table | OK | 25 | `cdbgg358185.53` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 0 | `—` |
| 03 Rows ingested per second, by producer | line | OK | 0 | `—` |
| 03 Read volume per serving query — cluster-wide | table | OK | 0 | `—` |
| 03 Rollup build duration by layer (ms) | line | OK | 0 | `—` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 21:06:17.9133045919277sonyliv-active-v` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1170000116312968710.58730` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.16 million10.42 MiB23.9122` |
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

## live-30m — `2026-08-01 20:35:59` .. `2026-08-01 21:05:59`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `556` |
| 01 Exact peak in window — all titles | number | OK | 1 | `599` |
| 01 Viewer-hours in window | number | OK | 1 | `280.1` |
| 01 Live layer lag (seconds) | number | OK | 1 | `5` |
| 01 Concurrent viewers — exact peak vs time-weighted average | line | OK | 30 | `2026-08-01 20:36:00596580.97` |
| 01 Top titles — average concurrent viewers | line | OK | 240 | `2026-08-01 20:36:00nivev jad22.73` |
| 01 Title leaderboard | table | OK | 25 | `necec cegvodcgdgn39159.97` |
| 02 Time-weighted average concurrency | number | OK | 1 | `565.228688` |
| 02 Viewer-hours | number | OK | 1 | `226.09` |
| 02 Active intervals started | number | OK | 1 | `3669` |
| 02 Average concurrency by platform | line | OK | 249 | `2026-08-01 20:36:00IPHONE55.15` |
| 02 Average concurrency by content type | line | OK | 24 | `2026-08-01 20:36:00vod580.97` |
| 02 Viewer-hours by category | pie | OK | 12 | `cdbgg16.63` |
| 02 Titles by viewer-hours | table | OK | 25 | `mesos gejvodbjcfm9.921543.9` |
| 02 Exact peak — all dimensions collapsed | number | OK | 1 | `599` |
| 02 Minute layer lag (seconds) | number | OK | 1 | `420` |
| 02 Peak minute in window | table | OK | 1 | `2026-08-01 20:38:00599588.78` |
| 02 Exact peak by platform | bar | OK | 12 | `ANDROID_PHONE410` |
| 02 Exact peak by app version | table | OK | 9 | `6.34.8400142.65` |
| 02 Exact peak by category | table | OK | 25 | `chbgg5815.8` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 31 | `2026-08-01 20:35:0022.18126.33163.671` |
| 03 Rows ingested per second, by producer | line | OK | 43 | `2026-08-01 20:35:00generator1.1` |
| 03 Read volume per serving query — cluster-wide | table | OK | 30 | `11406397511435481412\nWITH w AS (SELECT toDateTime(\'2026-` |
| 03 Rollup build duration by layer (ms) | line | OK | 86 | `2026-08-01 20:36:00live205` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 31 | `2026-08-01 20:35:0037` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 21:06:37.8612745971293sonyliv-active-v` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1170822116394668760.58730` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.16 million10.44 MiB23.9132` |
| 04 Average concurrent viewers by platform | stacked_bar | OK | 249 | `2026-08-01 20:36:00IPHONE55.15` |
| 04 Platform totals | table | OK | 12 | `ANDROID_PHONE151.9267.192514` |
| 04 Average concurrent viewers by content type | stacked_bar | OK | 24 | `2026-08-01 20:36:00vod580.97` |
| 04 Content type totals | table | OK | 1 | `vod226.091003669` |
| 04 Average concurrent viewers by app version | stacked_bar | OK | 196 | `2026-08-01 20:36:003.9.412.75` |
| 04 App version totals | table | OK | 9 | `6.34.8142.6563.092307` |
| 04 Average concurrent viewers by category | stacked_bar | OK | 264 | `2026-08-01 20:36:00bgfff23.72` |
| 04 Category totals | table | OK | 27 | `cdbgg16.637.35263` |
| 04 Average concurrent viewers by title (top 10, rest folded into 'other') | stacked_bar | OK | 264 | `2026-08-01 20:36:00necec ceg16.62` |
| 04 Title totals | table | OK | 30 | `mesos gejvodbjcfm9.924.39154` |

38 passed, 0 failed.

## live-6h — `2026-08-01 15:05:59` .. `2026-08-01 21:05:59`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent viewers now | number | OK | 1 | `557` |
| 01 Exact peak in window — all titles | number | OK | 1 | `1161` |
| 01 Viewer-hours in window | number | OK | 1 | `742.44` |
| 01 Live layer lag (seconds) | number | OK | 1 | `10` |
| 01 Concurrent viewers — exact peak vs time-weighted average | line | OK | 78 | `2026-08-01 19:48:00328157.62` |
| 01 Top titles — average concurrent viewers | line | OK | 595 | `2026-08-01 19:49:00cegeg gef0.57` |
| 01 Title leaderboard | table | OK | 25 | `necec cegvodcgdgn391524.22` |
| 02 Time-weighted average concurrency | number | OK | 1 | `164.87062` |
| 02 Viewer-hours | number | OK | 1 | `697.95` |
| 02 Active intervals started | number | OK | 1 | `12997` |
| 02 Average concurrency by platform | line | OK | 812 | `2026-08-01 16:46:00ANDROID_PHONE0.4` |
| 02 Average concurrency by content type | line | OK | 108 | `2026-08-01 16:46:00vod0.4` |
| 02 Viewer-hours by category | pie | OK | 12 | `chbgg49.8` |
| 02 Titles by viewer-hours | table | OK | 25 | `vamem befvodbfcfm28.624843.5` |
| 02 Exact peak — all dimensions collapsed | number | OK | 1 | `1161` |
| 02 Minute layer lag (seconds) | number | OK | 1 | `433` |
| 02 Peak minute in window | table | OK | 1 | `2026-08-01 19:53:0011611000.83` |
| 02 Exact peak by platform | bar | OK | 12 | `ANDROID_PHONE807` |
| 02 Exact peak by app version | table | OK | 10 | `6.34.8718437.71` |
| 02 Exact peak by category | table | OK | 25 | `chbgg6549.8` |
| 03 Stream ingest lag p50 / p95 / p99 (seconds) | line | OK | 86 | `2026-08-01 16:46:00-1.620.180.34` |
| 03 Rows ingested per second, by producer | line | OK | 100 | `2026-08-01 16:22:00csv:ch-hackathon-raw-data.csv15092.6` |
| 03 Read volume per serving query — cluster-wide | table | OK | 30 | `17970580568159697991-- ===================================` |
| 03 Rollup build duration by layer (ms) | line | OK | 189 | `2026-08-01 19:45:00live177` |
| 03 Recompute backlog — sessions dirtied per minute | line | OK | 87 | `2026-08-01 16:22:0010866` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 21:06:47.9483146006255sonyliv-active-v` |
| 03 Dedup collapse — landed vs resolved | table | OK | 1 | `1171622116474368790.58710` |
| 03 Storage and compression | table | OK | 10 | `events_clean1.16 million10.44 MiB23.9122` |
| 04 Average concurrent viewers by platform | stacked_bar | OK | 812 | `2026-08-01 16:46:00ANDROID_PHONE0.4` |
| 04 Platform totals | table | OK | 12 | `ANDROID_PHONE479.0468.648924` |
| 04 Average concurrent viewers by content type | stacked_bar | OK | 108 | `2026-08-01 16:46:00vod0.4` |
| 04 Content type totals | table | OK | 3 | `vod696.3599.7712947` |
| 04 Average concurrent viewers by app version | stacked_bar | OK | 680 | `2026-08-01 16:46:000.4` |
| 04 App version totals | table | OK | 10 | `6.34.8437.7162.718089` |
| 04 Average concurrent viewers by category | stacked_bar | OK | 881 | `2026-08-01 16:46:00other0.4` |
| 04 Category totals | table | OK | 30 | `chbgg49.87.13879` |
| 04 Average concurrent viewers by title (top 10, rest folded into 'other') | stacked_bar | OK | 830 | `2026-08-01 16:46:00necec ceg0.4` |
| 04 Title totals | table | OK | 30 | `vamem befvodbfcfm28.624.1484` |

38 passed, 0 failed.

---

**Total: 228 passed, 0 failed.**
