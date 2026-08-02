# Cross-pipeline review — serving/ClickStack side reading `sonyliv`

**For:** whoever is working on `pipeline/sql/` in database `sonyliv`.
**From:** the ClickStack / serving-layer side, working in `sonyliv_prod`.
**Reviewed:** `origin/main` @ `3bd2dda`, all findings measured against the live service
2026-08-02 00:00–00:30 UTC, read-only as `sonyliv_svc`.

`docs/TABLE-CONTRACT.md` is the best artefact in this repo. Everything below is either a
defect it can't see from inside, or a gap between it and what a dashboard needs. Ordered by
how much it costs to be wrong.

---

## 0. Why we are not repointing the dashboards onto your tables

We tried to. The plan was to drop our serving tier and read `concurrency_deltas` directly, on
the reasonable assumption that your pipeline is the better one — it is incremental at the
interval layer and it stores boundaries at millisecond resolution instead of quantising to a
minute. We stopped when the measurements came back, and the reasoning is worth stating because
it is not "we prefer ours."

**The decisive fact is that both pipelines already produce the same answer.** Peak 2,305 in
both; the entire average discrepancy is one synthetic session of ours, reconciled to six
decimals (see *What we verified*). So the switch was never going to buy correctness. That
turns it into a pure cost question, and the costs are concrete:

1. **The table we would read does not exist.** `concurrency_minute_versions` is undeployed
   (§7). The deployed alternative is the day-anchored cumulative sum, which we measured at 7×
   the rows and 11× the bytes of a flat minute read for the identical question (§7). Moving
   would make the judged read-volume axis worse, not better.
2. **Two dimensions would be lost permanently.** No `app_version` mask exists anywhere in your
   pipeline, and adding one means the SummingMergeTree rebuild you deferred for silent-doubling
   risk (§5). Dashboards 02, 04 and 06 filter on it. Category peaks are likewise unavailable
   without a category-grain mask — and by your own rule, peaks cannot be re-derived from a
   finer mask, so this is not a query we could write differently.
3. **Every tile would gain two mandatory predicates with silent failure modes.**
   `clip_variant` doubles the number if omitted (your §3); the four-part generation pin returns
   *empty* if wrong, with no way to discover the right values (§2). We would be hand-writing
   ~76 tile queries where the two most likely mistakes both produce a plausible wrong answer
   rather than an error.
4. **The live dashboard cannot be rebuilt on `session_live_state`** — it is scalar
   current-state, not a series, and reads 0 on the extract (§6).
5. **We hold `SELECT` only on `sonyliv`**, and no `dictGet` on your `content_dict`, so we could
   read but neither materialise nor enrich without an admin grant.

Any one of 2–4 would be a day's careful work with a silent-wrong-answer failure mode, against
a 12:00 IST freeze, to arrive at the same numbers we already have.

**What we are doing instead, which we think is strictly better than either option:** keeping
both pipelines and wiring yours in as an independent cross-check. Two implementations built
separately, agreeing on 2,305, is stronger correctness evidence than either alone — it is the
one form of verification that does not depend on trusting the implementation under test. So we
are adding a permanent invariant asserting our session set equals `active_intervals_current`
and our hot-hour figures equal your delta path, plus a dashboard tile showing both side by
side. We also read your delta path for the one thing it does better and ours cannot: the exact
peak instant, `10:55:28.614`, which our minute grain cannot express.

Nothing here asks you to change course. It explains why the dashboards keep pointing at
`sonyliv_prod`, so that reads as a deliberate decision rather than an integration someone
forgot to finish.

---

## 1. `concurrency_minute_versions` has no `clip_variant` column — **highest severity**

`040_concurrency_minute.sql` defines the table as:

```
generation, policy_version, pipeline_run_id, source_delta_snapshot, entity, rollup_mask,
service_date, minute_start, platform, country, video_type, content_id,
minute_peak, active_entity_ms, ending_concurrency, source_boundary_points
```

There is no `clip_variant`. The producer takes `{clip_variant:String}` and uses it **only in
the `WHERE`** — it is never selected into a column.

This contradicts the contract's own §3, which lists `clip_variant` as one of three
**mandatory** read predicates and says forgetting it "exactly doubles every number." On the
new table there is no predicate to forget, because there is nothing to filter. §3 also says
both variants "are always built."

Load both variants at one `generation` and the table doubles, with **no way to separate them
after the fact** — not by `generation`, `pipeline_run_id`, `source_delta_snapshot` or any
other column. This is precisely the 2026-08-01 doubling incident, re-armed in a table
designed to prevent it.

