package mock

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2"

	"github.com/sonyliv-clickathon/ingest/internal/chx"
)

// Sealer tuning.
const (
	// sealGrace is how far behind now the sealer stops. A minute is only sealed
	// once it is closed AND this much time has passed, so the async-insert flush
	// and ordinary lateness have landed. Below this the reader computes on the fly.
	sealGrace = 2 * time.Minute

	// sealInterval is how often the sealer looks for work. Well under the grace,
	// so a minute is sealed shortly after it becomes eligible rather than sitting
	// in the expensive live tail.
	sealInterval = 30 * time.Second

	// sealMaxSpan bounds one pass. A service that has been down for a day should
	// catch up in bounded chunks, not attempt a single query over the whole gap.
	sealMaxSpan = 30 * time.Minute

	// stateLookback is how far back the derivation reads to establish each
	// session's state.
	//
	// This is the honest limit of the whole approach. To know whether a session
	// was foregrounded and playing during minute M you need the most recent setter
	// before M, which has no bound in principle — a session paused four hours ago
	// is still paused. Reading from the beginning of time per seal is not viable,
	// so the derivation reads this far back and a session whose last state change
	// predates it is treated as starting from its first visible event.
	//
	// The real fix is a per-session state layer (sql/006_session_state.sql) that
	// carries the state forward instead of re-deriving it. Until that lands this
	// window is the tradeoff, and its size is the dominant cost of both the seal
	// and the live tail — every pass rescans it. Two hours against a measured p99
	// session length of 74 minutes keeps the margin comfortable while costing a
	// third of what six hours did.
	stateLookback = 2 * time.Hour
)

// Sealer materialises closed minutes into concurrency_minute.
//
// The reader then serves those rows directly and only computes the last couple of
// minutes, which is the difference between a query whose cost grows with history
// and one whose cost is the size of the answer.
type Sealer struct {
	client  *chx.Client
	timeout int64
}

// NewSealer builds a sealer. timeout is the liveness lease in milliseconds and
// must match what every other reader of this data uses.
func NewSealer(c *chx.Client, timeoutMS int64) *Sealer {
	return &Sealer{client: c, timeout: timeoutMS}
}

// Run seals on a ticker until ctx is cancelled.
func (s *Sealer) Run(ctx context.Context) {
	// Seal once at startup so a restart does not leave a gap the live tail has to
	// cover — the tail is bounded at sealGrace and would silently under-report a
	// longer outage.
	if err := s.Seal(ctx); err != nil && ctx.Err() == nil {
		log.Printf("sealer: %v", err)
	}
	t := time.NewTicker(sealInterval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			if err := s.Seal(ctx); err != nil && ctx.Err() == nil {
				log.Printf("sealer: %v", err)
			}
		}
	}
}

// Watermark reads the exclusive upper bound of sealed minutes.
//
// Zero means nothing has been sealed, in which case the reader computes
// everything live — correct, just slower, which is the right way for this to
// degrade.
//
// db is explicit rather than taken from the client because the two callers need
// different databases, and the difference is not cosmetic. The sealer writes to
// its own database, so Seal passes s.client.Database. A read serves whichever
// dataset the picker selected, so ServedCurve passes that. Reading the watermark
// from one database and the sealed rows from another does not fail — it cuts a
// correct curve at a foreign boundary and reports the result as served, which is
// wrong without looking wrong.
func (s *Sealer) Watermark(ctx context.Context, db string) (time.Time, error) {
	q := fmt.Sprintf(
		`SELECT sealed_through FROM %s.concurrency_watermark FINAL WHERE id = 1`,
		db)
	rows, err := s.client.Conn.Query(ctx, q)
	if err != nil {
		return time.Time{}, fmt.Errorf("read watermark: %w", err)
	}
	defer rows.Close()
	var out time.Time
	if rows.Next() {
		if err := rows.Scan(&out); err != nil {
			return time.Time{}, fmt.Errorf("scan watermark: %w", err)
		}
	}
	return out.UTC(), rows.Err()
}

