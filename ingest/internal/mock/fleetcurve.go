package mock

import (
	"context"
	"fmt"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2"

	"github.com/sonyliv-clickathon/ingest/internal/chx"
	"github.com/sonyliv-clickathon/ingest/internal/fleet"
)

// CurveSource says how a curve was produced, so a reader is never left guessing
// whether they are looking at the served answer or a recomputation of it.
type CurveSource string

const (
	// SourceServed reads concurrency_minute for sealed minutes and computes only
	// the unsealed tail. This is what the pipeline actually serves.
	SourceServed CurveSource = "served"
	// SourceExact re-runs the state machine over every event, scoped to the
	// fleet's own sessions. Slower and narrower, and the only one that is an
	// independent oracle.
	SourceExact CurveSource = "exact"
)

// ServedCurve reads the materialised metric. It stops at the watermark.
//
// It used to compute the unsealed tail on the fly, and that was measured at 7.3s
// against 0.9s for the oracle it was supposed to be faster than — a serving layer
// slower than the recomputation it replaces is not a serving layer. The cost is
// structural, not a tuning problem: the tail is scoped by dimension, so it cannot
// prune on session_key the way the oracle does, and an unscoped derivation has to
// scan the whole state lookback however small the output window is.
//
// So it does not compute anything. Sealed minutes are a GROUP BY over
// pre-aggregated rows and the answer arrives in milliseconds; the newest couple of
// minutes are simply not served yet, which is what `sealed_through` reports and
// what every real analytics pipeline does. The fleet's own line still runs to now,
// so the distance between the two lines at the right-hand edge IS the pipeline's
// lag, displayed rather than hidden.
//
// Scoped by DIMENSION, not by session. concurrency_minute is a metric over all
// traffic — that is what makes it a serving layer rather than a fleet feature — so
// an unfiltered read counts every session active in the window, whoever produced
// it. Where that distinction matters, ExactFleetCurve is the session-scoped answer.
func ServedCurve(ctx context.Context, c *chx.Client, sealer *Sealer, f fleet.Filter,
	from, to time.Time) ([]fleet.CurvePoint, time.Time, error) {

	sealed, err := sealer.Watermark(ctx)
	if err != nil {
		return nil, time.Time{}, err
	}
	// Never read sealed rows past the requested window, and never below its start.
	cut := sealed
	if cut.After(to) {
		cut = to
	}
	if cut.Before(from) {
		cut = from
	}

	if !cut.After(from) {
		return []fleet.CurvePoint{}, sealed, nil
	}
	pts, err := readSealed(ctx, c, f, from, cut)
	return pts, sealed, err
}

// dimPredicate filters by dimension. Empty fields match everything, which is what
// lets one query serve the filtered and unfiltered graph.
//
// Written once and used by both halves of ServedCurve: if the sealed half and the
// live half disagreed about what a filter means, the curve would step at the
// watermark and the step would look like a pipeline defect.
const dimPredicate = `
      ({content_id:Int64}   = 0  OR content_id  = {content_id:Int64})
  AND ({video_type:String}  = '' OR video_type  = {video_type:String})
  AND ({platform:String}    = '' OR platform    = {platform:String})
  AND ({app_version:String} = '' OR app_version = {app_version:String})
  AND ({country:String}     = '' OR country     = {country:String})`

func dimParams(f fleet.Filter, extra map[string]string) clickhouse.Parameters {
	p := clickhouse.Parameters{
		"content_id":  fmt.Sprint(f.ContentID),
		"video_type":  f.VideoType,
		"platform":    f.Platform,
		"app_version": f.AppVersion,
		"country":     f.Country,
	}
	for k, v := range extra {
		p[k] = v
	}
	return p
}

// readSealed serves pre-aggregated minutes.
//
// sum(sessions) across dimension buckets is exact, not an approximation: a
// session's dimensions are fixed for its life, so it lands in exactly one bucket
// and is counted once.
func readSealed(ctx context.Context, c *chx.Client, f fleet.Filter,
	from, to time.Time) ([]fleet.CurvePoint, error) {

	q := fmt.Sprintf(`
		SELECT minute,
		       toUInt64(sum(sessions))  AS sessions,
		       toInt64(sum(active_ms))  AS active_ms
		FROM %s.concurrency_minute
		WHERE minute >= {from:DateTime} AND minute < {to:DateTime}
		  AND %s
		GROUP BY minute ORDER BY minute`, c.Database, dimPredicate)

	qctx := clickhouse.Context(ctx, clickhouse.WithParameters(dimParams(f, map[string]string{
		"from": from.Format("2006-01-02 15:04:05"),
		"to":   to.Format("2006-01-02 15:04:05"),
	})))
	return scanCurve(c.Conn.Query(qctx, q))
}

// ExactFleetCurve is the oracle: the full state machine, scoped to the fleet's own
// sessions rather than to a dimension.
//
// Kept alongside the served path deliberately. The served metric is what the
// pipeline answers with, and a metric cannot validate itself — this is the
// independent derivation the comparison graph checks it against, and the only one
// that can prove the fleet and ClickHouse agree on a specific set of sessions.
func ExactFleetCurve(ctx context.Context, c *chx.Client, f fleet.Filter,
	from, to time.Time, timeoutMS int64) ([]fleet.CurvePoint, error) {

	scope := `session_key IN (
	        SELECT sipHash64(video_session_id)
	        FROM %[1]s.fleet_sessions FINAL
	        WHERE video_session_id NOT IN (
	            SELECT video_session_id FROM %[1]s.fleet_sessions WHERE removed
	        )
	          AND ({content_id:Int64}   = 0  OR content_id  = {content_id:Int64})
	          AND ({video_type:String}  = '' OR video_type  = {video_type:String})
	          AND ({platform:String}    = '' OR platform    = {platform:String})
	          AND ({app_version:String} = '' OR app_version = {app_version:String})
	          AND ({country:String}     = '' OR country     = {country:String})
	    ) AND event_ts <= w_to`

	q := fmt.Sprintf(`
WITH
    {timeout:Int64}                       AS timeout_ms,
    toDateTime64({from:String}, 3, 'UTC') AS w_from,
    toDateTime64({to:String},   3, 'UTC') AS w_to,
`+derivationCTE+`
SELECT toDateTime(m, 'UTC') AS minute,
`+minuteAggregate+`
FROM exploded
WHERE toDateTime64(m, 3, 'UTC') <  w_to
  AND toDateTime64(m + 60, 3, 'UTC') > w_from
GROUP BY minute ORDER BY minute`,
		c.Database, fmt.Sprintf(scope, c.Database))

	qctx := clickhouse.Context(ctx, clickhouse.WithParameters(dimParams(f, map[string]string{
		"timeout": fmt.Sprint(timeoutMS),
		"from":    from.Format("2006-01-02 15:04:05.000"),
		"to":      to.Format("2006-01-02 15:04:05.000"),
	})))
	return scanCurve(c.Conn.Query(qctx, q))
}

func scanCurve(rows driverRows, err error) ([]fleet.CurvePoint, error) {
	if err != nil {
		return nil, fmt.Errorf("curve query: %w", err)
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
			return nil, fmt.Errorf("scan curve point: %w", err)
		}
		p.Sessions, p.ActiveMS = sessions, activeMS
		out = append(out, p)
	}
	return out, rows.Err()
}

// driverRows is the subset of the ClickHouse rows interface scanCurve needs.
type driverRows interface {
	Next() bool
	Scan(...any) error
	Close() error
	Err() error
}
