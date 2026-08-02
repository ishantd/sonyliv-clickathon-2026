# SonyLiv Click-a-thon 2026

Submission repo for [Click-a-thon 2026](https://clickhouse.com/clickathon/india2026) — ClickHouse's 24-hour hackathon in Bengaluru (1–2 August 2026), SonyLiv problem statement track.

Problem statement reference: https://github.com/sidagarwal04/click-a-thon-2026/tree/main/SonyLiv
(Full text is revealed to all teams at 12:00 pm IST on 1 August — nothing here is pre-built against it.)

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
31 July alone — in **6.9 s**, and the peak reproduces exactly: 14,506 at 11:15,
the same figure the ClickHouse Cloud deployment reports.

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

## Status

Active build.

The **ingestion layer** is in [`ingest/`](ingest/README.md): a Go pipeline on the
ClickHouse native connector that loads the two supplied CSVs, plus an event
generator that drives a synthetic stream at a target concurrency through the same
write path. Design record and measurements in
[`ingest/ARCHITECTURE.md`](ingest/ARCHITECTURE.md). Verified end to end against
the supplied extract: 905,558 events, 0 rejected, 0 unjoinable content ids, and a
byte-identical replay that adds no rows.

Events land in two tables: `events_raw` keeps every source row verbatim and is
never deduplicated in place, so the duplicate rate stays measurable and a
normalization rule stays correctable; `events_clean` is a
`ReplacingMergeTree` derivation carrying the normalized values, read through an
`argMax` view that is correct whether or not a merge has run. Verified against
the live Cloud service: 905,558 landed, 901,348 after dedup, 4,210 collapsed
(4,209 exact duplicates plus one conflicting-payload row that remains
recoverable from `events_raw` and is already gone from `events_clean`), 0
rejected, 0 unjoinable content ids, 11.01 MiB on disk across both tables at
35.8x compression.

The independent evidence-backed ClickHouse design, executable SQL,
semantic policy, and embedded verification are in [`solution/`](solution/README.md).
It was created during the 24-hour hack window and intentionally leaves the
concurrent `docs/` / `prototype/` draft untouched for end-of-session comparison.

Current verified reference result for the supplied source hashes and policy
`sonyliv-active-v1`: 31,947 active intervals; exact hot-hour peak 2,305 and
time-weighted average 855.578199 sessions. These are correctness-oracle outputs,
not ClickHouse Cloud latency claims. The executable late-pause test also proves
that touched-session corrections converge exactly with a fresh full-source
rebuild and reject duplicate publication retries.

The canonical time contract is UTC end to end: source transport timestamps are
Unix epoch milliseconds, ClickHouse stores `DateTime64(3,'UTC')`, service days
are UTC, and any `Asia/Kolkata` rendering happens only in the consuming query or
UI.

## Team

| Role | Name | GitHub |
|---|---|---|
| Team Captain | | |
| Member | | |
| Member | | |
| Member | | |

Team name (as registered): _TBD_
Track: _TBD — confirmed once the problem statement is revealed_

## Stack requirements (from the Participant Handbook)

- **ClickHouse** as the primary database (mandatory).
- At least one of the following, meaningfully integrated (not superficial):
  - [ClickStack](https://github.com/ClickHouse/clickstack) — open source observability stack
  - [Langfuse](https://github.com/langfuse/langfuse) — open source LLM observability & analytics
  - [LibreChat](https://github.com/danny-avila/LibreChat) — open source AI chat platform

All three are integrated, over the same serving layer. Architecture, setup and the
verification script are in [`deploy/README.md`](deploy/README.md).

- **ClickStack** — dashboards over the concurrency serving layer, including a
  benchmark-answers board and a per-dimension drop alert.
- **LibreChat** — self-hosted on the EC2 box, hosting an analyst that answers
  viewing-trend questions. It reaches ClickHouse only through
  [`sonyliv-mcp`](ingest/cmd/sonyliv-mcp/README.md), an MCP server that connects as a
  restricted user granted `SELECT` on eight aggregate objects and nothing carrying
  `user_id`. Asked for a person, it refuses — and the refusal is enforced by the grant,
  not by the prompt.
- **Langfuse** — prompt management is the versioned source of truth for the analyst's
  system prompt, rendered into the deployment at deploy time and failing closed if it
  cannot be read. Model calls route through a LiteLLM sidecar, so every turn, tool call,
  latency and token count is traced.

## SonyLIV track requirements

Per [`SONYLIV_SUBMISSION_GUIDELINES.md`](https://github.com/sidagarwal04/click-a-thon-26-submissions/blob/main/SONYLIV_SUBMISSION_GUIDELINES.md).
All of this is in the product UI at **`/analytics`**, not only in a screenshot —
see [`dashboard/README.md`](dashboard/README.md#analytics--the-submission-surface).

**1. Concurrency curve.** Concurrent foreground sessions per minute, over a
selectable window, computed from the dataset in the problem statement and read
from the minute serving tier. Two series — the exact maximum inside each minute
and the time-weighted average. The default window is the 31 July match window
(10:20–11:35 UTC), a full ramp to a peak of **14,506 at 11:15** and the drain
after it. The ClickHouse statement that produced the chart is displayed under the
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

## Submission checklist

Required components, per §2.3 / §5.2 of the Participant Handbook:

- [ ] Working project in this public GitHub repo, MIT-licensed
- [ ] Solution summary (plain text, ≤500 words)
- [ ] Demo video link (YouTube or Loom, ≤5 minutes)
- [ ] Pitch deck (PDF, ≤15 slides, ≤20 MB)
- [ ] Project title (≤100 chars) and optional tagline (≤160 chars)

Deadlines:
- Submission portal opens: 12:00 pm IST, Sat 1 Aug 2026
- Code freeze (portal closes automatically, no extensions): 12:00 pm IST, Sun 2 Aug 2026

Repo must stay **public** from submission through the end of the judging period.

## License

[MIT](LICENSE) — required by the event rules (Apache 2.0 or another ClickHouse-pre-approved permissive license would also qualify).
