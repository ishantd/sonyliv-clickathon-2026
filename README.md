# Fast and Furious

<!-- DRAFT — Sid to confirm: team name as registered, project name/tagline, demo video link,
     pitch deck filename, LibreChat judge password, Langfuse share links.
     Everything else below is verified against the live service unless marked otherwise. -->

## Track

**SonyLIV** — *Counting the crowd: foreground-only concurrency at streaming scale.*

## Project

**Foreground** — count only the people who are actually watching, at any grain, in one query.

## Team Members

- Siddhartha Mishra ([@SiddharthaMishra](https://github.com/SiddharthaMishra))
- Ishant Dahiya ([@ishantd](https://github.com/ishantd))

## What it does

A session that is open is not a session that is watching. Someone who backgrounds the app
during an ad break, or whose phone drops off the network mid-over, still has a live session
row — and counting it inflates the number the business makes ad-load and capacity decisions
on.

This system computes concurrency over **only the truly active intervals** inside each
session, and serves peak and average at minute / hour / day grain, filtered across every
dimension the dataset provides, without ever rescanning raw history.

The shape of it:

1. **Events land verbatim.** `events_raw` is append-only and never rewritten, so the
   duplicate rate stays measurable and any normalization rule stays correctable after the
   fact. Deduplication and normalization happen one layer up, in `events_clean`.
2. **Sessions become intervals.** A per-session state machine walks the event stream and
   emits an array of `(start_time, end_time)` foreground intervals — closing on
   `AppBackgrounded`, on `VideoSessionEnd`, and on heartbeat silence past a measured grace
   window. One row per session, not one row per minute.
3. **Intervals become a minute serving layer.** Intervals are rolled up into
   `serving_concurrency_minute`, which carries `minute_peak`, `active_ms` and
   `ending_concurrency` per (minute × dimension combination). Dashboards read this and
   nothing else.
4. **Updates are incremental.** A materialized view marks touched sessions into
   `dirty_sessions`; the compactor rebuilds only those sessions' intervals and republishes
   only the minutes they touch. An open session that keeps heartbeating is re-derived, not
   rebuilt from scratch, and a late arrival is a correction rather than a full pass.

The invariant the whole design turns on:

> `active_ms` is additive everywhere. `ending_concurrency` is additive across dimensions at
> one instant. **A peak is additive across nothing.**

A peak is only exact at its own grouping. Taking `max(minute_peak)` over a finer grain and
then `GROUP BY platform` gives you the busiest single *(platform, title)* pair, not the
platform's peak — measured on the tuning extract, `ANDROID_PHONE` peaks at 10:55 while
`SONY_ANDROID_TV` peaks at 10:53, so adding those two bars is arithmetic across two
different instants. That is why the serving layer stores each dimension combination as its
own pre-aggregated rollup rather than expecting the query to slice a finer one.

## Hosted Demo

**https://fastandfurious.live**

| Surface | URL | What it shows |
|---|---|---|
| Analytics | https://fastandfurious.live/analytics/ | The concurrency curve, exact peak by platform, title / category / content-type leaderboards, serving-layer freshness |
| Live | https://fastandfurious.live/live/ | Real-time curve as sessions open, heartbeat and close — with the dimension filters applied |
| Create | https://fastandfurious.live/fleet/new/ | Spin up a synthetic fleet at a target concurrency and watch it land |
| Sessions | https://fastandfurious.live/fleet/ | Per-session inspection: raw events in, intervals out |
| Stepper | https://fastandfurious.live/manual/ | Emit one event at a time and watch the state machine move |
| Analyst | https://chat.fastandfurious.live | LibreChat over the serving layer, via a restricted MCP server |

A **dataset picker** in the nav switches every read between two ClickHouse databases:

| Dataset | Database | Contents |
|---|---|---|
| Mock ingestion | `sonyliv_prod` | The tuning extract plus everything the simulator has generated. Writable. |
| Evaluation set — 31 Jul | `sonyliv_unseen` | The sealed unseen day, exactly as loaded. **Read-only.** |

Reads follow the picker; writes cannot. The write paths never read a `db` parameter at all,
so there is no code path that could point ingestion at the evaluation set. The allowlist
lives in Go ([`ingest/internal/mock/analytics.go`](ingest/internal/mock/analytics.go))
because the database name is interpolated into SQL as a schema identifier, which cannot be
a bound parameter — an allowlist is the only safe mechanism. `?db=system` returns HTTP 400.

**Judge credentials for LibreChat** — see [Test credentials](#test-credentials).

## Demo Video

_TBD — 2–3 minutes, linked here before freeze._

## Concurrency curve

Rendered live in the product at [`/analytics/`](https://fastandfurious.live/analytics/) and
[`/live/`](https://fastandfurious.live/live/), not as a static image.

The unfiltered curve is a single scan of the pre-aggregated minute layer:

```sql
SELECT
    toString(minute_start)          AS minute,
    toUInt32(minute_peak)           AS peak,
    round(active_ms / 60000.0, 3)   AS average
FROM sonyliv_unseen.serving_minute_current
WHERE grouping = 'total'
  AND minute_start >= toDateTime({from:String}, 'UTC')
  AND minute_start <  toDateTime({to:String},   'UTC')
ORDER BY minute_start
```

Two series, because they answer different questions and the gap between them is the whole
point of the problem: over the tuning extract's hot hour the peak is **2,305** while the
time-weighted average is **855.58**. A chart showing only one invites the other to be
inferred from it.

`average` is `active_ms / 60000` — the conserved measure — rather than an average of the
per-minute counts. The counts are any-overlap, so averaging them overstates a minute in
which sessions came and went.

`grouping = 'total'` is load-bearing. The minute layer holds eleven overlapping
aggregations of the same traffic; summing across them measures 9,411.64 where the truth is
855.58.

**Peak by dimension value**, with the grouping chosen to match the question:

```sql
SELECT
    dim_values                                   AS platform,
    toUInt32(max(minute_peak))                   AS peak,
    toString(argMax(minute_start, minute_peak))  AS peaked_at,
    round(sum(active_ms) / 3600000.0, 3)         AS viewer_hours
FROM sonyliv_unseen.serving_minute_current
WHERE grouping = 'platform'
  AND minute_start >= toDateTime({from:String}, 'UTC')
  AND minute_start <  toDateTime({to:String},   'UTC')
GROUP BY platform
ORDER BY peak DESC
```

**Hour and day grain** roll up from the same minute rows — `max(minute_peak)` over the
window for the peak, `sum(active_ms) / 3600000` for the hour's time-weighted average — so
there is no separate hour or day table to keep consistent with the minute one.

Every panel's SQL is in [`ingest/internal/mock/analytics.go`](ingest/internal/mock/analytics.go);
the serving-layer DDL is in [`ingest/sql/007_serving_concurrency.sql`](ingest/sql/007_serving_concurrency.sql).

## Dataset filters

Every filter maps to a real dataset column, and each is served by its own pre-aggregated
rollup rather than by slicing a finer one. The rollup a query needs is selected by a bitmask
(`rollup_mask`); the `serving_minute_current` view exposes it as the friendlier `grouping`
string.

| UI filter | Dataset column | Source file | Mask bit | `grouping` |
|---|---|---|---|---|
| Platform | `platform` | raw events | 1 | `platform` |
| Country | `country` | raw events | 2 | `country` |
| Content / title | `content_id` → `title` | raw events → content metadata | 4 | `content` |
| Video type | `video_type` | content metadata | 8 | `video type` |
| App version | `app_version` | raw events | 16 | `app_version` |
| Category | `category` | content metadata | 32 | `category` |
| Time grain | `event_timestamp` | raw events | — | `minute_start` |
| (unfiltered) | — | — | 0 | `total` |

`content_id` resolves to `title` / `video_type` / `category` / `show_name` through a
ClickHouse `DICTIONARY` over the content table. Measured against the alternatives: dictionary
40,960 rows / 560 KiB / 7 ms; `JOIN` 74,424 rows / 1.09 MiB / 24 ms; a `dictHas` + `JOIN`
hybrid **28 ms** — the "lazy" option is the worst of the three, because ClickHouse builds the
join side unconditionally.

The filters are exposed in the product on `/live/` (content id, video type, platform, app
version, country) and as the grouped panels on `/analytics/`. They apply to the concurrency
curve itself, not only to the tables beside it.

### Columns deliberately **not** given a mask bit

A dimension can only carry a pre-aggregated peak if it is constant for the whole session —
otherwise one session belongs to two buckets at once and the rollup double-counts. We
measured each candidate rather than guessing:

| Column | Sessions that change it mid-session | Decision |
|---|---|---|
| `audio_language` | 8,796 | Filterable at interval grain; no mask |
| `subtitle_language` | 2,980 | Filterable at interval grain; no mask |
| `player_version` | 1,600 | Filterable at interval grain; no mask |
| `video_resolution` **(new on the unseen day)** | **80,731 of 108,486 — 74.4%**, up to 16 distinct values in a single session | Filterable, and exact for `active_ms`; **not peak-able per resolution** |

`video_resolution` is the clearest case: three quarters of sessions change it while playing,
which is exactly what adaptive bitrate does. Giving it a mask bit would have produced a
number that looks like a peak and is not one. The session-static set is declared in
[`solution/policy.yaml`](solution/policy.yaml) and asserted by
[`ingest/concurrency/sql/090_validate_serving.sql`](ingest/concurrency/sql/090_validate_serving.sql),
so a future column that violates it fails the build rather than the dashboard.

Unknown values are **charted, not dropped**. `unknown` is a real `video_type` carried by
1,089 catalogue titles, so the sentinel for a dictionary miss is `__unknown__` — chosen
outside the value domain precisely so that "the dictionary did not resolve this" stays
assertable and distinguishable from "the catalogue says unknown". Dropping the slice would
have silently removed 23.66 viewer-hours across 105 watched titles in the hot hour alone.

## Unseen-day results

Loaded into its own database, `sonyliv_unseen`, through the same pipeline with no code
changes beyond the two new columns the spec announced (`video_resolution`, `show_name`).

| | |
|---|---|
| Events ingested | **7,000,000** |
| After dedup (`events_clean`) | 6,974,879 |
| Distinct sessions | 108,486 |
| Catalogue titles | 33,326 |
| Minute-grain serving rows | 1,006,755 |
| Foreground intervals built | 123,732 |
| **Peak concurrency (session grain, ungrouped)** | **14,506** at `2026-07-31 11:15 UTC` |
| Average concurrency over the loaded span | 338.34 |
| Total viewer-hours | 11,238.6 |

> ### ⚠️ Open discrepancy — resolve before this is final
>
> We ran two independently-built pipelines over the same unseen day. They agree **exactly**
> on the tuning extract (2,305 at `2026-07-26 10:55`, from both) and they agree on the
> unseen day's **peak minute** (`11:15`) — but not on its magnitude:
>
> | Pipeline | Database | Peak | Sessions with intervals |
> |---|---|---|---|
> | Interval-array (`session_intervals`) | `sonyliv_unseen` | 14,506 | 83,083 of 108,486 |
> | Delta / checkpoint (`concurrency_deltas`) | `sonyliv` | 19,882 | 96,844 of 108,486 |
>
> The gap tracks the coverage gap: 25,403 sessions have no interval row at all in
> `sonyliv_unseen`, and `14,506 / (1 − 0.234) ≈ 18,940`. The interval build looks
> **incomplete**, not wrong — `dirty_sessions` still holds all 108,486 keys. Draining it
> should close most of the difference:
>
> ```bash
> CLICKHOUSE_DATABASE=sonyliv_unseen ./ingest/bin/sonyliv-ingest concurrency --layer all --full
> CLICKHOUSE_DATABASE=sonyliv_unseen make -C ingest rollup-check
> ```
>
> Do not publish 14,506 as the answer until that has re-run and the two pipelines reconcile.
> This section exists instead of a rounded-off number because a silently wrong concurrency
> figure is the precise failure mode this problem is about.

### Query latencies and pipeline evidence

Latencies and the `system.query_log` extract are captured in
[`clickstack/dashboards/05-benchmark-answers.json`](clickstack/dashboards/05-benchmark-answers.json)
— the *Query evidence*, *Query log coverage* and *Rows read* tiles read from the live
service, so nothing here is hand-recorded.

Two traps worth stating, because they change how the evidence has to be gathered at all:

- `system.query_log` is **per-replica** on Cloud. An extract from one node silently misses
  every query routed to the other. Query `clusterAllReplicas(default, system.query_log)`.
- The current `query_log` is not the whole history. ClickHouse renames the table to
  `query_log_1`, `query_log_2`, … at generation changes, and the old ones stay queryable. On
  2026-08-02 the current table began at 22:23 while the numbered tables reached back to
  08:38 — the difference between "lost to retention" and a complete answer.

## Architecture

```
  ch-hackathon-raw-data*.csv ──────┐
  ch-hackathon-content-data*.csv ──┤   sonyliv-ingest (Go, native protocol)
  synthetic fleet generator ───────┤   batched INSERT · dedup token · reject capture
  (sonyliv-mock, target concurrency)
                                   ▼
 ┌─────────────────────────────── ClickHouse Cloud (aws ap-south-1, 26.2, 2 replicas) ──┐
 │                                                                                      │
 │  events_raw          MergeTree · append-only · never rewritten   ← the evidence layer│
 │      │                                                                               │
 │      ├── MV ─▶ events_clean      ReplacingMergeTree · normalized · read via argMax    │
 │      └── MV ─▶ dirty_sessions    the incremental work queue                           │
 │                       │                                                              │
 │             compactor (sonyliv-ingest concurrency) — only touched sessions            │
 │                       ▼                                                              │
 │  session_intervals   ReplacingMergeTree · Array(start_time, end_time) per session      │
 │                       │                                                              │
 │             rollup, one row per (minute × dimension mask)                             │
 │                       ▼                                                              │
 │  serving_concurrency_minute   minute_peak · active_ms · ending_concurrency            │
 │      └── serving_minute_current    the only object the dashboards read                │
 │                                                                                      │
 │  content_dim ──▶ content_dict   DICTIONARY: content_id → title / type / category      │
 └──────────────────────────────────────────────────────────────────────────────────────┘
          │                        │                              │
   sonyliv-api (Go)         sonyliv-mcp (Go)                 ClickStack
   + Next.js static export  restricted ClickHouse user       6 dashboards + drop alert
          │                 SELECT on 8 aggregate objects
          │                        │
     nginx (TLS)          LibreChat + LiteLLM ──▶ Langfuse (traces + prompt registry)
   apex  → dashboard
   chat. → LibreChat
```

Everything runs on one EC2 box behind nginx, split on **Host** rather than on path.
LibreChat cannot be served from a prefix — its assets, `/api` routes and SSE stream are all
absolute from the root, and the two upstream requests for base-path support
([#5702](https://github.com/danny-avila/LibreChat/issues/5702), discussion #2406) are open
and unanswered. Under a path split, any drift between `basePath` and `NEXT_PUBLIC_API_BASE`
would have sent our dashboard's API calls to *LibreChat's* API — not a 404, a wrong service,
which is a far worse way to fail. On its own hostname that failure mode cannot exist at all.

TLS is a real Let's Encrypt certificate with three SANs, issued over **TLS-ALPN-01** via
`lego` (HTTP-01 was blocked by the security group, and certbot has never implemented ALPN),
renewed by a systemd timer. Config: [`deploy/nginx/sonyliv.conf`](deploy/nginx/sonyliv.conf),
[`deploy/tls-renew.sh`](deploy/tls-renew.sh).

## ClickStack, Langfuse, LibreChat

All three are integrated, over the same serving layer. Wiring, setup and the verification
script are in [`deploy/README.md`](deploy/README.md).

### ClickStack — *pipeline and product observability*

Six dashboards over the concurrency serving layer, defined as committed JSON and applied by
script, not clicked together in a UI:

| Dashboard | Role |
|---|---|
| [`01-live-concurrency.json`](clickstack/dashboards/01-live-concurrency.json) | The live curve and ending concurrency |
| [`02-concurrency-analytics.json`](clickstack/dashboards/02-concurrency-analytics.json) | Peak and average by grain and window |
| [`03-pipeline-observability.json`](clickstack/dashboards/03-pipeline-observability.json) | Ingestion lag, compactor drain rate, serving-layer freshness |
| [`04-grouped-viewers.json`](clickstack/dashboards/04-grouped-viewers.json) | Per-dimension breakdowns off the mask layer |
| [`05-benchmark-answers.json`](clickstack/dashboards/05-benchmark-answers.json) | Benchmark answers, rows read, and query-log evidence |
| [`06-viewer-drop-alerts.json`](clickstack/dashboards/06-viewer-drop-alerts.json) | Per-dimension concurrency-decline alert |

Connection and ingestion config: [`clickstack/sources.json`](clickstack/sources.json),
[`clickstack/alerts.json`](clickstack/alerts.json), applied by
[`clickstack/apply.sh`](clickstack/apply.sh) (`make -C ingest clickstack`). Tile-by-tile
render verification in [`clickstack/TILE-VERIFICATION.md`](clickstack/TILE-VERIFICATION.md).
It reads the `sonyliv` / `sonyliv_prod` / `sonyliv_unseen` databases on our ClickHouse Cloud
service directly — the serving tables above, not a separate copy.

Managed ClickStack has no stable deep link — the route is console → service → ClickStack →
Launch, through an authenticated redirect — so a demo tab pointed at it lands on a login
page. The same panels are therefore **reproduced in-product** at `/analytics/`, reading the
same serving-layer views, so a number on that page and a number on a ClickStack tile come
from one definition. Cross-checked: `/analytics/` reports `ANDROID_PHONE` peaking at 1,461
at 10:55, which is what an independent query path reports in
[`docs/TABLE-CONTRACT.md`](docs/TABLE-CONTRACT.md) §5.6.

### LibreChat — *conversational layer over the serving layer*

Self-hosted at **https://chat.fastandfurious.live**, hosting an analyst that answers
viewing-trend questions in natural language.

It reaches ClickHouse only through [`sonyliv-mcp`](ingest/cmd/sonyliv-mcp/README.md), an MCP
server we wrote because ClickHouse Cloud's hosted MCP **cannot be narrowed** — its tool list
includes `get_organizations` and `get_organization_cost`, which cannot be turned off, and
authenticated with a Cloud API key it returned our entire organisation's control-plane data.

The boundary is enforced in two independent layers, in this order:

1. **The grant — this is the boundary.** `sonyliv_mcp` holds `SELECT` on eight aggregate
   serving objects and `dictGet` on `content_dict`. Nothing else. Whatever SQL arrives,
   ClickHouse refuses to read `events_clean` or `session_intervals` for this user. The
   server refuses to *start* if the connected account can reach either.
2. **The guard — this is the explanation.** A parser validates every statement before it is
   sent: single statement, `SELECT` / `WITH` only, relations checked against an allowlist,
   off-box table functions (`url`, `s3`, `remote`, `clusterAllReplicas`) refused by name.

The guard exists so a refusal reads *"that table is outside the serving layer"* instead of
`ACCESS_DENIED`, which a model can act on — not because it is trusted. Ask the analyst about
a named person and it refuses, and **the refusal is enforced by the grant, not by the
prompt.**

Committed: [`librechat.yaml.tmpl`](deploy/librechat/librechat.yaml.tmpl),
[`docker-compose.yml`](deploy/librechat/docker-compose.yml),
[`litellm-config.yaml`](deploy/librechat/litellm-config.yaml),
[`prompts/serving-analyst.md`](deploy/librechat/prompts/serving-analyst.md),
[`sync-agent.sh`](deploy/librechat/sync-agent.sh),
[`.env.example`](deploy/librechat/.env.example) (secrets redacted),
[`deploy/deploy-librechat.sh`](deploy/deploy-librechat.sh).

The `.tmpl` is the committed artifact rather than the rendered `librechat.yaml`, on purpose:
the live file is generated at deploy time with the Langfuse-managed prompt substituted in,
so committing it would create a second, drifting copy of a prompt that already has a
versioned source of truth. The rendered file and the agent id are gitignored for the same
reason.

#### Test credentials

```
https://chat.fastandfurious.live
email:    demo@sonyliv.local
password: <TBD — Sid to paste, or hand over on the submission form>
```

### Langfuse — *prompt registry and LLM tracing*

- **Prompt management is the source of truth.** The analyst's system prompt is versioned in
  Langfuse and rendered into the deployment at deploy time by
  [`deploy/langfuse-prompt-sync.sh`](deploy/langfuse-prompt-sync.sh), which **fails closed**
  if it cannot be read — the box never boots with a stale prompt of unknown provenance.
  Seeding: [`deploy/langfuse-prompt-seed.sh`](deploy/langfuse-prompt-seed.sh).
- **Every turn is traced.** Model calls route through a LiteLLM sidecar
  ([`litellm-config.yaml`](deploy/librechat/litellm-config.yaml)), so each turn, tool call,
  latency and token count lands in Langfuse Cloud.

Public share links for the graded runs: _TBD — paste before freeze._

## How we built it

**ClickHouse Cloud** (aws ap-south-1, ClickHouse 26.2, 2 replicas) is the only datastore.
Ingestion, the state machine, the rollup and all concurrency computation are SQL and Go
against it — nothing is computed in the application layer.

- **Go** for ingestion, the compactor, the API, the simulator and the MCP server — five
  binaries under [`ingest/cmd/`](ingest/cmd), one static artifact each, no runtime deps.
- **Next.js** (static export) for the dashboard, served out of a Go `embed.FS`. One binary
  on the box, no second Node process, no separate asset host.
- **chDB** for the correctness oracle:
  [`solution/tools/verify_embedded.py`](solution/tools/verify_embedded.py) recomputes the
  reference answers straight from the CSVs, independent of ClickHouse entirely.
- **Two independent pipelines** over the same data — an interval-array model and a
  delta/checkpoint model — built separately and reconciled against each other. On the tuning
  extract they agree to the digit: 10,848 sessions on both sides, zero unmatched on either.

### What we learned the hard way

Everything below was measured against the live service. None of it reproduces on a laptop
and none of it was visible in code review. The full record is in [`CLAUDE.md`](CLAUDE.md)
and [`docs/`](docs).

- **A dictionary loads per replica, and an empty one reports `LOADED`.** We observed one
  replica at `element_count = 33464` and the other at `0` at the same instant, both
  reporting `LOADED`. Queries routed to the cold one got the default from every
  `dictGetOrDefault` — no error, no warning, purely a function of routing. Fix: assert
  enrichment resolved *before* writing, and force the load rather than relying on lazy load.
- **A doubled concurrency curve passes every internal invariant.**
  `insert_deduplication_token` does not make a large `INSERT SELECT` idempotent; we ran one
  twice into a `SummingMergeTree` and the peak became exactly 2 × 2,305. `sum(net) = 0`,
  `min(running) = 0` and `opens = closes` all still passed. **A verification must compare
  against a source outside the layer it verifies** — internal consistency is structurally
  incapable of detecting a scalar multiple, and on the unseen day it would have been
  invisible.
- **A verification file that has never executed is worse than none**, because its presence
  reads as coverage. ClickHouse has no implicit string concatenation, so every multi-line
  `throwIf` message in one gate file was a syntax error — a 272,070-row minute tier shipped
  with none of its checks firing, including the one its own header called "the only
  reference-free check".
- **An output alias silently shadows the column it filters on.**
  `toUInt16(13) AS rollup_mask … WHERE rollup_mask = 5` returns **zero rows and no error**.
  This shipped, and was caught only by a non-emptiness assertion.
- **`SummingMergeTree` with no explicit column list sums your dimensions too.** 96.7% of
  sessions overflowed `user_key` past 2⁶⁴ and 49.6% landed *below* a single input — a
  wrapped id that passes every plausibility check.
- **`INNER ANY JOIN` collapses the left side as well as the right**, which silently returned
  zero intervals instead of 31,947.

## How to run it

### Prerequisites

Go ≥ 1.22, Node ≥ 20.9, and a ClickHouse Cloud service (or any ClickHouse 24.x+).

### 1. Configure

```bash
cp ingest/.env.example .env
$EDITOR .env      # CLICKHOUSE_HOST / PORT / USER / PASSWORD / DATABASE / SECURE
```

### 2. Create the schema

```bash
make -C ingest schema        # add schema-print to see the DDL without connecting
```

Applies every top-level file in [`ingest/sql/`](ingest/sql) in order. Files under
`ingest/sql/manual/` are deliberately **not** applied — they create users and run
destructive mutations, and should be auditable rather than a side effect of a build.

### 3. Load the data

Download both CSVs from the problem-statement package, then:

```bash
./scripts/bootstrap.sh --events path/to/ch-hackathon-raw-data.csv \
                       --content path/to/ch-hackathon-content-data.csv
```

To load the unseen day into its own database:

```bash
./scripts/bootstrap.sh --database sonyliv_unseen \
    --events  path/to/ch-hackathon-raw-data_surprise.csv \
    --content path/to/ch-hackathon-content-data_surprise.csv
```

### 4. Build the intervals and the serving layer

```bash
make -C ingest rollup         # full rebuild: session_intervals, then both serving layers
make -C ingest rollup-live    # or: keep the live layer moving on a 10s cadence
make -C ingest rollup-check   # gating — prints every invariant, exits non-zero on any FAIL
```

### 5. Run the product locally

```bash
make -C ingest api                            # :8080, serves the embedded dashboard
cd dashboard && npm install && npm run dev    # :3000, against the Go API
```

### 6. Verify correctness independently

```bash
python3 solution/tools/verify_embedded.py     # chDB oracle, straight off the CSVs
make -C ingest check                          # go test + vet + gofmt
make -C ingest verify                         # post-load integrity and storage report
```

### Deploying

```bash
DEPLOY_HOST=your-box ./deploy/deploy.sh            # Go binaries + dashboard
DEPLOY_HOST=your-box ./deploy/deploy-mcp.sh        # MCP server + restricted CH user
DEPLOY_HOST=your-box ./deploy/deploy-librechat.sh  # LibreChat + LiteLLM + prompt sync
```

Full runbook, including the one-time box setup, in [`deploy/README.md`](deploy/README.md).

## Repo map

| Path | What's in it |
|---|---|
| [`ingest/`](ingest/README.md) | Go pipeline, schema SQL, compactor, API, simulator, MCP server |
| [`ingest/sql/`](ingest/sql) | The deployed schema — landing, clean, intervals, serving |
| [`ingest/concurrency/`](ingest/concurrency) | Rollup and its gating verification suite |
| [`solution/`](solution/README.md) | Independent design record, executable SQL, chDB oracle, [`policy.yaml`](solution/policy.yaml) |
| [`pipeline/`](pipeline/sql) | The parallel delta/checkpoint pipeline — a second opinion on every number |
| [`dashboard/`](dashboard) | Next.js product UI |
| [`clickstack/`](clickstack/README.md) | Dashboards, sources, alerts, apply script |
| [`deploy/`](deploy/README.md) | nginx, systemd units, TLS renewal, LibreChat + LiteLLM |
| [`optimizations/`](optimizations/README.md) | Projections, and the measurements behind them |
| [`docs/`](docs) | Design record, decisions, evidence, table contract, cross-pipeline review |
| [`prototype/`](prototype) | The first Python pass, kept for comparison |

## License

[MIT](LICENSE).
