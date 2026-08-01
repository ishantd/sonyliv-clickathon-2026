# Handoff: concurrency model on top of the event layer

*Written 2026-08-01. Everything below was measured against the real
905,558-event extract, not reasoned from the data dictionary. Where a number
appears, the query that produced it is reproducible — see the last section.*

Read this before changing `ingest/sql/005`, `ingest/sql/006`, or
`concurrency/sql/010`. Most of the decisions in those files look like they could
be simplified. They can't, and the reasons are expensive to rediscover.

---

## 1. Where things stand

| Layer | File | State |
|---|---|---|
| Landing zone | `ingest/sql/002_events_raw.sql` | deployed |
| Normalized + dedup | `ingest/sql/003_events_clean.sql` | deployed |
| Content dim + dict | `ingest/sql/001_content.sql` | deployed |
| Ingest control | `ingest/sql/004_ingest_control.sql` | deployed |
| **Per-session state** | `ingest/sql/006_session_state.sql` | **written, tested in chdb, not deployed** |
| **Interval output** | `ingest/sql/005_session_intervals.sql` | **written, not deployed** |
| Interval derivation | `concurrency/sql/010_recompute_sessions.sql` | window-function version; **to be replaced by the set-algebra derivation off `006`** |
| Day rebuild → minute grain | — | **not written** |
| Serving table + gates | — | **not written** |

The old `solution/` track is a separate, independently-verified implementation.
Keep it until the new path reproduces its numbers (§5).

### The immediate next task

`010` currently reads `events_dedup` and runs a window-function state machine.
The decision was to replace it with a set-algebra derivation reading `006`. The
algebra is settled and written up in the header of `006`; what is missing is the
SQL. Before deleting the window-function version, diff the interval arrays
session-by-session across all 10,866 sessions — the data is local and that diff
takes minutes.

---

## 2. The measurement ledger

These are the numbers that constrain the design. Re-deriving them costs hours.

### Scale and identity

| | |
|---|---:|
| Events / sessions / users / content ids played | 905,558 / 10,866 / 9,618 / 3,357 |
| `raw` SHA-256 | `15ce6df78e7239820fb9951f2a5c68de2abb47a0950068947e1a0344a0283a96` |
| `content` SHA-256 | `e013c4958e9b6396f9cc6cd2681bb6944bb65dc810b7f0925f78254ed9c7ddd4` |

### Why `foreground` and `playing` must be two independent booleans

Collapsing them into one "inactive" flag was measured at every one of the
905,558 event positions:

| | |
|---|---:|
| disagreements | 38,958 (4.30%) |
| sessions affected | 10,731 of 10,866 (**98.8%**) |
| direction | **every one an overcount** |