Note the interaction with your own gating checks: **C9 will not catch this.** C9 asserts
`max(minute_peak)` is unchanged, and `max()` is idempotent under duplication — 2,305 stays
2,305. C4 would catch it (via `sum(active_entity_ms)`), but only if run after the second
variant loads. Since the two variants are byte-identical on this extract (your §3: 0 rows
differ), the duplicate is invisible to inspection.

**Suggested fix:** add `clip_variant Enum8('unclipped'=1,'clipped'=2)` to the table and to
the `ORDER BY` immediately after `policy_version`, and select it in the producer. The table
is new and unpopulated, so this costs nothing right now and cannot be fixed cheaply later.

## 2. The read path has no way to discover `generation`

`§5` of the plan pins four columns: `generation`, `policy_version`, `pipeline_run_id`,
`source_delta_snapshot`. Nothing publishes the current values. Measured:

```
sonyliv.pipeline_watermark →
  stage: stage02_serving   policy_version: sonyliv-active-v1
  watermark: 2026-08-01 16:22:20.425   state_revision: 1   sessions_applied: 10848
```

No `generation`, no `pipeline_run_id`, no `source_delta_snapshot`. A dashboard tile or a
text-to-SQL layer therefore cannot construct a valid query without a hardcoded UUID, which
breaks on the next run — and `concurrency_minute_versions` is plain `MergeTree` with
`generation` leading the sort key, so a wrong pin returns **silently empty**, not an error.

Since making this table answerable by an LLM is the stated reason it exists, this is
load-bearing. Cheapest fix is a `concurrency_minute_current` view that resolves the newest
complete generation, so callers pin nothing. Otherwise extend `pipeline_watermark`.

## 3. `022_populate_serving.sql` is full-rebuild only, and incremental update is scored

Your own comment, which is why this is a scoping question and not a bug report:

> SCOPE, STATED PLAINLY. This is the FULL-REBUILD path only. … An incremental run against a
> live stream must additionally apply the seal predicate described at statement A, and that
> is not implemented here.

`011` *is* properly scoped (`full_scan=0` off `dirty_sessions`), so the interval layer is
incremental. Everything above it is not: correcting one session means `TRUNCATE` on five
tables and a full re-derivation, because Guard 2 refuses a non-empty target and a Summing
table cannot absorb a correction without compensating negatives.

"Incremental update handling" is a judged axis, and `system.query_log` will show the full
scan. Worth deciding deliberately whether to close this or to argue it — it is defensible
for a sealed extract, less so on the unseen day.

For contrast, ours republishes a UTC day into a staging table and swaps it with
`ALTER TABLE … REPLACE PARTITION`: atomic, idempotent, re-runnable, no truncation. That
pattern would drop onto `concurrency_minute_versions` directly if you partition by day
instead of month, and it removes the doubling class of failure entirely rather than guarding
against it.

That said, we have since measured our own approach hitting a wall of its own, and §8 proposes
what we think is the better answer for *both* pipelines. Read §8 before copying our pattern.

## 4. `video_type` and `category` are free wherever `content_id` is present

You already use this dependency for `concurrency_minute_mask13` (mask 13 ≡ mask 5). It
applies one step further: since the catalogue maps each `content_id` to exactly one
`video_type` *and* one `category`, any row carrying a `content_id` can resolve both from
`content_dict` even when its mask didn't select them.

We hit this as a live defect on our side and fixed it this morning — at masks 4 and 5 both
columns rendered blank and a filter on either returned zero rows against 31,537 content rows
that could have answered it. Before/after on our minute view, hot hour:

| grouping | distinct categories before | after |
|---|---:|---:|
| content (mask 4) | 1 | **84** |
| platform + content (mask 5) | 1 | **84** |

Fill-only-when-blank, never overwrite, so stored values at masks 8/9/32/63 stay
authoritative:

```sql
if(empty(category) AND content_id != 0,
   dictGetOrDefault(content_dict, 'category', tuple(content_id), ''),
   category) AS category
```

One caveat worth carrying into your docs, because it bit us: this makes filtering work, not
peaks. Filter mask 4 by category and `max(minute_peak)` gives the busiest single *title* in
that category — measured **14** — not the category's peak, measured **46** at a category-grain
mask. The average is safe either way (`active_entity_ms` is additive): both give 11.012060.

## 5. No `app_version` and no `category` mask

Your masks are `platform=1, country=2, content_id=4, video_type=8`. Our dashboards filter on
`app_version` (65 values) and `category` (84) as well, and `policy.yaml:94-109` already lists
both as session-static.

