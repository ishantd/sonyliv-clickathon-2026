package mock

// The concurrency derivation, in one place.
//
// Three callers need the identical state machine: the sealer that materialises
// concurrency_minute, the live tail that covers the minutes the sealer has not
// reached, and the fleet comparison graph. Three copies of a five-term predicate
// with stop-wins precedence and a lease is three chances to disagree, and a
// disagreement here reads as a pipeline defect on the very graph built to detect
// them.
//
// So the CTE chain is a constant with two holes: a scope predicate and a grouping.

// derivationCTE is the state machine, from raw events to active islands.
//
// %[1]s is the database. %[2]s is a scope predicate over `events_dedup` — the
// only part that varies, because "which sessions" is the one thing the callers
// genuinely disagree about.
//
// It is the same chain as concurrency/sql/010_recompute_sessions.sql: collapse the
// millisecond, apply stop-wins precedence, forward-fill the two independent state
// dimensions, take the lease from eligible liveness only, then merge the surviving
// segments into islands.
const derivationCTE = `
    scoped AS (
        SELECT session_key, event_ts, signal,
               signal IN ('play','resume','liveness') AS is_liveness
        FROM %[1]s.events_dedup
        WHERE %[2]s
    ),
    -- Collapse the millisecond first. events_dedup yields one row per
    -- (session, ts, type, event), so one instant can still carry a background and
    -- a pause together.
    instants AS (
        SELECT session_key, event_ts,
               max(signal = 'session_start')    AS has_start,
               max(signal = 'session_end')      AS has_end,
               max(signal = 'background')       AS has_background,
               max(signal = 'foreground')       AS has_foreground,
               max(signal IN ('pause','error')) AS has_play_stop,
               max(signal IN ('play','resume')) AS has_play_start,
               max(is_liveness)                 AS has_liveness
        FROM scoped GROUP BY session_key, event_ts
    ),
    -- Stop-wins within an instant: -1 beats +1. Getting this backwards silently
    -- overcounts every same-millisecond pause/resume pair.
    setters AS (
        SELECT *,
               multiIf(has_end OR has_background, toInt8(-1),
                       has_start OR has_foreground, toInt8(1), toInt8(0)) AS fg_setter,
               multiIf(has_end OR has_play_stop, toInt8(-1),
                       has_play_start, toInt8(1), toInt8(0))              AS play_setter
        FROM instants
    ),
    stated AS (
        SELECT *,
               max(has_start) OVER w                                   AS started,
               max(has_end)   OVER w                                   AS end_seen,
               argMaxIf(fg_setter,   event_ts, fg_setter   != 0) OVER w AS fg_state,
               argMaxIf(play_setter, event_ts, play_setter != 0) OVER w AS play_state
        FROM setters
        WINDOW w AS (PARTITION BY session_key ORDER BY event_ts
                     ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
    ),
    leased AS (
        SELECT *,
               maxIf(event_ts, has_liveness AND started = 1 AND end_seen = 0
                     AND fg_state = 1 AND play_state = 1) OVER
                   (PARTITION BY session_key ORDER BY event_ts
                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS last_eligible,
               leadInFrame(event_ts, 1, w_to + toIntervalMillisecond(timeout_ms)) OVER
                   (PARTITION BY session_key ORDER BY event_ts
                    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS next_ts
        FROM stated
    ),
    segments AS (
        SELECT session_key, event_ts AS s,
               least(next_ts, last_eligible + toIntervalMillisecond(timeout_ms)) AS e
        FROM leased
        WHERE started = 1 AND end_seen = 0 AND fg_state = 1 AND play_state = 1
          AND last_eligible > toDateTime64(0, 3, 'UTC')
          AND event_ts < last_eligible + toIntervalMillisecond(timeout_ms)
    ),
    -- Segments provably cannot overlap within a session: a segment's end is at
    -- most the next event's timestamp. So islands come from a lag comparison
    -- rather than a running maximum.
    marked AS (
        SELECT *, s > lagInFrame(e, 1, toDateTime64(0, 3, 'UTC')) OVER
            (PARTITION BY session_key ORDER BY s, e
             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS new_island
        FROM segments WHERE e > s
    ),
    numbered AS (
        SELECT *, sum(new_island) OVER
            (PARTITION BY session_key ORDER BY s, e
             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS island
        FROM marked
    ),
    islands AS (
        SELECT session_key,
               greatest(min(s), w_from) AS start_time,
               least(max(e),   w_to)    AS end_time
        FROM numbered GROUP BY session_key, island
        HAVING end_time > start_time
    ),
    -- Explode each island into the minutes it touches. The last minute comes from
    -- end_time minus one millisecond because intervals are half-open: an island
    -- ending exactly at 10:02:00.000 must not appear in the 10:02 minute.
    exploded AS (
        SELECT session_key, start_time, end_time,
               arrayJoin(range(
                   toUInt32(toUnixTimestamp(toStartOfMinute(start_time))),
                   toUInt32(toUnixTimestamp(toStartOfMinute(
                       end_time - toIntervalMillisecond(1)))) + 60,
                   60)) AS m
        FROM islands
    )`

// minuteAggregate turns exploded islands into per-minute numbers.
//
// uniqExact, NOT count(): a session can have several active islands inside one
// minute — pause and resume within the same minute produces two — and this counts
// sessions, not islands. count() reported 21 for a fleet of 20 when this was first
// written, and the comparison graph could not catch it because the Go side had the
// same bug.
const minuteAggregate = `
       toUInt64(uniqExact(session_key)) AS sessions,
       toInt64(sum(dateDiff('millisecond',
             greatest(start_time, toDateTime64(m, 3, 'UTC')),
             least(end_time,      toDateTime64(m + 60, 3, 'UTC'))))) AS active_ms`
