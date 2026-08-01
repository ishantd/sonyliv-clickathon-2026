# ClickStack tile verification

Database `sonyliv_prod`, granularity 60s, generated 2026-08-01 22:26:23Z.

## hot-hour — `2026-07-26 10:00:00` .. `2026-07-26 11:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent now | number | OK | 1 | `0` |
| 01 Peak (ungrouped) | number | OK | 1 | `0` |
| 01 Viewer-hours | number | OK | 1 | `0` |
| 01 Layer lag (s) | number | OK | 1 | `14` |
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
| 02 Layer lag (s) | number | OK | 1 | `385` |
| 02 Peak minute | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Peak by grouping | table | OK | 60 | `totalall23052026-07-26 10:55:00855.660` |
| 03 Ingest lag p50/p95/p99 (s) | line | OK | 0 | `—` |
| 03 Rows/s by producer | line | OK | 0 | `—` |
| 03 Read volume by query | table | OK | 0 | `—` |
| 03 Rollup duration (ms) | line | OK | 0 | `—` |
| 03 Sessions dirtied/min | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 22:26:22.005554935319sonyliv-active-v1` |
| 03 Dedup collapse | table | OK | 1 | `1369547136193976080.55550` |
| 03 Storage | table | OK | 10 | `events_clean1.36 million15.05 MiB19.4134` |
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

46 passed, 0 failed.

## hot-day — `2026-07-26 00:00:00` .. `2026-07-27 00:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent now | number | OK | 1 | `0` |
| 01 Peak (ungrouped) | number | OK | 1 | `0` |
| 01 Viewer-hours | number | OK | 1 | `0` |
| 01 Layer lag (s) | number | OK | 1 | `12` |
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
| 02 Layer lag (s) | number | OK | 1 | `394` |
| 02 Peak minute | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Peak by grouping | table | OK | 60 | `totalall23052026-07-26 10:55:001671.75637` |
| 03 Ingest lag p50/p95/p99 (s) | line | OK | 0 | `—` |
| 03 Rows/s by producer | line | OK | 0 | `—` |
| 03 Read volume by query | table | OK | 0 | `—` |
| 03 Rollup duration (ms) | line | OK | 0 | `—` |
| 03 Sessions dirtied/min | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 22:26:33.004254952315sonyliv-active-v1` |
| 03 Dedup collapse | table | OK | 1 | `1370646136310475420.55030` |
| 03 Storage | table | OK | 10 | `events_raw1.44 million15.11 MiB20.4111` |
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
| 05 Peak per hour | line | OK | 19646 | `2026-07-26 00:00:00content: ruzaz lac1` |
| 05 Per day | table | OK | 12357 | `2026-07-26totalall23052026-07-26 10:55:0069.656157.464637` |
| 05 Query evidence | table | OK | 0 | `—` |

46 passed, 0 failed.

## gap-no-data — `2026-07-16 00:00:00` .. `2026-07-18 00:00:00`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent now | number | OK | 1 | `0` |
| 01 Peak (ungrouped) | number | OK | 1 | `0` |
| 01 Viewer-hours | number | OK | 1 | `0` |
| 01 Layer lag (s) | number | OK | 1 | `12` |
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
| 02 Layer lag (s) | number | OK | 1 | `404` |
| 02 Peak minute | table | OK | 0 | `—` |
| 02 Peak by grouping | table | OK | 0 | `—` |
| 03 Ingest lag p50/p95/p99 (s) | line | OK | 0 | `—` |
| 03 Rows/s by producer | line | OK | 0 | `—` |
| 03 Read volume by query | table | OK | 0 | `—` |
| 03 Rollup duration (ms) | line | OK | 0 | `—` |
| 03 Sessions dirtied/min | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 22:26:42.005354982302sonyliv-active-v1` |
| 03 Dedup collapse | table | OK | 1 | `1371780136423575450.550` |
| 03 Storage | table | OK | 10 | `events_clean1.36 million15.10 MiB19.4154` |
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

