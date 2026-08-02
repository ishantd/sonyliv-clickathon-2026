# Response to `CROSS-PIPELINE-REVIEW.md`

**Reviewed against:** the review's own baseline `3bd2dda`, then re-measured against
`origin/main` @ `6d732e5` and the live `sonyliv` service (ClickHouse 26.2.1.525,
2 replicas) on **2026-08-02 01:30–02:00 UTC**, read-only.

Every verdict below is a measurement, not a reading. Where a finding was already
fixed between their baseline and now, that is stated rather than claimed as new work.

---

## Verdicts

| § | Finding | Verdict |
|---|---|---|
| 1 | `concurrency_minute_versions` has no `clip_variant` | **CONFIRMED, and it was armed.** Fixed. |
| 2 | No way to discover `generation` | **CONFIRMED.** Fixed with `concurrency_minute_current`. |
| 3 | `022` is full-rebuild only | **CONFIRMED, scoping call.** Not closed — see below. |
| 4 | `video_type`/`category` free where `content_id` present | **VALID, not adopted.** See below. |
| 5 | No `app_version`, no `category` mask | **CONFIRMED, accepted gap.** |
| 6 | `session_live_state` can't answer "live now" | **CONFIRMED, by design.** No action. |
| 7 | `concurrency_minute_versions` undeployed | **STALE.** Deployed in `983a04b`, after their baseline. |
| 8 | Make corrections sparse (ReplacingMergeTree) | **Good idea, real cost they didn't price.** See below. |

### §1 — confirmed, and worse than they could see

They were right, and from outside they could not see how close it was to firing.
Measured before the fix:

```
columns named clip_variant        0
rows                        272,070      (one variant's worth)
distinct generations              1
max(minute_peak) mask 0       2,305      (correct)
```

So the table held exactly one variant with **no column recording which one**. Their
point that it could not be separated after the fact is exact.

One correction to their analysis of the gating: they say "C4 would catch this". C4
could not, because **C4 was a syntax error and had never run** — see the section
below. Their reasoning about C9 being blind (`max()` is idempotent under
duplication) is right, and it is now proven rather than argued: on a deliberate
double-load, G3 and G1 fire, G2 stays blind.

`ORDER BY` is immutable, so this needed a rebuild rather than an `ALTER`. A
migration guard now throws with instructions instead of no-op'ing against the old
shape.

### §2 — confirmed, fixed with the cheaper of their two options

They offered a `concurrency_minute_current` view or extending `pipeline_watermark`.
Took the view, and made it resolve `max(generation)` rather than reading the
watermark — a missing or stale watermark row would reintroduce exactly the
silent-empty failure the view exists to remove. It is not a scan: `generation`
leads the sort key, so `max()` is answered from the primary index, measured **1 row
/ 40 bytes**.

`clip_variant`, `entity` and `rollup_mask` stay caller predicates deliberately.
Which variant is authoritative is a judgement call against a private key and `010`
is explicit that the pipeline refuses to make it silently. The difference is that
the caller can now *express* the choice.

### §4 — valid, deliberately not adopted before freeze

The dependency argument is correct and their measurement (1 → 84 distinct
categories at masks 4 and 5) is convincing. Not adopting it here, for one reason
they will recognise: it adds a `dictGetOrDefault` to a read path, and on this
service a dictionary that has loaded **zero rows still reports `LOADED`**, per
replica — so a cold replica silently returns the fallback for every row. `040`'s
`mask13` view already carries that exposure and uses `'__unknown__'` precisely so
the failure is assertable. Widening the surface an hour before a freeze, on the
same day the load-bearing verification file turned out never to have run, is the
wrong order of operations. It is a good post-freeze change.

### §8 — a cost they did not price: it forfeits projection eligibility

The core argument is right, and the write-amplification numbers are damning.
Two things to weigh that the review does not mention.

**It gives up projections on the minute tier.** `deduplicate_merge_projection_mode`
is `throw` on both replicas (default, unchanged), which blocks `ADD PROJECTION` on
Replacing/Summing/Aggregating engines. Of the 13 MergeTree tables in `sonyliv`:

```
ELIGIBLE (classic)   active_intervals, concurrency_minute_versions, events_raw,
                     dirty_sessions, ingest_batches, ingest_rejects
BLOCKED              concurrency_deltas, concurrency_bucket_net,
                     concurrency_day_anchor, events_clean, content_dim,
                     session_live_state
```

`concurrency_minute_versions` is currently **eligible**. Under §8 it becomes
`ReplacingMergeTree` and joins the blocked list. That matters because a projection
is exactly how the same class of problem was just solved one layer down — see
below.

**The `FINAL` cost is understated.** They argue `FINAL` is cheap because reads are
prefix-bounded, which is true for the *serving* reads. It is not true for the
**conservation gate**: G1 sums `active_entity_ms` across every dimension at
mask 0, which is precisely the unbounded shape, and it is the one check that has to
work on judging day.

