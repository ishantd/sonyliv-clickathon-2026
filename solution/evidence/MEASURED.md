# Measured evidence ledger

This ledger contains observations, not product-policy claims. The source is the
public SonyLIV Click-a-thon package and all calculations were run locally with
chDB 4.2.1 (the embedded ClickHouse engine) over the original CSV bytes. The
reproducible server-side queries are in `sql/05_profile_loaded_data.sql`.

## Source identity

| Source | Bytes | Data rows | SHA-256 |
|---|---:|---:|---|
| Raw events | 232,827,255 | 905,558 | `15ce6df78e7239820fb9951f2a5c68de2abb47a0950068947e1a0344a0283a96` |
| Content dimension | 1,181,455 | 33,464 | `e013c4958e9b6396f9cc6cd2681bb6944bb65dc810b7f0925f78254ed9c7ddd4` |

The raw event-time range is `2026-07-14 15:43:58.144` through
`2026-07-26 11:30:04.847` UTC over seven non-contiguous dates. July 26 contains
849,888 events and 10,517 session starts, so whole-file daily averages are not a
representative load benchmark.

## Population and shape

| Measure | Observed |
|---|---:|
| Raw events | 905,558 |
| Video session IDs | 10,866 |
| User IDs anywhere in events | 9,618 |
| Canonical users on SessionStart | 9,510 |
| Raw content IDs | 3,357 |
| Heartbeat rows | 843,600 (93.158%) |
| Rows/session | p50 53; p90 180; p99 432; max 1,803 |
| Session duration | p50 711.983s; p90 1,990.126s; p99 about 4,447s |
| Sessions longer than 1h / 4h / 24h | 150 / 16 / 1 |
| Longest session | 157,101.184s (43.64h) |

Event types: 843,600 `VideoHeartbeat`, 14,700 `AppBackgrounded`,
14,321 `AppForegrounded`, 10,883 `VideoPlay`, 10,881
`VideoSessionEnd`, 10,880 `VideoSessionStart`, and 293 `VideoError`.

## Disorder and duplicates

- 4,209 excess exact rows occur across about 3,412 duplicate groups and 862
  sessions; maximum multiplicity is six.
- `(session, timestamp, event_type, event)` removes 4,210 rows. The one extra
  conflict differs in subtitle payload, so payload selection must be explicit.
- Deduplicating `(session, timestamp)` would remove 211,766 rows from 161,660
  tied groups. At least 159,433 groups contain legitimate different events.
- In packaged CSV order, 264,998 rows (29.264%) are behind the prior event-time
  maximum for their session, affecting 10,828 sessions. Lag versus that prior
  maximum is p50 70.247s, p90 1,806.664s, p99 8,307.742s, and maximum
  155,764.222s (43.27h).
- Only 5,556 sessions physically start with their Start row, and only 4,281
  physically finish with their End row.

The file has no arrival timestamp. These values prove that batch replay must
sort by event time; they do **not** identify a production watermark. Production
must measure `ingested_at - event_time` directly.

## Lifecycle and state evidence

- After exact deduplication, every supplied session has a distinct Start, Play,
  and at least one End. Four sessions have two non-identical End timestamps; the
  supplied snapshot contains no truly open/no-End session.
- With first-End terminal semantics, 241 sessions have 870 later rows. With even
  the latest End, 239 sessions still have 802 later rows. Post-End input is an
  anomaly, not evidence that an ended lifecycle should reopen.
- Playback markers behave as idempotent assignments: 9,768 adjacent transitions
  are `resume -> resume` and 422 are `pause -> pause`.
- 13,497 of 14,321 Foreground events have `pause` as their latest playback
  marker. Therefore foregrounding cannot imply playing.
- 1,950 pauses and 357 resumes occur while backgrounded. Foreground and playing
  must be independent booleans.
- Of 293 errors, 238 are immediately followed by End and 288 have no later
  Play/resume. Treating Error as a playback stop is strongly supported; making
  it terminal is not established.
- The problem statement explicitly names paused time as inactive. Heartbeats
  continue after pause, so heartbeat freshness alone is insufficient.

Representative session `94D660...` starts, plays, emits telemetry, pauses at
800.944s, backgrounds at 827.440s, foregrounds at 830.641s, emits a heartbeat at
857.629s, then ends. Foreground and heartbeat do not erase the prior pause.

## Heartbeat evidence and sensitivity

`VideoHeartbeat` contains 47 event values, not one uniform clock. The clean
`network-activity` signal has 166,974 consecutive gaps: median 40.003s, p90
40.012s, and about 67% in [39s, 41s]. `video-resize` and iPhone
`network-bandwidth` show the same cadence. The data dictionary nevertheless says
the production heartbeat is currently every 60 seconds.

A periodic whitelist of `network-activity`, `buffer-health`, `video-resize`, and
`network-bandwidth` covers 10,847 of 10,866 sessions. The policy uses any
non-pause `VideoHeartbeat` as a liveness observation because the event type is
the documented heartbeat channel; stop markers still control playback state.