// Seal materialises every minute that has closed and passed the grace window.
func (s *Sealer) Seal(ctx context.Context) error {
	now := time.Now().UTC()
	target := now.Add(-sealGrace).Truncate(time.Minute)

	from, err := s.Watermark(ctx, s.client.Database)
	if err != nil {
		return err
	}
	if from.IsZero() {
		// First run: start one lookback back rather than at the epoch, so a fresh
		// deployment against an existing events table does not try to seal history
		// nobody asked for.
		from = target.Add(-stateLookback).Truncate(time.Minute)
	}
	if !target.After(from) {
		return nil
	}
	if target.Sub(from) > sealMaxSpan {
		target = from.Add(sealMaxSpan)
	}

	if err := s.sealRange(ctx, from, target); err != nil {
		return err
	}
	return s.setWatermark(ctx, target)
}

// sealRange writes one contiguous span of minutes.
//
// The insert carries a deduplication token derived from the span, which is what
// makes the two-step "insert then advance the watermark" safe. If the process dies
// between them, the retry writes the identical block and ClickHouse drops it —
// where without the token a SummingMergeTree would happily add the same minutes
// twice and double every number in them.
func (s *Sealer) sealRange(ctx context.Context, from, to time.Time) error {
	// Just the time window. This used to also carry a
	// `session_key IN (SELECT session_key FROM events_dedup WHERE <same window>)`
	// subquery, which selects precisely the rows the time filter already selects
	// and doubles the scan to do it.
	scope := `event_ts >= w_lookback AND event_ts < w_to`

	q := fmt.Sprintf(`
INSERT INTO %[1]s.concurrency_minute
    (minute, content_id, video_type, platform, app_version, country, sessions, active_ms)
WITH
    {timeout:Int64}                             AS timeout_ms,
    toDateTime64({from:String}, 3, 'UTC')       AS w_from,
    toDateTime64({to:String},   3, 'UTC')       AS w_to,
    toDateTime64({lookback:String}, 3, 'UTC')   AS w_lookback,
`+derivationCTE+`,
    -- Dimensions come from the session's own events. They are constant for a
    -- session's whole life, so any() over its rows is exact rather than a sample.
    dims AS (
        SELECT session_key,
               any(content_id)  AS content_id,
               any(platform)    AS platform,
               any(app_version) AS app_version,
               any(country)     AS country
        FROM %[1]s.events_clean
        WHERE session_key IN (SELECT session_key FROM exploded)
          AND event_ts >= w_lookback AND event_ts < w_to
        GROUP BY session_key
    )
SELECT toDateTime(e.m, 'UTC') AS minute,
       d.content_id,
       dictGetOrDefault('%[1]s.content_dict', 'video_type', tuple(d.content_id), 'unknown') AS video_type,
       d.platform, d.app_version, d.country,
`+minuteAggregate+`
FROM exploded AS e
INNER JOIN dims AS d ON d.session_key = e.session_key
WHERE toDateTime64(e.m, 3, 'UTC') >= w_from
  AND toDateTime64(e.m, 3, 'UTC') <  w_to
GROUP BY minute, d.content_id, video_type, d.platform, d.app_version, d.country`,
		s.client.Database, scope)

	ictx := clickhouse.Context(ctx, clickhouse.WithSettings(clickhouse.Settings{
		"insert_deduplication_token": fmt.Sprintf("concurrency:%d-%d", from.Unix(), to.Unix()),
		"async_insert":               0,
	}), clickhouse.WithParameters(clickhouse.Parameters{
		"timeout":  fmt.Sprint(s.timeout),
		"from":     from.Format("2006-01-02 15:04:05.000"),
		"to":       to.Format("2006-01-02 15:04:05.000"),
		"lookback": from.Add(-stateLookback).Format("2006-01-02 15:04:05.000"),
	}))

	if err := s.client.Conn.Exec(ictx, q); err != nil {
		return fmt.Errorf("seal %s..%s: %w", from.Format(time.TimeOnly), to.Format(time.TimeOnly), err)
	}
	return nil
}

func (s *Sealer) setWatermark(ctx context.Context, through time.Time) error {
	now := time.Now().UTC()
	q := fmt.Sprintf(
		`INSERT INTO %s.concurrency_watermark (id, sealed_through, updated_at, version) VALUES (1, ?, ?, ?)`,
		s.client.Database)
	if err := s.client.Conn.Exec(ctx, q, through, now, uint64(now.UnixMilli())); err != nil {
		return fmt.Errorf("advance watermark to %s: %w", through, err)
	}
	return nil
}