46 passed, 0 failed.

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
| 02 Layer lag (s) | number | OK | 1 | `411` |
| 02 Peak minute | table | OK | 1 | `2026-07-26 10:55:0023052283.98` |
| 02 Peak by grouping | table | OK | 60 | `totalall23052026-07-26 10:55:001779.533662` |
| 03 Ingest lag p50/p95/p99 (s) | line | OK | 0 | `—` |
| 03 Rows/s by producer | line | OK | 0 | `—` |
| 03 Read volume by query | table | OK | 0 | `—` |
| 03 Rollup duration (ms) | line | OK | 0 | `—` |
| 03 Sessions dirtied/min | line | OK | 0 | `—` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 22:26:42.0051054982302sonyliv-active-v` |
| 03 Dedup collapse | table | OK | 1 | `1372594136504875460.54980` |
| 03 Storage | table | OK | 10 | `events_clean1.37 million15.11 MiB19.4144` |
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
| 05 Peak per hour | line | OK | 22484 | `2026-07-14 15:00:00platform + country: IPHONE  india1` |
| 05 Per day | table | OK | 13548 | `2026-07-14categorybhbbb12026-07-14 15:43:000.0130.71926` |
| 05 Query evidence | table | OK | 0 | `—` |

46 passed, 0 failed.

## live-30m — `2026-08-01 21:56:23` .. `2026-08-01 22:26:23`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent now | number | OK | 1 | `2564` |
| 01 Peak (ungrouped) | number | OK | 1 | `2803` |
| 01 Viewer-hours | number | OK | 1 | `681.95` |
| 01 Layer lag (s) | number | OK | 1 | `9` |
| 01 Concurrent viewers | line | OK | 31 | `2026-08-01 21:56:0099` |
| 01 Peak vs average (ungrouped) | line | OK | 31 | `2026-08-01 21:56:0019899` |
| 01 Top titles | line | OK | 190 | `2026-08-01 21:56:00zupop daj99` |
| 01 Title leaderboard | table | OK | 25 | `nivev jadvodcdbgg20002000398.32` |
| 02 Average concurrency | number | OK | 1 | `1106.070247` |
| 02 Viewer-hours | number | OK | 1 | `442.43` |
| 02 Intervals started | number | OK | 1 | `5758` |
| 02 By platform | line | OK | 178 | `2026-08-01 21:57:00ANDROID_PHONE198` |
| 02 By content type | line | OK | 41 | `2026-08-01 21:57:00vod198` |
| 02 Viewer-hours by category | pie | OK | 12 | `cdbgg216.77` |
| 02 Titles | table | OK | 25 | `nivev jadvodcdbgg214.9720106.4` |
| 02 Peak (ungrouped) | number | OK | 1 | `2803` |
| 02 Layer lag (s) | number | OK | 1 | `361` |
| 02 Peak minute | table | OK | 1 | `2026-08-01 22:14:0028032603.72` |
| 02 Peak by grouping | table | OK | 60 | `countryindia28032026-08-01 22:14:00442.4324` |
| 03 Ingest lag p50/p95/p99 (s) | line | OK | 31 | `2026-08-01 21:56:000.3170.8150.817` |
| 03 Rows/s by producer | line | OK | 55 | `2026-08-01 21:56:00api4.1` |
| 03 Read volume by query | table | OK | 30 | `2595868534908427675-- ====================================` |
| 03 Rollup duration (ms) | line | OK | 63 | `2026-08-01 22:05:00intervals1865` |
| 03 Sessions dirtied/min | line | OK | 31 | `2026-08-01 21:56:00200` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 22:26:52.0041155013311sonyliv-active-v` |
| 03 Dedup collapse | table | OK | 1 | `1373926136637475520.54970` |
| 03 Storage | table | OK | 10 | `events_clean1.37 million15.13 MiB19.4154` |
| 04 By platform | stacked_bar | OK | 178 | `2026-08-01 21:57:00ANDROID_PHONE198` |
| 04 Platform totals | table | OK | 11 | `ANDROID_PHONE389.9688.144586` |
| 04 By content type | stacked_bar | OK | 41 | `2026-08-01 21:57:00vod198` |
| 04 Content type totals | table | OK | 2 | `vod439.1599.265687` |
| 04 By app version | stacked_bar | OK | 143 | `2026-08-01 21:57:006.34.8198` |
| 04 App version totals | table | OK | 8 | `6.34.8378.6885.594311` |
| 04 By category | stacked_bar | OK | 194 | `2026-08-01 21:57:00djfhp198` |
| 04 Category totals | table | OK | 30 | `cdbgg216.77492041` |
| 04 By title (top 10) | stacked_bar | OK | 192 | `2026-08-01 21:57:00zupop daj198` |
| 04 Title totals | table | OK | 30 | `nivev jadvodcdbgg214.9748.592010` |
| 05 Peak (ungrouped) | number | OK | 1 | `2803` |
| 05 Average (ungrouped) | number | OK | 1 | `1106.070247` |
| 05 Viewer-hours (ungrouped) | number | OK | 1 | `442.43` |
| 05 Rows read | number | OK | 1 | `24` |
| 05 Peak by dimension value | table | OK | 50 | `countryindia28032026-08-01 22:14:001106.070247442.43` |
| 05 Peak per minute | line | OK | 34021 | `2026-08-01 21:57:00total: all198` |
| 05 Peak per hour | line | OK | 2962 | `2026-08-01 21:00:00platform: ANDROID_PHONE198` |
| 05 Per day | table | OK | 2949 | `2026-08-01totalall28032026-08-01 22:14:0018.43451106.0724` |
| 05 Query evidence | table | OK | 20 | `05da3323-bf89-403f-8425-1b0af1055f623708860768777926036621` |