Sensitivity using exact dedup, event-time order, first-End terminal, independent
foreground/playing state, pause/error as stops, and an active-only heartbeat
lease:

| Model | Active hours | Share of naive session duration |
|---|---:|---:|
| Start-to-End overlap | 2,972.122 | 100.000% |
| Foreground + playing, no lease | 1,798.156951 | 60.501% |
| 60s lease | 1,773.598929 | 59.675% |
| 90s lease | 1,777.090138 | 59.792% |
| 120s lease | 1,779.502796 | 59.873% |

Relative to explicit foreground-and-playing time, 60/90/120 seconds retain
98.6343%/98.8284%/98.9626%, shortening 661/423/343 sessions. At 60 seconds,
retention varies from 99.94% on Mweb to 88.45% on Samsung HTML TV. A timeout is
therefore a configurable field policy, not a fact that this closed extract can
uniquely reveal.

These values use the checked-in rule that `AppForegrounded` changes only
visibility and does not renew liveness. If Foreground is instead treated as a
liveness signal, the 120s total becomes 1,780.049563h (+0.546768h across 152
sessions). That alternate assumption explains the prior sensitivity estimate;
it is not a query discrepancy.

## Dimensions and content

| Dimension | Cardinality |
|---|---:|
| Platform | 10 |
| App version | 65 |
| Country | 1 (`india`) |
| Audio language | 41 exact; 26 lower/trim-normalized |
| Subtitle language | 11 exact; 8 normalized |
| Player version | 14 |
| Content category | 84 |
| Content title | 30,508 |

- Content has 33,464 rows and 33,464 unique IDs. Every one of the 3,357 used IDs
  matches exactly once; 30,107 content rows are unused in this extract.
- Content IDs span `-987654322..2078179327`, proving `Int32` fits the supplied
  universe and `UInt32` is wrong.
- Used event rows split into 778,455 VOD, 101,293 live, and 25,810 with blank
  video type. Blank is retained as explicit `__unknown__`.
- There are 4,317 observed start-anchored
  `(platform,country,content_id,video_type)` combinations, making benchmark-mask
  materialization bounded on this dataset.
- Static-dimension drift versus SessionStart affects user in 120 sessions,
  platform in 95, content in one, app version in zero, and country in zero.
  Audio/subtitle/player values are genuinely stateful and must not be silently
  treated as session constants.

## Session versus user concurrency

- 775 canonical users have more than one session and 61 have overlapping
  session lifetimes.
- One synthetic user owns 301 sessions and reaches 98 simultaneous open
  sessions.

Session concurrency and distinct-user concurrency are materially different.
Distinct users must be computed by unioning a user's intervals per requested
dimension mask before boundaries are emitted.

## Verified exact versus session-independent baseline

The checked-in embedded verifier executed the full ClickHouse DDL, event-time
interval query, ten rollup masks for both session/user entities, boundary MV,
minute cache, exact bucket query, and publication gates. Under policy
`sonyliv-active-v1` with a 120s lease:

- 31,947 active intervals cover 10,848 sessions and 1,779.502796 session-hours.
- The hot `2026-07-26 10:00–11:00 UTC` exact in-minute peak is 2,305 and exact
  time-weighted average is 855.578199.
- The exact minute-boundary sample peak is 2,285. The session-independent
  heartbeat-lease estimator peaks at 3,162, with mean overcount 292 and maximum
  overcount 938 across the 60 boundaries.
- Exact endpoint query and minute cache agree. Invalid/overlapping/post-End
  intervals, negative prefix points, unbalanced days, global/platform delta
  mismatches, and content misses are all zero. Cache active-milliseconds equal
  clipped reference interval milliseconds (`6,018,191,556`) for July 26.
- A deterministic late pause at `2026-07-26 10:27:46.358 UTC` dirties exactly
  one session and emits 320 unique compensating rows (160 session, 160 user)
  with signed row sum zero. The current state table, corrected serving curve,
  and a fresh full-source rebuild each produce exactly `6,404,143,590` active
  milliseconds.
- The corrected generation passes exact per-minute parity and all full-source
  gates, changing the hot-hour result to peak 2,304 and average 855.041077.
  Republishing the same adjustment batch and rebuilding the same generation are
  both rejected; a partial-minute cache request is also rejected for exact-query
  routing.

These are correctness results from embedded ClickHouse, not target-Cloud latency
claims. The full record is `evidence/embedded-verification.json`.

## Sizing consequence

With the checked-in state machine and 120-second setting, the file yields 31,947
normalized active intervals and 63,894 interval boundaries: 14.17x fewer
contributions than raw events before timestamp/dimension aggregation. A linear
100x framing is about 90.6M raw events versus 6.39M boundary contributions.
This is a sizing proxy, not a benchmark result; real scale tests must report
`system.query_log` rows/bytes and wall latency.