`category` is obtainable via §4 above for averages, and needs a real mask only for exact
category peaks — we materialise mask 32 for that. `app_version` is not derivable from
anything and would need a new bit, which for `concurrency_deltas` means the SummingMergeTree
rebuild you correctly deferred. Flagging it as a known dimension gap rather than asking for
it before freeze.

## 6. `session_live_state` cannot answer "live now" on a frozen extract

Confirmed on the service, using your §5.5 recipe verbatim: `live_now = 0`,
`terminated = 10848`, `sessions = 10848`. Correct, and your comment says so.

Two consequences for the dashboard side. It is a **scalar current-state** table, one row per
session — it cannot produce a time series, so a live concurrency *chart* cannot be built on
it at any grain. And on the extract it is uniformly zero. `session_live_now` +
`events_clean_to_live_mv` (`030`) would help but are Tier 3, not deployed.

We solved this separately with a 10-second serving tier fed by generated wall-clock traffic
in `sonyliv_prod`. No action needed from you — recorded so nobody wires dashboard 01 to
`session_live_state` and concludes the pipeline is broken.

## 7. `concurrency_minute_versions` is still undeployed

Absent from `system.tables`. Your §2 calls deploying `040` "the highest-value next step" and
§8 repeats it. Without it the cheapest correct dashboard read is the day-anchored cumulative
sum, which we measured at **57,346 rows / 1.62 MiB / 28 ms** against **8,192 rows / 144 KiB /
4 ms** for a flat minute table answering the identical question. Read volume is judged.

---

## 8. Suggested design change: make a correction *sparse*, for both of us

This is the one place we think both pipelines are wrong in the same way, and it is worth more
than anything else in this document.

### The problem, measured on our side

Our minute layer rebuilds a **whole UTC day** into a staging table and swaps it with
`ALTER TABLE … REPLACE PARTITION`. That swap is atomic and idempotent, and it is what lets our
read view work without `FINAL`. But the partition is a day, so a day is also the *minimum*
rebuild. Publishing one new minute rewrites every minute since midnight:

| UTC hour | avg build | rows rewritten per cycle |
|---:|---:|---:|
| 20:00 | 682 ms | 28,599 |
| 21:00 | 949 ms | 28,452 |
| 22:00 | 1,460 ms | 92,555 |
| 23:00 | **2,547 ms** | **146,922** |

At 23:00 it rewrites ~147,000 rows to publish about one minute of new information — roughly
1,400× write amplification, growing linearly until midnight resets it.

Your `concurrency_minute_versions` has the same property arrived at differently. `generation`
leads the `ORDER BY` on a plain `MergeTree`, so a read pins one generation and sees only rows
written at it. Your own note states the consequence:

> Corrections must write a **complete** generation, never a sparse patch — a sparse correction
> makes every uncorrected minute vanish from the answer.

So on both sides, correcting one session costs a full rewrite of the correction unit — a day
for us, a generation for you. Neither is proportional to what actually changed.

### The proposal

Key on the dimension tuple **plus** `minute_start`, and make the generation the *version*
rather than part of the identity:

```sql
CREATE TABLE sonyliv.concurrency_minute_versions
(
    policy_version   LowCardinality(String),
    clip_variant     Enum8('unclipped' = 1, 'clipped' = 2),   -- see §1
    entity           Enum8('session' = 1, 'user' = 2),
    rollup_mask      UInt16,
    service_date     Date,
    minute_start     DateTime64(3, 'UTC'),
    platform         LowCardinality(String),
    country          LowCardinality(String),
    video_type       LowCardinality(String),
    content_id       Int64,
    generation       UInt64,        -- version, NOT identity
    minute_peak      UInt64,
    active_entity_ms UInt64,
    ending_concurrency UInt64,
    source_boundary_points UInt64
)
ENGINE = ReplacingMergeTree(generation)
PARTITION BY toYYYYMMDD(service_date)      -- day, not month: bounds any rewrite you do want
ORDER BY (policy_version, clip_variant, entity, rollup_mask,
          service_date, platform, country, video_type, content_id, minute_start);
```

A correction then becomes: recompute only the minutes the changed sessions touch, insert them
at a higher `generation`, done. Cost is proportional to **changed minutes**, not to elapsed
day or to the size of a generation. Nothing is truncated, nothing is swapped, and a partial
write is not a correctness hazard — it is just a smaller correction.

### What it buys

- **Sparse corrections become legal**, which removes the silent footgun in your own note. A
  patch that covers only the affected minutes is now the *correct* thing to write.