46 passed, 0 failed.

## live-6h — `2026-08-01 16:26:23` .. `2026-08-01 22:26:23`

| Tile | Type | Result | Rows | First row |
|---|---|---|---|---|
| 01 Concurrent now | number | OK | 1 | `2570` |
| 01 Peak (ungrouped) | number | OK | 1 | `2803` |
| 01 Viewer-hours | number | OK | 1 | `1708.34` |
| 01 Layer lag (s) | number | OK | 1 | `8` |
| 01 Concurrent viewers | line | OK | 159 | `2026-08-01 19:48:00157.62` |
| 01 Peak vs average (ungrouped) | line | OK | 159 | `2026-08-01 19:48:00328157.62` |
| 01 Top titles | line | OK | 871 | `2026-08-01 19:49:00cegeg gef0.57` |
| 01 Title leaderboard | table | OK | 25 | `nivev jadvodcdbgg20002000424.95` |
| 02 Average concurrency | number | OK | 1 | `264.95519` |
| 02 Viewer-hours | number | OK | 1 | `1479.33` |
| 02 Intervals started | number | OK | 1 | `22276` |
| 02 By platform | line | OK | 1263 | `2026-08-01 16:46:00ANDROID_PHONE0.4` |
| 02 By content type | line | OK | 206 | `2026-08-01 16:46:00vod0.4` |
| 02 Viewer-hours by category | pie | OK | 12 | `cdbgg272.74` |
| 02 Titles | table | OK | 25 | `nivev jadvodcdbgg241.6724945.8` |
| 02 Peak (ungrouped) | number | OK | 1 | `2803` |
| 02 Layer lag (s) | number | OK | 1 | `370` |
| 02 Peak minute | table | OK | 1 | `2026-08-01 22:14:0028032603.72` |
| 02 Peak by grouping | table | OK | 60 | `countryindia28032026-08-01 22:14:001479.33173` |
| 03 Ingest lag p50/p95/p99 (s) | line | OK | 167 | `2026-08-01 16:46:00-1.620.180.34` |
| 03 Rows/s by producer | line | OK | 208 | `2026-08-01 16:46:00api0` |
| 03 Read volume by query | table | OK | 30 | `2595868534908427675-- ====================================` |
| 03 Rollup duration (ms) | line | OK | 371 | `2026-08-01 19:45:00live177` |
| 03 Sessions dirtied/min | line | OK | 167 | `2026-08-01 16:46:001` |
| 03 Layer freshness | table | OK | 3 | `intervals2026-08-01 22:27:02.004955043311sonyliv-active-v1` |
| 03 Dedup collapse | table | OK | 1 | `1374921136736875530.54930` |
| 03 Storage | table | OK | 10 | `events_clean1.37 million15.12 MiB19.4124` |
| 04 By platform | stacked_bar | OK | 1263 | `2026-08-01 16:46:00ANDROID_PHONE0.4` |
| 04 Platform totals | table | OK | 12 | `ANDROID_PHONE1141.6177.1716008` |
| 04 By content type | stacked_bar | OK | 206 | `2026-08-01 16:46:00vod0.4` |
| 04 Content type totals | table | OK | 3 | `vod1474.4599.6722155` |
| 04 By app version | stacked_bar | OK | 1048 | `2026-08-01 16:46:000.4` |
| 04 App version totals | table | OK | 10 | `6.34.81075.7272.7214646` |
| 04 By category | stacked_bar | OK | 1251 | `2026-08-01 16:46:00other0.4` |
| 04 Category totals | table | OK | 30 | `cdbgg272.7418.443023` |
| 04 By title (top 10) | stacked_bar | OK | 1209 | `2026-08-01 16:46:00other0.4` |
| 04 Title totals | table | OK | 30 | `nivev jadvodcdbgg241.6716.342494` |
| 05 Peak (ungrouped) | number | OK | 1 | `2803` |
| 05 Average (ungrouped) | number | OK | 1 | `264.95519` |
| 05 Viewer-hours (ungrouped) | number | OK | 1 | `1479.33` |
| 05 Rows read | number | OK | 1 | `173` |
| 05 Peak by dimension value | table | OK | 50 | `totalall28032026-08-01 22:14:00264.955191479.33` |
| 05 Peak per minute | line | OK | 121449 | `2026-08-01 16:46:00total: all1` |
| 05 Peak per hour | line | OK | 11666 | `2026-08-01 16:00:00platform + content: JIO_ANDROID_TV  vub` |
| 05 Per day | table | OK | 8216 | `2026-08-01countryindia28032026-08-01 22:14:0061.6389513.06` |
| 05 Query evidence | table | OK | 20 | `9b89186c-9a54-4e71-be5a-f047995cfbc11836906734307236954154` |

46 passed, 0 failed.

---

**Total: 276 passed, 0 failed.**
