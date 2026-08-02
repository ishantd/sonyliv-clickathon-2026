# Counting real viewers, not ghosts

**Foreground-only concurrency at streaming scale**, on ClickHouse.
Submission for [Click-a-thon 2026](https://clickhouse.com/clickathon/india2026) — SonyLIV track
([problem statement](https://github.com/sidagarwal04/click-a-thon-2026/tree/main/SonyLiv)).

Counting every session between its first and last event is the obvious implementation, and on the
unseen day it is wrong by a fifth.

| Unseen day · 2026-07-31 · 7,000,000 events | |
|---|---|
| Naive, session-boundary peak | **24,069** at 11:16 UTC |
| Measured foreground peak | **19,882** at 11:15 UTC — *a different minute* |
| Overcount | **+21.1%** at peak · **+30.0%** across all session-minutes |
| Answer time | **5 ms** / **8,192 rows** (476 ms / 13,945,916 rows to recompute raw) |
| Conservation gate | `sum(opens) = sum(closes) = count()` = 163,740, ratio **1.000** |

**[fastandfurious.live](https://fastandfurious.live)** · **[chat.fastandfurious.live](https://chat.fastandfurious.live)** · **[pitch deck](pitch/pitch-deck.pdf)**

---

## Run it

Docker, and nothing else.

```bash
cp .env.example .env      # optional — every value has a working default
docker compose up         # → http://localhost:8088
```

Starts ClickHouse, applies the schema, loads the extracts if present, and brings up the ingest API,
rollup loop and dashboard, each gated on the previous. Drop `ch-hackathon-*.csv` into `./data` first
to load real data — the unseen day's `*_surprise.csv` files work unchanged. Without them the stack
still comes up and the simulator generates traffic.

```bash
docker compose --profile traffic up   # 250-session fleet
docker compose --profile mcp up       # MCP tools on :8848
docker compose down -v                # stop and drop the volume
```

Two caveats: the `mcp` profile connects as the ordinary user, so it demonstrates the tools and **not**
the security boundary; and a single node cannot exhibit any of the Cloud behaviours catalogued in
[`CLAUDE.md`](CLAUDE.md). LibreChat has its own stack
(`docker compose -f deploy/librechat/docker-compose.yml up`). For ClickHouse Cloud see
[`ingest/README.md`](ingest/README.md) and [`deploy/README.md`](deploy/README.md).

---

## The idea

Concurrency is not stored. **Edges** are. Each stretch of genuinely active viewing publishes two rows
— `+1` at its start, `−1` at its end — and concurrency is the running sum. Storage is bounded by
*sessions*, not session-minutes, so a correction is subtraction rather than a rebuild.

```
7,000,000 events → 163,740 intervals → 8,192 rows read → 5 ms
                     43× fewer          1,700× fewer      95× faster
```

"Active" is one predicate, versioned in [`solution/policy.yaml`](solution/policy.yaml) and stamped on
every published answer:

```
active = started AND NOT terminated AND foreground AND playing
         AND event_time < last_eligible_signal + 120s
```

Every clause is defended by a measurement rather than a preference —
[`docs/DECISIONS.md`](docs/DECISIONS.md) D1 has the evidence and the cost of flipping each one.

---

## Architecture

```
                     ┌──────────────────── WRITE PATH ────────────────────┐

  sonyliv-ingest  ─┐
  sonyliv-gen     ─┼──▶  events_raw  ──MV──▶  events_clean  ──┐
  sonyliv-api     ─┘     append-only          Replacing        │      ┌─ content_dict
                              │               + argMax view    ├─────▶│  33,326 titles
                              └──MV──▶ dirty_sessions ─────────┘      └─ resolved at
                                       (touched-session queue)           compaction
                                                    │
                                                    ▼
                                          active_intervals          ← stage 01
                                          163,740 rows, 7.2 MiB       13-CTE state machine
                                                    │
  ┌───────────────────── READ PATH ──────────────────┴──────────────────────────┐

  concurrency_deltas  ──MV──▶  concurrency_bucket_net  ──▶  concurrency_day_anchor
  Summing, ±1 at edges         per-bucket net              cumulative level per day
  6,435,460 rows                                                    │
            │                                                       │
            └──────────────────────┬────────────────────────────────┘
                                   ▼
                    concurrency_minute_versions      ← stage 02, the serving surface
                    1,295,876 rows · 4.3 MiB · dense minutes

  session_live_state ──▶ session_live_now             ← the live path, independent
  O(open sessions). Never touches history.
```

| | | |
|---|---|---|
| [`ingest/`](ingest/README.md) | Go on the native connector | `sonyliv-ingest`, `sonyliv-gen`, `sonyliv-api`, `sonyliv-mcp` |
| [`pipeline/sql/`](pipeline/sql) | the deployed stages | `010`/`011` intervals · `020`/`022` serving · `030` live · `040` minute tier, each with a verifier |
| [`solution/`](solution/README.md) | semantics | versioned `policy.yaml`, executable SQL, hash-locked harness |
| [`dashboard/`](dashboard/README.md) | Next.js | live, analytics, load simulator — prints each panel's SQL and cost |
| [`clickstack/`](clickstack/README.md) | observability | 6 dashboards, 5 alerts, as reviewable JSON |
| [`deploy/`](deploy/README.md) | nginx, systemd, 4 deploy scripts | LibreChat + LiteLLM, MCP as a restricted user |
| [`optimizations/`](optimizations/README.md) | 7 measured read-path rewrites | each with before/after and an equivalence check |
| [`scripts/`](scripts/README.md) | `bootstrap.sh` | empty database → verified, 7 reference-free assertions |

Design record: [`ingest/ARCHITECTURE.md`](ingest/ARCHITECTURE.md),
[`docs/TABLE-CONTRACT.md`](docs/TABLE-CONTRACT.md), and the commented DDL in
[`pipeline/sql/`](pipeline/sql).

---

## Schemas

Landing and normalisation — [`ingest/sql/`](ingest/sql):

```sql
events_raw                            -- SharedMergeTree
  content_id           Int64             PARTITION BY toYYYYMMDD(event_timestamp)
  video_session_id     String            ORDER BY (video_session_id, event_timestamp)
  user_id              String
  event_type           LowCardinality(String)     -- the only hot read is a
  event                LowCardinality(String)     -- touched-session lookup, so
  event_timestamp      DateTime64(3,'UTC')        -- session id leads the key
  platform, app_version, country, audio_language,
  subtitle_language, player_version, video_resolution   LowCardinality(String)
  session_start_epoch  DateTime64(3,'UTC')
  session_key, user_key  UInt64          -- cityHash64 of the string ids
  _ingested_at         DateTime64(3,'UTC')     -- provenance: which batch, which
  _source_file         LowCardinality(String)  -- file, which row within it
  _ingest_batch_id     UUID
  _batch_row_seq       UInt32

events_clean                          -- SharedReplacingMergeTree(row_version)
  session_key          UInt64            PARTITION BY toYYYYMMDD(session_start_ts)
  event_ts             DateTime64(3,'UTC')  ORDER BY (session_key, event_ts,
  event_type           LowCardinality(String)         event_type, event)
  event                LowCardinality(String)
  …same dimensions, normalised…
  signal   Enum8('liveness','session_start','session_end','play','pause',
                 'resume','background','foreground','error')
  is_periodic_ping     Bool
  row_version          UInt64
```

`signal` is the load-bearing column — pause and resume exist only as lowercase values inside
`event_type = 'VideoHeartbeat'`, among 42 event names, so the state machine reads `event`, never
`event_type`. Queried through an `argMax` view, so no `FINAL` on the hot path.

Intervals — [`pipeline/sql/010_active_intervals.sql`](pipeline/sql/010_active_intervals.sql):

```sql
active_intervals                      -- SharedMergeTree
  policy_version   LowCardinality(String)  ORDER BY (policy_version, clip_variant,
  clip_variant     Enum8('unclipped','clipped')      session_key, start_time)
  session_start_date  Date
  session_key, user_key  UInt64
  interval_index   UInt16
  start_time       DateTime64(3,'UTC')     -- half-open [start, end)
  end_time         DateTime64(3,'UTC')
  content_id       Int64                   -- dimensions denormalised here, so the
  platform, country, video_type            -- serving layer never joins
                   LowCardinality(String)
  state_revision   UInt64                  -- resolved by argMax; an uncommitted
  built_at         DateTime64(3,'UTC')     -- higher revision stays invisible
```

Serving — [`020_serving_layer.sql`](pipeline/sql/020_serving_layer.sql),
[`040_concurrency_minute.sql`](pipeline/sql/040_concurrency_minute.sql):

```sql
concurrency_deltas                    -- SharedSummingMergeTree((opens, closes))
  policy_version   LowCardinality(String)  ORDER BY (policy_version, clip_variant,
  clip_variant     Enum8(…)                  rollup_mask, platform, country,
  rollup_mask      UInt16                    content_id, video_type, boundary_ts)
  platform, country, video_type
                   LowCardinality(String)  -- mask ahead of the dimensions: one
  content_id       Int64                   -- combination = one contiguous range
  boundary_ts      DateTime64(3,'UTC')
  opens, closes    UInt32                  -- explicit column list; a bare one
                                           -- would sum your dimensions

concurrency_bucket_net   …same key…, bucket DateTime('UTC'), opens/closes/n_deltas UInt64
concurrency_day_anchor   …same key…, day Date, level Int64   -- cumulative level per
                                                             -- day: no read from t=0

concurrency_minute_versions           -- SharedMergeTree
  generation       UInt64                PARTITION BY toYYYYMMDD(service_date)
  policy_version, clip_variant           ORDER BY (generation, policy_version,
  pipeline_run_id  UUID                    clip_variant, pipeline_run_id,
  source_delta_snapshot  UInt128           source_delta_snapshot, entity,
  entity           Enum8('session','user') rollup_mask, service_date, platform,
  rollup_mask      UInt16                  country, video_type, content_id,
  service_date     Date                    minute_start)
  minute_start     DateTime64(3,'UTC')
  platform, country, video_type, content_id
  minute_peak         UInt64              -- exact max inside the minute
  active_entity_ms    UInt64              -- for the time-weighted average
  ending_concurrency  UInt64
  source_boundary_points  UInt64
```

`generation` leads so an old generation stays byte-stable while a new one is built beside it. Hour and
day grain are `max(minute_peak)` and `sum(active_entity_ms) / duration` over the same rows.

Live — [`030_session_live_now.sql`](pipeline/sql/030_session_live_now.sql):

```sql
session_live_state                    -- SharedAggregatingMergeTree
  policy_version   LowCardinality(String)  ORDER BY (policy_version, session_key)
  session_key      UInt64                  -- exactly one row per session
  state_revision   SimpleAggregateFunction(max, UInt64)
  lease_expiry     AggregateFunction(argMax, DateTime64(3,'UTC'), UInt64)
  is_active_now    AggregateFunction(argMax, UInt8, UInt64)   -- argMaxIf, so a
  is_terminated    AggregateFunction(argMax, UInt8, UInt64)   -- heartbeat-only
  open_interval_start, user_key, content_id,                  -- block cannot
  platform, country, video_type                               -- clobber an
                   AggregateFunction(argMax, …, UInt64)       -- earlier state
```

Supporting: `content_dim` (`content_id`, `title`, `video_type`, `category`, `show_name`) behind the
`content_dict` dictionary, and `dirty_sessions` — the touched-session queue, ordered
`(session_start_date, session_key, last_ingested_at, ingest_batch_id)`.

Throughout: `DateTime64(3,'UTC')` end to end, UTC stored and IST rendered only at display;
`LowCardinality` for every categorical; signed `Int64` content ids, because the catalogue contains a
negative id cast to unsigned; explicit sentinels rather than blanket `Nullable`.

---

## How we avoid full scans

1. **The mask is in the sort key.** Nine combinations materialised (`0,1,2,3,4,5,8,9,15`); one
   combination reads one contiguous granule range. Peak is computed *after* aggregating — never by
   summing per-dimension peaks, which land on different minutes.
2. **Day anchors, so no read starts at `t = 0`.** A prefix sum from epoch is a full scan by
   construction and nothing prunes it. Measured here: a 30-second predicate on `events_clean` still
   read **92.6%** of the table, because `event_ts` is not the key prefix.
3. **Dense minutes, no cumulative sum at read.** Whole-day peak *and* time-weighted average is one
   `max()` and one `sum()` over 8,192 rows.
4. **Enrichment at write time.** `video_type` resolved during compaction and denormalised into the
   interval rows; the build asserts enrichment resolved before it writes.
5. **Aggregate projections where the engine allows them** — 9 of 22 MergeTree tables;
   `deduplicate_merge_projection_mode` is `throw` on Replacing/Summing/Aggregating.
   [`optimizations/sql/020_projections.sql`](optimizations/sql/020_projections.sql).

The live path sidesteps the problem entirely: `session_live_now` filters
`last_event_ts > now() − 120s`, so a quiet session falls out of the `WHERE` clause and **nothing is
written when a viewer stops** — the hard part, since ClickHouse has no primitive that fires on absence.

---

## Updates without rebuilds

A still-live interval is published with a **provisional** end at the lease expiry; the next heartbeat
re-derives the session and publishes the difference —
`correction(t) = new_boundary_map(t) − old_boundary_map(t)`. No `ALTER UPDATE`, no `ALTER DELETE`, no
scheduled `OPTIMIZE FINAL` anywhere.

It mattered: the tuning extract had zero open sessions, while the unseen day had **37,649 that never
end (34.7%)** and **25,403 already running** when the window opened. Both absorbed with zero rebuilds.

---

## Verification

**A check that only inspects one layer cannot validate that layer.** A doubled Summing curve passes
`sum(net) = 0`, `min(running) = 0` and `opens = closes` — every internal invariant stays green at
exactly twice the peak. So each stage compares against its *input*, and no gate contains a number from
the tuning day.

```bash
./scripts/bootstrap.sh                       # 7 reference-free assertions
cd ingest && make check                      # Go tests + vet + gofmt
python3 solution/tools/verify_embedded.py    # hash-locked correctness harness
```

> **Known divergence.** The older `sonyliv_unseen` builder reports **14,506** for the same minute: it
> keeps 0 of the 25,403 sessions that have no `VideoSessionStart`, and that is the entire gap.
> `sonyliv` is the submission.

---

## Integrations

All three, over the same serving layer — setup and verification in
[`deploy/README.md`](deploy/README.md).

- **ClickStack** — observes the pipeline itself: one trace from `replay.read` to
  `generation.publish`, six dashboards, five alerts. Viewer-drop is measured against each slice's own
  trailing median, not a global threshold.
- **LibreChat + [`sonyliv-mcp`](ingest/cmd/sonyliv-mcp/README.md)** — reaches ClickHouse only as a
  restricted user with `SELECT` on eight aggregate objects and nothing carrying `user_id`. Asked for a
  person it refuses, and the grant enforces that, not the prompt. This integration is *why* the flat
  minute tier exists: an LLM reliably writes `max(minute_peak) … WHERE minute_start BETWEEN …`.
- **Langfuse** — versioned source of truth for the analyst prompt, rendered at deploy time, failing
  closed. Model calls route through LiteLLM, so every turn and tool call is traced.

At 100× the serving tier grows with **dimensions × minutes**, not events — 1,440 minutes × nine masks
is the same shape at 1× and at 100×. What grows is the interval build, a partitioned per-day
restartable job rather than a query anyone waits on.

---

## Submission

Per [`SONYLIV_SUBMISSION_GUIDELINES.md`](https://github.com/sidagarwal04/click-a-thon-26-submissions/blob/main/SONYLIV_SUBMISSION_GUIDELINES.md).
The concurrency curve, the six dataset filters and per-panel cost evidence are all in the product UI
at **`/analytics`** — see
[`dashboard/README.md`](dashboard/README.md#analytics--the-submission-surface).

| Item | Where |
|---|---|
| Working project, MIT, public | this repo |
| Pitch deck (≤15 slides, ≤20 MB) | [`pitch/pitch-deck.pdf`](pitch/pitch-deck.pdf) — 14 slides, 1.5 MB |
| Live demo · conversational layer | [fastandfurious.live](https://fastandfurious.live) · [chat.fastandfurious.live](https://chat.fastandfurious.live) |
| Unseen-day answers, latencies, evidence | `/analytics` and [`05-benchmark-answers.json`](clickstack/dashboards/05-benchmark-answers.json) |
| Solution summary (≤500 words) | _pending_ |
| Demo video (≤5 min) | _pending_ |

**Team.** _TBD_

**Service.** `sonyliv` · ClickHouse Cloud 26.2 · aws ap-south-1 · 2 replicas. Everything quoted here
was measured there.

## License

[MIT](LICENSE).
