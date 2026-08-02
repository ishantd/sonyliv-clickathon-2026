# Counting real viewers, not ghosts

**Foreground-only concurrency at streaming scale**, on ClickHouse.
Submission for [Click-a-thon 2026](https://clickhouse.com/clickathon/india2026) — SonyLIV track.
Problem statement: [sidagarwal04/click-a-thon-2026 · SonyLiv](https://github.com/sidagarwal04/click-a-thon-2026/tree/main/SonyLiv).

Counting every session between its first and last event is the obvious implementation, and on the
unseen day it is wrong by a fifth. Phones get pocketed, players get paused, streams stall — all of it
keeps a session technically open and none of it is an audience.

| | On the unseen day (2026-07-31, 7,000,000 events) |
|---|---|
| Naive, session-boundary peak | **24,069** at 11:16 UTC |
| Measured foreground peak | **19,882** at 11:15 UTC — *a different minute* |
| Overcount | **+21.1%** at peak, **+30.0%** across all session-minutes |
| Answer time | **5 ms** reading **8,192 rows** (476 ms and 13,945,916 rows to recompute it raw) |
| Conservation gate | `sum(opens) = sum(closes) = count()` = **163,740**, ratio **1.000** |

Live: **[fastandfurious.live](https://fastandfurious.live)** (the curve) ·
**[chat.fastandfurious.live](https://chat.fastandfurious.live)** (ask it in English) ·
**[pitch/pitch-deck.pdf](pitch/pitch-deck.pdf)** (14 slides).

---

## Run it

Docker, and nothing else. No Go, no Node, no ClickHouse install, no account.

```bash
cp .env.example .env      # optional — every value has a working default
docker compose up
```

Then open **http://localhost:8088**.

That one command starts ClickHouse, creates the database, applies the full schema,
loads the extracts if you have them, and brings up the ingest API, the rollup loop
and the dashboard — each gated on the previous finishing.
[`.env.example`](.env.example) documents every knob; the ones worth knowing are
`CH_DATABASE`, `DASHBOARD_PORT` and `DATA_DIR`.

**Loading the supplied extracts** is optional. Drop either or both into `./data`
before `docker compose up`:

```
data/ch-hackathon-content-data.csv     the catalogue   ~1.4 MB
data/ch-hackathon-raw-data.csv         the events      ~1.8 GB
```

The unseen day's files work unchanged — the loader globs the prefix, so
`*_surprise.csv` is picked up with no config change. Measured on a laptop, from an
empty volume: **7,000,000 events in 1 m 10 s at 100,295 rows/s**, 0 retries, after
which the rollup builds all 17 days of the serving layer — 992,811 minute rows for
31 July alone — in **6.9 s**, peaking at 14,506 at 11:15. That is the *local
builder's* answer; the deployed `sonyliv` pipeline reports **19,882** for the same
minute, and the two differ for a known reason — see the note under
[Verification](#verification).

With no CSVs the stack still comes up, and that is a working demo rather than a
degraded one: create a fleet on `/fleet/new` and the curve builds from the
simulator's own traffic, which is closer to what the product is for.
`--profile traffic` starts one for you. If you load only one file, load the
catalogue — without it every session resolves to `__unknown__` and the title,
category and content-type panels collapse to a single bar.

```bash
docker compose --profile traffic up      # start a 250-session fleet immediately
docker compose --profile mcp up          # serve the MCP tools over HTTP on :8848
docker compose logs -f rollup            # watch the serving layer build
docker compose down -v                   # stop, and delete the ClickHouse volume
```

Two things this stack deliberately does not reproduce. The `mcp` profile connects
as the same user as everything else, so it demonstrates the tools and **not** the
security boundary — the real deployment connects as `sonyliv_mcp`, which cannot
read `events_clean` or `session_intervals` at all
([`ingest/sql/manual/009_mcp_reader.sql`](ingest/sql/manual/009_mcp_reader.sql)).
And it is a single node, so none of the ClickHouse Cloud behaviours in
[`CLAUDE.md`](CLAUDE.md) — per-replica dictionary loads, SharedMergeTree
substitution, projections blocked on Replacing tables — can appear here. Treat
what runs locally as correct, not as evidence about how it behaves in Cloud.

LibreChat is not in this compose file: it needs an LLM key, and a chat window that
cannot reach a model is worse than an absent one. It has its own stack —
`docker compose -f deploy/librechat/docker-compose.yml up`, with
[`deploy/librechat/.env.example`](deploy/librechat/.env.example) as the guide.

To run natively against ClickHouse Cloud instead — which is what the hosted demo
does — see [`ingest/README.md`](ingest/README.md) and
[`deploy/README.md`](deploy/README.md).

---

## The shape of the answer

Concurrency is not stored. **Edges** are.

Each stretch of genuinely active viewing publishes exactly two rows — `+1` at its start, `−1` at its
end — and concurrency at any instant is the running sum. Storage is therefore bounded by *sessions*,
never by session-minutes, and a correction becomes subtraction instead of a rebuild.

```
7,000,000 events  →  163,740 intervals  →  8,192 rows read  →  5 ms
                        43× fewer            1,700× fewer        95× faster
```

An active interval is defined by one predicate, versioned in
[`solution/policy.yaml`](solution/policy.yaml) and stamped onto every published answer:

```
active = started AND NOT terminated AND foreground AND playing
         AND event_time < last_eligible_signal + 120s
```

Every clause is defended by a measurement, not a preference. Liveness qualifies on **any** event
rather than the periodic heartbeat trio, because 58.6% of iPhone and 63.6% of Apple TV sessions never
emit the trio at all — a trio-based rule returns a plausible number with most Apple traffic silently
missing. Pause counts as inactive because the brief asks for *"truly active playback intervals"*, and
a paused stream serves no ads. The 120 s lease is three missed 40 s ticks; it falsely splits about
0.2% of continuous playback, and 180 s would add a full minute of phantom viewing after every real
stop to recover a few hundredths of a point.

---

## Architecture

Two questions, two structures. Conflating them is the mistake the design exists to avoid.

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

### The components

| Component | What it is | Why it exists |
|---|---|---|
| [`ingest/`](ingest/README.md) | Go on the ClickHouse native connector — `sonyliv-ingest` (CSV loader), `sonyliv-gen` (calibrated event generator), `sonyliv-api` (write path + read API), `sonyliv-mcp` (MCP server) | Deterministic native blocks, all three dedup windows pinned, and a batch ledger so a retry is auditable |
| [`pipeline/`](pipeline/sql) | The deployed SQL stages: `010`/`011` intervals, `020`/`022` serving, `030` live, `040` minute tier, each with its verifier | This is the pipeline. Everything else supports it |
| [`solution/`](solution/README.md) | Versioned `policy.yaml`, executable SQL, and a hash-locked correctness harness | The semantics live in a file, not in comments |
| [`dashboard/`](dashboard/README.md) | Next.js — live, analytics, load simulator. Prints the SQL and the cost of every panel | The brief's "minimal visualisation", plus the evidence-of-cost requirement |
| [`clickstack/`](clickstack/README.md) | 6 dashboards, 5 alerts, 4 sources — created through the API as reviewable JSON, not clicked together | Observes the pipeline itself; `check-tiles.sh` runs every tile's SQL |
| [`deploy/`](deploy/README.md) | nginx, systemd units, and four deploy scripts — one per thing with its own cadence | LibreChat + LiteLLM over Compose, MCP as a restricted ClickHouse user |
| [`optimizations/`](optimizations/README.md) | Seven measured read-path rewrites, each with before/after and an equivalence check | Handover artifacts for clients outside this repo |
| [`scripts/`](scripts/README.md) | `bootstrap.sh` — empty database to a verified one, seven reference-free assertions | One command, Python stdlib over HTTPS |

Full design record and the measurements behind each choice:
[`ingest/ARCHITECTURE.md`](ingest/ARCHITECTURE.md), [`docs/TABLE-CONTRACT.md`](docs/TABLE-CONTRACT.md),
and the heavily-commented DDL in [`pipeline/sql/`](pipeline/sql).

---

## Schemas, and the reasoning in the sort keys

Every sort key below is chosen against a specific read. None of them is a default.

| Table | Engine | `ORDER BY` | The read it serves |
|---|---|---|---|
| `events_raw` | SharedMergeTree, partitioned `toYYYYMMDD(event_timestamp)` | `video_session_id, event_timestamp` | The **only** hot read is a touched-session history lookup. Session ID leads despite high cardinality because no dashboard ever reaches this table |
| `events_clean` | SharedReplacingMergeTree, partitioned `toYYYYMMDD(session_start_ts)` | `session_key, event_ts, event_type, event` | Same access shape, deduplicated. Read through an `argMax` view so it is correct whether or not a merge has run — **no `FINAL` on the hot path** |
| `content_dim` → `content_dict` | SharedReplacingMergeTree → hashed Dictionary | `content_id` | 33,326 titles resolved **once at compaction**, denormalized into the interval rows. The serving layer never joins |
| `dirty_sessions` | SharedMergeTree | `session_start_date, session_key, last_ingested_at, ingest_batch_id` | The incremental work queue: which sessions an insert touched |
| `active_intervals` | SharedMergeTree | `policy_version, clip_variant, session_key, start_time` | Policy and variant lead so a whole slice is one contiguous range; session leads within it for the correction lane |
| `concurrency_deltas` | SharedSummingMergeTree | `policy_version, clip_variant, rollup_mask, platform, country, content_id, video_type, boundary_ts` | **The mask is in the key**, so asking for one dimension combination reads one contiguous range and nothing else |
| `concurrency_bucket_net`<br>`concurrency_day_anchor` | SharedSummingMergeTree<br>SharedReplacingMergeTree | same prefix, then `bucket` / `day` | Checkpoints, so a window read starts at the nearest anchor instead of `t = 0` |
| `concurrency_minute_versions` | SharedMergeTree, partitioned `toYYYYMMDD(service_date)` | `generation, policy_version, clip_variant, …, rollup_mask, service_date, …, minute_start` | The flat serving surface. Generation leads so an old generation stays byte-stable while a new one is built beside it |
| `session_live_state` | SharedAggregatingMergeTree | `policy_version, session_key` | One row per session, `argMaxIf` states. O(open sessions), never history |

**Types.** `DateTime64(3,'UTC')` end to end — source timestamps are epoch milliseconds, normalized once
at the boundary. UTC everywhere; `Asia/Kolkata` rendering happens only in the consuming query.
`LowCardinality(String)` for every categorical dimension, signed `Int64` content ids (the catalogue
contains a negative id cast to unsigned), explicit `__unknown__` sentinels instead of blanket
`Nullable`.

---

## How we avoid full scans

This is the whole game. Five mechanisms, each measured:

**1. The mask is part of the sort key.** `concurrency_deltas` and `concurrency_minute_versions` both
carry `rollup_mask` in the `ORDER BY`, ahead of the dimensions. A query for one combination reads one
contiguous granule range. Nine masks are materialised — `0,1,2,3,4,5,8,9,15` — and peak is always
computed *after* aggregating the requested combination, never by summing per-dimension peaks, which
land on different minutes.

**2. Checkpoints, so no read starts at `t = 0`.** A prefix sum from epoch is a full scan by
construction, and no sort key, skip index or projection prunes it. `concurrency_bucket_net` and
`concurrency_day_anchor` hold the cumulative level at each day boundary, so a window read costs
O(checkpoints before the window) + O(deltas inside it). Measured on this service: a 30-second window
predicate against `events_clean` still read **834,364 of 901,348 rows (92.6%)**, because `event_ts` is
not the sort-key prefix. That is what "incremental over a time predicate" actually costs.

**3. A dense minute tier with no cumulative sum at read time.** `concurrency_minute_versions` stores
`minute_peak` and `active_entity_ms` per minute, so a whole-day peak *and* time-weighted average is a
`max()` and a `sum()` over 8,192 rows — **5 ms**. Hour and day grain are `max(minute_peak)` and
`sum(active_ms) / duration` over the same rows.

**4. Enrichment at write time, not read time.** `video_type` is resolved from the dictionary during
compaction and denormalized into the interval rows, so no serving query joins anything. The build
asserts enrichment resolved before it writes — a dimension that is 100% fallback is a failure, not a
data characteristic.

**5. Aggregate projections where the engine allows them.** An `IN (SELECT … GROUP BY …)` subquery
takes no predicate pushdown, so `active_intervals_current` read 96,662 rows to return 31,947 on the
tuning data. An aggregate projection whose body is exactly that subquery is substituted for it:
`Granules 8/8` becomes `Granules 3/8`. Only the classic `SharedMergeTree` tables are eligible — **9 of
the 22** MergeTree tables in `sonyliv` today, because `deduplicate_merge_projection_mode` is `throw` on
Replacing/Summing/Aggregating, and a `SELECT … FINAL` cannot use a projection at all. See [`optimizations/sql/020_projections.sql`](optimizations/sql/020_projections.sql).

**And the live path avoids the problem entirely.** `session_live_now` filters
`last_event_ts > now() − 120s`, so a session that goes quiet simply falls out of the `WHERE` clause.
**Nothing has to be written when a viewer stops** — which is the hard part, because ClickHouse has no
primitive that fires on absence. Cost is O(open sessions), identical on day 1 and day 300.

---

## Updates without rebuilds

An interval whose session is still live is published with a **provisional** end at the lease expiry.
When the next heartbeat lands the session is re-derived and the pipeline publishes the *difference*:

```
correction(t) = new_boundary_map(t) − old_boundary_map(t)
```

`+1` at the old expiry, `−1` at the new one. A late pause retracts its own tail. No `ALTER UPDATE`, no
`ALTER DELETE`, no scheduled `OPTIMIZE FINAL` anywhere in the pipeline — every change to a published
answer is an additive, signed row.

This mattered more than expected. On the tuning extract every one of 10,866 sessions had a Start and
an End, so the open-session problem could only be simulated. The unseen day supplied it for real:
**37,649 sessions that never end (34.7%)** and **25,403 that were already running** when the window
opened. Both were absorbed with zero rebuilds.

---

## Verification

The rule the whole harness is built on: **a check that only inspects one layer cannot validate that
layer.** A doubled Summing curve passes `sum(net) = 0`, `min(running) = 0` and `opens = closes` — every
internal invariant stays green at exactly twice the peak. So every stage carries a conservation check
against its *input*:

```sql
-- 022_populate_serving.sql, V0 — reference-free, throws with the ratio
sum(opens) in concurrency_deltas  ==  count() in active_intervals_current
```

No gate contains a number from the tuning day. Gates that did were found and removed — had they
survived, every one would have fired on *correct* unseen-day output and blocked the run, because
19,882 is not 2,305.

```bash
./scripts/bootstrap.sh              # empty database → verified, 7 reference-free assertions
cd ingest && make check             # Go tests + vet + gofmt
python3 solution/tools/verify_embedded.py   # hash-locked correctness + correction harness
```

> **Known divergence.** `sonyliv_unseen`, the older serving builder behind some dashboard views,
> reports **14,506** for the same minute. It drops all 25,403 sessions that have no
> `VideoSessionStart`; the `sonyliv` pipeline infers their state and keeps them. `sonyliv` is the
> submission.

---

## Open-source integrations

All three, over the same serving layer. Setup in [`deploy/README.md`](deploy/README.md).

- **ClickStack** — observes the pipeline itself. One trace spans
  `replay.read → raw.insert → session.normalize → boundary.correct → minute.build →
  generation.validate → generation.publish`, carrying `run_id`, source SHA, policy version, ingest-lag
  quantiles, correction backlog, read rows/bytes and the answer hash. Six dashboards and five alerts,
  created through the API as reviewable JSON. Viewer-drop is measured against each slice's own trailing
  15-minute median, not a global threshold. Deliberately **not** alerted: "any late event" — lateness is
  this stream's baseline, and an alert that always fires is not an alert.
- **LibreChat + `sonyliv-mcp`** — an analyst over the serving tables. It reaches ClickHouse only through
  an MCP server connected as a **restricted user** with `SELECT` on eight aggregate objects and nothing
  carrying `user_id`. Asked for a person, it refuses, and the refusal is enforced by the grant rather
  than the prompt. This integration is also *why* `concurrency_minute_versions` exists: an LLM reliably
  writes `max(minute_peak) … WHERE minute_start BETWEEN …`, and will not reliably write a day-anchored
  cumulative sum over millisecond boundaries.
- **Langfuse** — the versioned source of truth for the analyst's system prompt, rendered in at deploy
  time and failing closed if it cannot be read. Model calls route through a LiteLLM sidecar, so every
  turn, tool call, latency and token count is traced.

---

## Scale

The provided data is a scaled-down proxy. At 100× — ~700 M events a day, ~10.8 M sessions, ~16.4 M
intervals — the serving tier grows with **dimensions × minutes**, not with events: 1,440 minutes × nine
masks is the same shape at 1× and at 100×. What grows is the interval build, and that is a partitioned,
per-day, restartable job rather than a query anyone waits on.

---

## SonyLIV track requirements

Per [`SONYLIV_SUBMISSION_GUIDELINES.md`](https://github.com/sidagarwal04/click-a-thon-26-submissions/blob/main/SONYLIV_SUBMISSION_GUIDELINES.md).
All of this is in the product UI at **`/analytics`**, not only in a screenshot —
see [`dashboard/README.md`](dashboard/README.md#analytics--the-submission-surface).

**1. Concurrency curve.** Concurrent foreground sessions per minute, over a
selectable window, computed from the dataset in the problem statement and read
from the minute serving tier. Two series — the exact maximum inside each minute
and the time-weighted average. The default window is the 31 July match window
(10:20–11:35 UTC), a full ramp to the peak and the drain after it. The ClickHouse statement that produced the chart is displayed under the
chart itself, in runnable form, with the bound parameters; it is returned by the
server with the result, so it cannot drift from the query that ran.

**2. Dataset filters.** Six, applied to the curve and to every other view on the
page:

| filter | dataset column it is backed by |
|---|---|
| Platform | `events.platform` |
| Country | `events.country` |
| Content type | `content_dim.video_type`, joined on `events.content_id` |
| Category | `content_dim.category`, joined on `events.content_id` |
| App version | `events.app_version` |
| Title | `content_dim.title`, joined on `events.content_id` |

The filter set selects which pre-aggregated rollup answers the question. Where no
rollup is materialised at exactly that combination, viewer-hours stays exact and
the **peak is withheld rather than estimated** — a maximum over a finer grain is
the busiest single combination, not the peak of the slice asked for. The UI says
which rollup answered, and why, on every panel.

**3. Evidence of cost.** Every panel prints what its query actually cost —
ClickHouse execution time, rows read, bytes scanned — from the driver's progress
counters. The unfiltered day curve reads 8,192 rows; recomputing the same answer
from the event stream reads 13,945,916.

## Team

| Role | Name | GitHub |
|---|---|---|
| Team Captain | | |
| Member | | |
| Member | | |
| Member | | |

Team name (as registered): _TBD_
Track: _TBD — confirmed once the problem statement is revealed_

## Submission

| Item | Where |
|---|---|
| Working project, MIT-licensed, public | this repo |
| Pitch deck (≤15 slides, ≤20 MB) | [`pitch/pitch-deck.pdf`](pitch/pitch-deck.pdf) — 14 slides, 1.5 MB |
| Live demo | [fastandfurious.live](https://fastandfurious.live) |
| Conversational layer | [chat.fastandfurious.live](https://chat.fastandfurious.live) |
| Unseen-day answers, latencies, pipeline evidence | `/analytics`, and [`clickstack/dashboards/05-benchmark-answers.json`](clickstack/dashboards/05-benchmark-answers.json) |
| Solution summary (≤500 words) | _pending_ |
| Demo video (≤5 min) | _pending_ |

**Service.** `sonyliv` · ClickHouse Cloud 26.2 · aws ap-south-1 · 2 replicas.
Everything quoted in this README was measured there, not inferred.

## License

[MIT](LICENSE).
