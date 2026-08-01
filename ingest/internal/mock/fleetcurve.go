package mock

import (
	"context"
	"fmt"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2"

	"github.com/sonyliv-clickathon/ingest/internal/chx"
	"github.com/sonyliv-clickathon/ingest/internal/fleet"
)

// MaxComparedSessions caps how many session ids the comparison query scopes to.
//
// Not arbitrary: the ids go into the query as a literal array, and ClickHouse's
// default max_query_size is 256 KB. At 65 bytes per 64-character id, 2,000 ids is
// ~130 KB — comfortably under, where 10,000 would be rejected outright. The caller
// reports truncation rather than silently comparing a subset.
const MaxComparedSessions = 2000

// FleetCurve computes per-minute concurrency for a set of sessions the way the
// pipeline does — by inferring it from the event stream.
//
// This is deliberately NOT internal/mock.Curve. That one is the session-independent
// heartbeat-lease estimate, which peaks 37% above the exact answer on the tuning
// extract; plotting it against the fleet's own record would show a gap that is an
// artifact of the estimator rather than evidence about the pipeline. This runs the
// real five-term predicate from concurrency/sql/010_recompute_sessions.sql:
// started AND NOT end_seen AND foreground AND playing AND inside the lease.
//
// Dimension filtering is deliberately absent here. The caller passes ids the
// registry has already filtered, so both lines of the graph are narrowed by one
// implementation of the filter instead of two that could disagree.
func FleetCurve(ctx context.Context, c *chx.Client, videoSessionIDs []string,
	from, to time.Time, timeoutMS int64) ([]fleet.CurvePoint, error) {

	if len(videoSessionIDs) == 0 {
		return []fleet.CurvePoint{}, nil
	}
	if len(videoSessionIDs) > MaxComparedSessions {
		videoSessionIDs = videoSessionIDs[:MaxComparedSessions]
	}

	sql := fmt.Sprintf(`
WITH
    {timeout:Int64}                          AS timeout_ms,
    toDateTime64({from:String}, 3, 'UTC')    AS w_from,
    toDateTime64({to:String},   3, 'UTC')    AS w_to,
    -- Hash server-side and keep the predicate on the leading sort-key column, so
    -- this is a set of point lookups rather than a scan. Reimplementing
    -- ClickHouse's SipHash in Go would be a second definition that could disagree.
    arrayMap(x -> sipHash64(x), {vsids:Array(String)}) AS keys,
    scoped AS (
        SELECT session_key, event_ts, signal,
               signal IN ('play','resume','liveness') AS is_liveness
        FROM %[1]s.events_dedup
        WHERE session_key IN keys AND event_ts <= w_to
    ),
    -- Collapse the millisecond first. events_dedup yields one row per
    -- (session, ts, type, event), so a single instant can still carry a background
    -- and a pause together.
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
    -- Stop-wins precedence within an instant: -1 beats +1.
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
               max(has_start) OVER w                                    AS started,
               max(has_end)   OVER w                                    AS end_seen,
               argMaxIf(fg_setter,   event_ts, fg_setter   != 0) OVER w  AS fg_state,
               argMaxIf(play_setter, event_ts, play_setter != 0) OVER w  AS play_state
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
    -- Segments provably cannot overlap within a session: a segment's end is at most
    -- the next event's timestamp. So island detection is a lag comparison rather
    -- than a running maximum.
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
    -- Explode each island into the minutes it touches. The last minute is derived
    -- from end_time minus one millisecond because intervals are half-open: an
    -- island ending exactly at 10:02:00.000 must not appear in the 10:02 minute.
    exploded AS (
        SELECT session_key, start_time, end_time,
               arrayJoin(range(
                   toUInt32(toUnixTimestamp(toStartOfMinute(start_time))),
                   toUInt32(toUnixTimestamp(toStartOfMinute(
                       end_time - toIntervalMillisecond(1)))) + 60,
                   60)) AS m
        FROM islands
    )
-- uniqExact, NOT count(): a session can have several active islands inside one
-- minute (pause and resume within the same minute produces two), and this counts
-- sessions rather than islands. count() reported 21 for a fleet of 20.
SELECT toDateTime(m, 'UTC')   AS minute,
       uniqExact(session_key) AS sessions,
       sum(dateDiff('millisecond',
             greatest(start_time, toDateTime64(m, 3, 'UTC')),
             least(end_time,      toDateTime64(m + 60, 3, 'UTC')))) AS active_ms
FROM exploded
WHERE toDateTime64(m, 3, 'UTC') < w_to
  AND toDateTime64(m + 60, 3, 'UTC') > w_from
GROUP BY m ORDER BY m`, c.Database)

	rows, err := c.Conn.Query(ctx, sql,
		clickhouse.Named("vsids", videoSessionIDs),
		clickhouse.Named("timeout", timeoutMS),
		clickhouse.Named("from", from.UTC().Format("2006-01-02 15:04:05.000")),
		clickhouse.Named("to", to.UTC().Format("2006-01-02 15:04:05.000")))
	if err != nil {
		return nil, fmt.Errorf("fleet curve: %w", err)
	}
	defer rows.Close()

	out := make([]fleet.CurvePoint, 0, 64)
	for rows.Next() {
		var (
			p        fleet.CurvePoint
			sessions uint64
			activeMS int64
		)
		if err := rows.Scan(&p.Minute, &sessions, &activeMS); err != nil {
			return nil, fmt.Errorf("scan fleet curve point: %w", err)
		}
		p.Sessions, p.ActiveMS = sessions, activeMS
		out = append(out, p)
	}
	return out, rows.Err()
}