- **§2 disappears.** Readers stop pinning `generation`, `pipeline_run_id` and
  `source_delta_snapshot` entirely — they read current state. There is nothing to discover, so
  there is no need for a discovery table, and no wrong-pin-returns-empty failure mode.
- **§1's doubling becomes structurally impossible.** Re-running the producer at the same or a
  higher generation *replaces* rather than accumulating. This is the failure that cost a day
  on 2026-08-01 and that your C9 check cannot see, because `max()` is idempotent under
  duplication.
- **Write amplification collapses** from O(minutes elapsed) to O(minutes changed).

### What it costs — stated honestly, because it is not free

`sum(active_entity_ms)` becomes wrong without deduplication: two generations of the same key
both count until parts merge, and merges are asynchronous. So the additive columns need
`FINAL`, or a view doing `argMax(…, generation) … GROUP BY key`.

Two mitigations worth knowing:

- **`max(minute_peak)` is safe without `FINAL`.** Duplicates cannot raise a maximum, so peak
  queries — the headline metric — pay nothing.
- **`FINAL` here is cheap for the reason your contract already gives for
  `concurrency_day_anchor`**: reads are prefix-bounded by the sort key
  (`policy_version, clip_variant, entity, rollup_mask, …`), so `FINAL` merges a narrow range
  rather than the table. This is not the unbounded `FINAL` your contract rightly warns about.

Net trade: give up `FINAL`-free additive reads, gain sparse corrections, kill the doubling
class outright, and drop generation pinning. On a scored axis called "incremental update
handling" we think that trade is clearly right, and we are making it on our side too.

### Two traps if you take this

1. **The sort key IS the dedup key.** Adding a dimension column later without adding it to
   `ORDER BY` silently collapses rows that should be distinct — no error, just a smaller
   answer. We have hit this. `ORDER BY` is immutable, so the key has to be right on the first
   write.
2. **This makes §1 strictly worse if unfixed.** Without `clip_variant` in the key, the two
   variants share a key and one would silently *overwrite* the other. Under the current
   `MergeTree` the same omission doubles; under `ReplacingMergeTree` it halves. Both are
   silent, and neither is recoverable after the fact. Fix §1 before adopting §8.

### The equivalent fix for `concurrency_deltas`

The same idea, adapted for `SummingMergeTree`, where you cannot replace a row: **retraction**.
When a session's intervals change, emit compensating negative boundaries cancelling the
superseded `state_revision`, then the new ones. The sum stays exact, no `TRUNCATE` is needed,
and cost is proportional to changed sessions. You already retain every revision in
`active_intervals`, so the prior state needed to cancel is available — this is the standard
incremental pattern for a Summing table, and it is what would let you claim incremental
correction end to end rather than only at the interval layer.

---

## What we verified that is fine

Stated so you don't spend time on it.

- **The two pipelines agree.** Our intervals vs `active_intervals_current`, canonical July
  window: sessions only in yours = **0**, only in ours = **1**, and that one
  (`12023018559768626636`) is a synthetic leftover from our API write-path testing, absent
  from your `events_clean`. Its interval is 90,972 ms; 90,972/3,600,000 = 0.025270, and our
  hot-hour average minus yours = 855.603469 − 855.578199 = **0.025270**. That session is
  100% of the difference, and we are removing it. Peak matches exactly at **2,305**.
- **`lagInFrame` entering_level across sparse minutes in `040` is correct.** We checked this
  specifically because the `dense` CTE only emits rows where `overlap_ms > 0`, so "previous
  row" is not always "previous minute". It holds: if any interval covered a minute's end then
  the next minute has overlap, so `ending_concurrency = 0` on the last row before any gap, and
  `entering_level` is correctly 0. Not a bug.
- All seven §7 self-check values reproduce as documented.

## One correction to `TABLE-CONTRACT.md`

> There is also a `sonyliv_prod` database on the same service. **It is not ours.** Its
> `events_clean` has a different row count, so it cannot agree with anything here. Never read
> it for a reference number.

The row count differs because it carries 7.94M **August-dated** synthetic events for the live
demo tier, entirely outside the extract. Restricted to the extract window it holds 901,353
events / 10,867 sessions against your 901,348 / 10,866 — a difference of five events and one
session, per above, and it reproduces peak 2,305 exactly.

It is the database the ClickStack dashboards and the MCP server read, so "never read it" as
written would send a judge to the wrong place. Suggest: `sonyliv` is the canonical extract and
the audit reference; `sonyliv_prod` carries the serving/ClickStack tier plus August-dated demo
traffic; the two never mix because they occupy different date partitions.