The mechanism: a `pause` arriving while the session is *already* backgrounded
changes nothing in a single flag (it's already off), so the pause leaves no
trace — and the next `AppForegrounded` reopens a session whose player is paused.
That co-timing is not rare, it's the norm: backgrounding pauses the player, so
the pause lands within ~5s of the bg edge.

The asymmetry that forces two booleans:

| | |
|---|---:|
| `AppForegrounded` events firing while playback is **stopped** | 13,501 of 14,321 (**94.27%**) |
| `resume`/`Play` events firing while **backgrounded** | 367 |
| `pause`/`error` firing while **backgrounded** | 1,967 |

`AppForegrounded` restores visibility but not playback. `resume` restores
playback but not visibility. Neither can serve as the other's opener.

### Why the four transition arrays can't be merged either

| model | arrays | disagreements | direction | sessions |
|---|---:|---:|---|---:|
| **merge the two stop arrays** | 3 | **219,884 (24.28%)** | all **under**count | 4,483 |
| **merge stops and starts** | 2 | 38,958 (4.30%) | all **over**count | 10,731 |

Merging the *closers* is far worse than merging everything. If a `pause` also
closes foreground, foreground can only reopen on an explicit `AppForegrounded` —
and after a pause with no background, none is coming. The session goes dark for
the rest of its life: ~49 bad positions per affected session versus ~3.6 for the
full collapse.

The four arrays are **two (opener, closer) pairs**. The pairing carries the
semantics; merging across a pair boundary breaks it in one direction or the other.

And the saving isn't there: all four transition arrays together are 98,858
timestamps — **14% of `signal_ts`'s 616,553**.

### Why `AdPause` and `speed-pause` are `liveness`, not `pause`

`speed-pause` / `speed-resume` fire at the **identical millisecond** — 365 of 380
pairs, p50 gap 0 ms. It is the player's internal rate-change handshake, not a
viewer stopping. But `same_timestamp_precedence` puts stop above start, so
classing them as pause/resume collapses the pair to STOPPED **with no resume left
to reopen it**:

| | |
|---|---:|
| same-ms speed pairs | 380 |
| sessions affected | 174 |
| **pairs that never recover** | **106** |
| active time destroyed | **41.9 hours** (2.36% of 1,779.5h) |

`AdPause` is a much smaller effect than it first appears — 36 of 45 land when the
session is *already* stopped by a real pause, so only 9 change anything. The
argument for classing it `liveness` is semantic, not numeric: an ad break is
someone watching, and ad load is densest in the hot hours.

### Why `signal_ts` is stored despite being the bulk of the table

| | |
|---|---:|
| liveness events | 827,143 |
| distinct (session, timestamp) pairs stored | **616,553** (1.34× collapse — the trio shares a millisecond) |
| array length p50 / p90 / p99 / max | 33 / 126 / 342 / 1,709 |
| sessions where the lease expires **inside** an active interval | **161 of 10,572 (1.52%)** |
| such internal cuts | 171 |
| active time overcounted if you keep only a `last_signal` scalar | **11.93 h (0.67%)** |

A scalar `last_signal` gets the tail right for every session but misses the 171
mid-interval silences, over-counting 11.93 hours. That is the entire value of the
array: 0.67% accuracy.

Judge it on that basis, not on my earlier claim of 37.7% — **that figure was
wrong** (§4). The cost is one narrow, well-compressed column and array lengths
bounded by *session* length, which doesn't grow with scale. Correctness is the
top-weighted judging criterion, so 0.67% is worth one column — but it is a
defensible thing to drop if storage ever becomes the binding constraint.

### `006` verification (chdb 4.2.1, real data)

Loaded in 8 hash-scattered batches so each session's events land in many blocks
— the only regime where a commutative-aggregate design can be wrong.

| | |
|---|---:|
| partial state rows for 10,866 sessions | 31,404 across 20 active parts |
| columns compared against single-pass truth | 9 |
| **mismatches** | **0** |

Constructs confirmed working: `SimpleAggregateFunction(groupUniqArrayArray,
Array(DateTime64(3,'UTC')))`, `AggregateFunction(argMin, Tuple(named…),
Tuple(DateTime64(3,'UTC'), UInt64))`, `argMinStateIf` over tuples.

---

## 3. Traps

Each of these fails **silently** — no error, just wrong numbers.

**`minIf` erases mins on merge.** `minIf(event_ts, signal='session_end')` over a
block with no End returns `1970-01-01`, and `min(1970, real_end)` is `1970`. Every
`min` in `006` writes a far-future sentinel for non-matching rows instead. `max`
has no equivalent problem, which is why only the mins carry it.

**`content_dict` is `COMPLEX_KEY_HASHED`,** so `dictGet` needs `tuple(content_id)`
even for a single `Int64`. It is named `content_dict`, not `content_dictionary`,
and its `video_type` default is `'unknown'`, not `'__unknown__'`.

**Same-millisecond stop+start pairs resolve to stop.** That is correct for genuine
conflicts and catastrophic for atomic handshake pairs (see `speed-pause`). A new
client version on the unseen day could introduce another such pair, and it would
be invisible — the numbers would just be low. Worth a gate: list same-ms
stop/start event-name pairs and fail on anything not in a known allowlist.

**`select_sequential_consistency = 1` is not optional on Cloud.** The pipeline
reads what it just wrote at several points, and `SharedMergeTree` can serve a
read from a replica that hasn't seen a freshly committed part.

**`do_not_merge_across_partitions_select_final = 1`** is safe on `events_clean`,
`session_state` and `session_intervals *only because* all three partition on a
session-stable date, so no session's rows ever span partitions. If a partition key
changes, this setting silently becomes wrong.

**`_batch_row_seq` has a 20-bit budget** (`row_version = millis << 20 | seq`).
`loader.go` resets it per chunk and `--batch-size` defaults to 50,000, so it is
not reachable in normal use — but the `> 100000` warning is gated on `&& !*async`,
so `--async --batch-size 2000000` would overflow silently.

**Interval arrays are order-load-bearing.** `010` `arraySort`s on start; the day
rebuild does not re-sort. Anything writing `session_intervals` must sort.

---

## 4. Corrections to earlier claims in this repo's history

Recorded so the next person doesn't inherit them from commit messages or comments.

- **"37.7% of sessions have a lease expiry inside an active interval."** Wrong.
  The correct figure is **1.52% (161 sessions, 171 cuts)**. The bad measure counted
  gaps between eligible signals that contained a pause or background — there the
  interval already ended at the stop, so the lease wasn't what cut it. Segment into
  Base runs *first*, then look for gaps within a run.
- **"`signal_ts` duplicates 91% of your data."** Wrong by roughly an order of
  magnitude. It duplicates ~79% of *one narrow timestamp column*; `events_clean`
  carries ~20 columns.
- **"`row_version` overflow is a live hazard."** Not reachable — the sequence
  resets per chunk (§3 has the residual).
- **"18 unclosed `AdPause` events truncate sessions."** Overstated. 36 of 45
  AdPause events land while the session is already stopped, so the fold is a
  near-no-op there; only 9 change anything.
- **The `docs/` + `prototype/` track counts paused-foreground time as active
  (peak 2,970).** The problem statement explicitly names paused time as
  overstating the audience, so `solution/`'s pause-inactive semantics (peak
  2,305) is the correct reading. Treat 2,970 as superseded, not as an alternative.

---

## 5. Parity targets

The old `solution/` track is verified against these. The new path must reproduce
them before the old one is deleted.

| | |
|---|---:|
| active intervals | 31,947 |
| active sessions | 10,848 |
| active session-hours | 1,779.502796 |
| hot hour (2026-07-26 10:00–11:00 UTC) exact in-minute peak | 2,305 |
| hot hour exact time-weighted average | 855.578199 |
| July 26 cached active-ms | 6,018,191,556 |
| late-pause fixture, converged active-ms | 6,404,143,590 |
| session-independent baseline peak (for contrast) | 3,162 |

The strongest single gate once the day rebuild exists:
**`Σ active_entity_ms == Σ interval durations clipped to the day`**. It exercises
the whole segment/bucket intersection in one number, and it is the same invariant
the old track published as `active_millisecond_conservation_failures: 0`.

---

## 6. Open questions the data cannot settle

- **Does "concurrency at a given minute" mean in-minute peak, minute-boundary
  sample, or any-overlap?** Measured: 2,305 / 2,285 / not computed. The problem
  statement's *"count how many sessions overlap at a given minute"* reads most
  literally as any-overlap, which is the one variant the current schema **cannot**
  answer — it needs a distinct entity count per minute, not a peak and an
  integral. Decide before the unseen day.
- **Session or distinct-user concurrency, or both?** The data dictionary names
  user-level concurrency explicitly, so `006` carries `user_key` and the day
  rebuild should emit both entities.
- **Heartbeat timeout.** 120s is a field choice, not a fact. 60/90/120s retain
  98.63/98.83/98.96% of explicit foreground-and-playing time.

---

## 7. Reproducing locally

The dataset is Git LFS in a separate repo, and its SHA-256s match the verifier's
expectations exactly:

```bash
brew install git-lfs && git lfs install
git clone --depth 1 https://github.com/sidagarwal04/click-a-thon-2026.git
cd click-a-thon-2026 && git lfs pull
shasum -a 256 SonyLiv/data/*.csv   # must match §2
pip3 install chdb                  # 4.2.1 used for everything above
```

chdb differences that matter: `lowerUTF8` does not exist (use `lower`; the values
are ASCII), and `Shared*MergeTree` engines don't exist (use the plain forms —
Cloud translates them anyway).

Every measurement in §2 is a single query over the CSV loaded into a chdb
`MergeTree`. The `006` verification harness — load in N scattered batches, then
diff merged state against a single-pass computation, per session, per column — is
the pattern worth keeping for any future commutative-aggregate column.