Net: their trade is defensible and probably right *eventually*. It is the wrong
change to make on a verified serving table with hours left, and it should be taken
together with a decision about what replaces the projection. Their two traps
(sort key IS the dedup key; fix §1 first) are both correct and §1 is now fixed, so
the path is open.

### §3 — left open deliberately, and the review's framing is right

It is a scoping question, not a bug. The interval layer is incremental; everything
above it is not. Not closing it before freeze. Their `REPLACE PARTITION` pattern is
the right shape and §8 is the better version of it.

### One correction back to them

Their closing note asks us to soften "never read `sonyliv_prod` for a reference
number". Their explanation — that the row-count difference is 7.94M August-dated
demo events, and that restricted to the extract window it agrees to five events and
one session — is a better description than what `CLAUDE.md` says, and their
reconciliation of the one synthetic session to six decimals
(0.025270 both sides) is solid work. Adopting their wording. The warning stays for
*reference numbers*, since the two databases genuinely diverge outside the window.

---

## What they could not see from outside: two silent defects in the deployed tier

Both found by *executing* the SQL rather than reading it. Neither is visible from
`sonyliv_prod`, and neither would have surfaced without running it.

### `concurrency_minute_mask13` returned zero rows in production

```
concurrency_minute_mask13                          0 rows
concurrency_minute_versions WHERE rollup_mask = 5  85,553 rows
```

`toUInt16(13) AS rollup_mask` shadows the base column, so `WHERE rollup_mask = 5`
was evaluated as `13 = 5`. Isolated on the service against the same data:

| form | rows |
|---|---:|
| `toUInt16(13) AS rollup_mask` + `WHERE rollup_mask = 5` | **0** |
| output alias renamed | 85,553 |
| filter pushed into a subquery | 85,553 |

Deployed, committed, and silently empty — the exact shape this project exists to
avoid. Fixed with the subquery form, which keeps the output column name callers
expect. `041`'s **G6** now asserts a derived view is never empty while its source
is not.

### `041`'s gating checks were a syntax error and had never executed

Every `throwIf` message was split across adjacent string literals. ClickHouse does
not concatenate those — it is a parse error, which `040`'s own `COMMENT` clause
already documents as having broken that file once. Verified by parsing the
committed C4 verbatim:

```
Code: 62. Syntax error: failed at position 488
('The minute table is lossy or double-counted. Do NOT serve from it.')
```

So the 272,070-row minute tier was deployed with **none of its gates ever firing**,
including the one its own header calls "the only reference-free check".

That also means the two gates were worse than absent, because they were
tuning-day-specific:

- **old C9** threw unless the peak was exactly `2305`
- **old C10** threw unless *some* interval crossed midnight

Both are properties of the July extract. On the unseen day both fail on **correct**
data. Rewritten as G1–G6, reference-free; tuning values demoted to T1–T4 which
never throw.

---

## The read path: what was actually unbounded

Swept every view, MV and query in `pipeline/sql` and `ingest/sql`. Most apparent
full scans are false positives worth naming, because the distinction matters:

**An incremental MV never reads its source table.** `FROM events_raw` in an MV body
is a declaration of shape, not a scan — the MV only ever sees its own insert block.
So `events_raw_to_clean_mv`, `events_raw_to_dirty_mv`,
`concurrency_deltas_to_bucket_mv` and `events_clean_to_live_mv` are all bounded by
construction. The only MV-shaped risk is a `POPULATE` or a backfill `INSERT`, and
this repo correctly avoids `POPULATE` everywhere.

