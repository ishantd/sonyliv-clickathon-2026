# ClickStack dashboards

Three dashboards over the serving tables, created through the managed ClickStack
API rather than clicked together by hand — so they are diffable, reviewable, and
reproducible on another service.

| File | What it is |
|---|---|
| `dashboards/01-live-concurrency.json` | Live concurrency at 10-second grain, filterable by title / content type / category |
| `dashboards/02-concurrency-analytics.json` | Corrected concurrency at 1-minute grain, filterable by platform / app version / content type / category |
| `dashboards/03-pipeline-observability.json` | Ingest lag, rollup latency, recompute backlog, and read volume per serving query |
| `sources.json` | The four ClickStack sources the tiles bind to |
| `apply.sh` | Create-or-update everything. Idempotent |
| `csapi.sh` | One authenticated request against the ClickStack API |
| `check-tiles.sh` | Run every tile's SQL against ClickHouse and report pass/fail |

## Setup

`.env` needs the four Cloud API values plus one that has to be read by hand:

```
CLICKHOUSE_CLOUD_KEY_ID=...
CLICKHOUSE_CLOUD_KEY_SECRET=...        # Org Admin or Service Admin
CLICKHOUSE_CLOUD_ORG_ID=...
CLICKHOUSE_CLOUD_SERVICE_ID=...
CLICKSTACK_CONNECTION_ID=...           # 24 hex chars, from the ClickStack UI
```

**Why `CLICKSTACK_CONNECTION_ID` cannot be automated.** Managed ClickStack
provisions its own ClickHouse connection and does not expose the connections
routes over the Cloud API — on this service both `GET` and `POST` on
`.../clickstack/connections` return 404, while `/sources`, `/dashboards`,
`/alerts`, `/webhooks`, `/saved-searches` and `/roles` all work. Every tile needs
that connection's id (`connectionId` is required on a raw-SQL chart config, and
`connection` is required on a source), so it has to be read once from the UI:
open ClickStack from the ClickHouse Cloud console, then **Team Settings →
Connections**, or the **Connection** dropdown in any tile editor. It looks like
`68f3a1c9d4e77b0012ab34cd`.

Then:

```bash
./clickstack/apply.sh --dry-run    # resolved payloads, sends nothing
./clickstack/apply.sh              # create or update
```

or `make clickstack` from `ingest/`.

## Verifying before you publish

ClickStack renders a broken tile as an empty box with the error tucked into a
panel, so a dashboard can look fine while half of it is failing. `check-tiles.sh`
expands the HyperDX SQL macros to concrete values and runs each tile's query
directly:

```bash
./clickstack/check-tiles.sh                                       # last 24h
./clickstack/check-tiles.sh '2026-07-26 10:00:00' '2026-07-26 11:00:00'
./clickstack/check-tiles.sh --rows                                # show first rows
```

All 28 SQL tiles pass against `sonyliv_prod`. It checks that a query is valid and
returns rows — not that the result looks right; `make rollup-check` is what
asserts the numbers.

## What the dashboards read, and the one rule behind their layout

Both concurrency dashboards read the serving tables from
`ingest/sql/007_serving_concurrency.sql`, never `events_raw`. The tables exist in
the shape they do because of a single property:

- **`active_ms` is additive across every dimension.** `sum(active_ms) / window`
  is the exact time-weighted average concurrency under *any* filter combination.
  Every filterable tile is built from it.
- **`ending_concurrency` is additive across dimensions at one instant**, because a
  session belongs to exactly one slice. It is the honest "how many right now".
- **A peak is additive across nothing.** Two titles peak at different moments, so
  summing their peaks counts viewers who were never simultaneously present. Exact
  peaks are therefore precomputed per grouping (`dim_mask`) and cannot respond to
  an arbitrary filter — there is no precomputed peak for *Platform=IPHONE AND
  Category=Sport*, and manufacturing one by summing would produce an upper bound
  masquerading as a peak.

That is why dashboard 02 splits its tiles into two labelled groups instead of
letting every filter touch every tile. The distinction is visible in the UI on
purpose.

## Reference figures

`make rollup-check` asserts these against the serving tables, scoped to the
extract's own sessions so synthetic traffic cannot move a fixed number:

| Figure | Value |
|---|---|
| Active intervals | 31,947 across 10,848 sessions |
| Session-hours | 1,779.502796 |
| Hot hour 2026-07-26 10:00–11:00 UTC, exact in-minute peak | 2,305 |
| Hot hour, time-weighted average | 855.578199 |

## Known limits

- **Two observability tiles read the answering replica only.** Cluster-wide
  `system.query_log` / `system.parts` need `clusterAllReplicas(...)`, which
  requires `GRANT READ ON REMOTE TO sonyliv_svc` — `sonyliv_svc` already has
  `SELECT` on both tables but not that. The tiles say "— this replica" in their
  titles rather than rendering as empty boxes. To widen them, run the grant as an
  admin and wrap both table references.
- **The live dashboard needs live traffic.** 93.9% of the extract sits in a
  2.5-hour window on 2026-07-26, so the 10-second layer has nothing recent to
  show unless something is producing events. `bin/sonyliv-gen --concurrency 900
  --duration 90m --speed 1 --content-pool 30 --seed <fresh>` alongside
  `make rollup-live` fills it. A fresh seed each run is required — identical flags
  produce an identical dedup fingerprint and the load is silently skipped as a
  replay.
- **Alerts are not wired.** The API supports them bound to dashboard tiles with
  webhook delivery, but there is no webhook destination to point them at yet.