**`011`'s incremental path prunes correctly.** `WHERE {full_scan} = 1 OR session_key
IN scoped_sessions` looked like it might defeat the index. It does not — the
constant folds. `EXPLAIN indexes = 1` with `full_scan = 0`:
`Condition: (session_key in 49-element set)`, `Granules: 3/117`.

### The one that was real, and is fixed

`active_intervals_current` is the mandatory read path for every downstream stage,
and it read **2.95× the rows it needed, on every read, regardless of predicate**:

| read | rows | bytes |
|---|---:|---:|
| via `active_intervals_current` | 96,662 | 2,264,336 |
| prefix-bounded floor | 32,768 | 1,114,178 |

`96,662 = 63,894 + 32,768` — the view's `IN (SELECT … GROUP BY …)` subquery scans
the whole table because nothing pushes the caller's predicate into it, then the
outer scan prunes normally.

Fixed with an aggregate projection whose body is exactly that subquery. Proven
against the real DDL and row shape:

```
before   ReadFromMergeTree (active_intervals)        Granules 8/8
after    ReadFromMergeTree (proj_session_revision)   Granules 3/8
```

`force_optimize_projection = 1` accepts the subquery; an unrelated aggregate under
the same setting throws `PROJECTION_NOT_USED`, so the signal discriminates. Cost
**85.11 KiB** on a 915 KiB table, and it grows with *sessions*, not intervals.

Two alternatives measured and rejected:

- **Window function** — `max(state_revision) OVER (PARTITION BY …)` reads 63,894,
  better than 96,662 but not the 32,768 floor. ClickHouse 26.2 does not push a
  filter through a `Window` step **even when every predicate column is in the
  `PARTITION BY`**: `Condition: true`, `Granules: 8/8`, Filter above Window. It
  also adds a full `Sorting` step.
- **Parameterized view** — reaches the floor, but changes the call syntax and
  breaks every caller plus `TABLE-CONTRACT.md`.

### Measured, deliberately left alone

`max(event_ts) FROM events_clean` (3 sites: `011` guard, `011` observation horizon,
`022` observation horizon) is a genuine full scan — 901,348 rows / 7,210,784 bytes /
11.2 ms — because `event_ts` is not the sort-key prefix, and `events_clean` is a
`SharedReplacingMergeTree` so a projection is refused on it.

`dirty_sessions.max_event_time` answers it **identically** (both
`2026-07-26 11:30:04.847`) for 10,943 rows / 87,544 bytes / 2.6 ms — 82.4× fewer
rows, 4.4× faster. **Not taken.** `dirty_sessions` is an append-only work queue
with no TTL *today*, but nothing stops it being pruned once processed, and
`observation_horizon` is the clip boundary — a horizon that silently goes backwards
drops real events from the answer. Trading a 9 ms saving for a silent-wrong-answer
coupling inverts this project's stated priority. Recorded in `011` so nobody
"optimises" it into a bug later.

Inherent and accepted: `events_dedup` (7× on a hot path, already documented "never
per query") and `content_current` (a full 33,464-row resolution per dictionary
reload — that is what a dictionary source *is*).

---

## Apply order

Nothing below has been run against the service — these are hand-over commands.
`040` is destructive by necessity; read the guard's message first.

```bash
clickhouse-client --host "$CLICKHOUSE_HOST" --port 9440 --secure \
  --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" \
  --database sonyliv --multiquery < pipeline/sql/010_active_intervals.sql
```

Then confirm the projection landed — if `ADD PROJECTION` was refused, everything
still works and silently costs 2.95×, so this check is the point:

```bash
clickhouse-client --host "$CLICKHOUSE_HOST" --port 9440 --secure \
  --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" --query "
SELECT hostName(), name, parent_name
FROM clusterAllReplicas(default, system.projection_parts)
WHERE database='sonyliv' AND table='active_intervals' AND active"
```

`concurrency_minute_versions` must be rebuilt, because `ORDER BY` gained
`clip_variant` and that is immutable. The table is derived — only
`concurrency_minute_mask13` and `concurrency_minute_current` read it — so dropping
it loses no source of truth:

```bash
clickhouse-client --host "$CLICKHOUSE_HOST" --port 9440 --secure \
  --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" \
  --query "DROP TABLE IF EXISTS sonyliv.concurrency_minute_versions"
```

Then `040` per variant, then `041`. Run `041` for **each** variant you loaded —
G1 and G2 are per-`clip_variant` by design:

```bash
clickhouse-client --host "$CLICKHOUSE_HOST" --port 9440 --secure \
  --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" --database sonyliv \
  --param_generation=2 \
  --param_policy_version=sonyliv-active-v1 \
  --param_pipeline_run_id="$(uuidgen | tr 'A-Z' 'a-z')" \
  --param_source_delta_snapshot=0 \
  --param_clip_variant=unclipped \
  --multiquery < pipeline/sql/040_concurrency_minute.sql
```

The ingest DDL changes are metadata-only `MODIFY SETTING` re-issues and safe to
re-run at any time:

```bash
for f in ingest/sql/002_events_raw.sql ingest/sql/003_events_clean.sql ingest/sql/004_ingest_control.sql; do
  sed "s/{{db}}/sonyliv/g" "$f" | clickhouse-client --host "$CLICKHOUSE_HOST" \
    --port 9440 --secure --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" --multiquery
done
```

To re-run the offline validation before any of the above:

```bash
python3 pipeline/tools/validate_040_041.py
```

---

## Blocker not in this review, and it outranks everything here

`data/surprise_spec.md` landed in `6d732e5`. The unseen dataset **changes both
schemas**:

- raw events add `video_resolution`
- content adds `show_name`

Nothing in `ingest/sql`, `ingest/internal/csvsrc` or `scripts/bootstrap.sh` knows
about either column, so **the unseen-day CSV load fails on column count before any
of the above matters**. That needs: additive `ALTER` on `events_raw`, `events_clean`
and `content_dim`; `ALTER TABLE events_raw_to_clean_mv MODIFY QUERY` to carry
`video_resolution` through; `show_name` in `content_current` and `content_dict`;
and the Go CSV parser's column map. It is deliberately **not** in this commit —
it is a larger, separate change than the review response, and it should not be
mixed into a correctness fix.
