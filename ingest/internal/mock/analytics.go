package mock

import (
	"context"
	"fmt"
	"net/http"
	"reflect"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/sonyliv-clickathon/ingest/internal/chx"
)

// Analytics panels: the ClickStack dashboards, served from this box.
//
// WHY THIS EXISTS RATHER THAN A LINK. The six ClickStack dashboards are just
// queries over the serving layer, and ClickStack reads the same ClickHouse this
// server already holds a client for. Linking out to them costs a login, and
// managed ClickStack has no stable deep link at all — the documented route is
// "open the service in the console, pick ClickStack in the left menu, press
// Launch", which redirects through an authenticated handoff. A demo tab that
// lands on a login page is not a demo tab. So the panels are reproduced here,
// against the same objects, and the dashboard becomes self-contained.
//
// NAMED PANELS, NOT ARBITRARY SQL. Every panel is a fixed statement chosen at
// compile time; the request supplies only a window and a row cap. That is not
// defensive boilerplate — /api/ is reachable with a bearer token that the browser
// has to hold in localStorage, so a `?sql=` parameter here would turn a token
// leak into "run anything against production", including reads of the per-user
// event tables the MCP server exists to keep out of reach. The panel name is a
// map key. There is nothing to inject into.
//
// Panels read the SERVING layer only — the same views the ClickStack tiles use —
// so a number rendered here and a number rendered there come from one definition.
// None of them touch events_clean, session_intervals or any per-user table.

// A window worth opening on, per database.
type window struct {
	Key   string `json:"key"`
	Label string `json:"label"`
	From  string `json:"from"`
	To    string `json:"to"`
	// RelMinutes, when non-zero, means "the last N minutes" and From/To are ignored.
	// Resolved in the browser rather than here so it follows the viewer's clock.
	RelMinutes int `json:"rel_minutes,omitempty"`
}

// A selectable ClickHouse database.
//
// HARDCODED, AND THAT IS THE SECURITY BOUNDARY. The chosen name is interpolated
// into panel SQL as a schema identifier, and a schema name cannot be a bound
// query parameter -- so if the request's `db` were passed through, this endpoint
// would be a SQL injection point reachable with the browser's bearer token. The
// request selects an INDEX INTO THIS LIST; it never supplies a name. Anything
// unrecognised is rejected, not defaulted, so a typo fails loudly instead of
// silently charting the wrong dataset.
//
// One connection serves all of them. The panel SQL fully qualifies every table
// (`db.table`), and sonyliv_svc holds grants on each, so switching databases
// needs no second client and no reconnect.
type database struct {
	Name  string `json:"name"`
	Label string `json:"label"`
	Note  string `json:"note"`
	// Writable describes, it does not enforce -- and the distinction matters, so
	// state it rather than imply a guard that is not there.
	//
	// The write paths (fleet INSERT, the stepper, /api/events) never read a `db`
	// parameter at all: they use the server's configured database, full stop. So
	// the picker CANNOT point a write at another dataset, which is a stronger
	// property than checking a flag would give -- there is no code path to guard.
	// This field exists so the UI can say which dataset the simulator writes into,
	// because a reader looking at the evaluation set needs to know the buttons on
	// the other pages do not act on what they are seeing.
	//
	// It matters because a single stray test session already cost the July extract
	// its exact figures; the same mistake here would be seven million rows.
	Writable bool     `json:"writable"`
	Windows  []window `json:"windows"`
}

// databases is the selector's whole surface.
//
// Two datasets, because those are the two this deployment actually uses:
// sonyliv_demo is what the box is configured with and therefore the only one the
// simulator writes into, and sonyliv is the canonical 31 Jul load it is measured
// against. sonyliv_prod and sonyliv_unseen exist on the server but are not
// offered — a picker entry is a promise that the option shows something.
//
// One asymmetry worth knowing before adding a third: /live's served path reads
// concurrency_minute, and that table is written ONLY by the in-process sealer,
// which writes to the server's own database. So a dataset other than
// sonyliv_demo has no sealed rows and /live's ClickHouse line is empty for it —
// correctly, not by failure. sonyliv's data lives in serving_concurrency_minute,
// which is what /analytics reads, and that is where its 6.9M events are visible.
var databases = []database{
	{
		Name:     "sonyliv_demo",
		Label:    "Live demo",
		Writable: true,
		Note:     "What the generator, fleet and API write as you drive them. This is the server's configured database, so it is the only dataset the simulator writes into, and the only one /live can chart a served curve for — the sealer materialises concurrency_minute here and nowhere else.",
		Windows: []window{
			{Key: "1h", Label: "Last hour", RelMinutes: 60},
			{Key: "6h", Label: "Last 6 hours", RelMinutes: 360},
			{Key: "24h", Label: "Last 24 hours", RelMinutes: 1440},
		},
	},
	{
		Name:     "sonyliv",
		Label:    "Evaluation set — 31 Jul",
		Writable: false,
		Note:     "6,911,308 events for 2026-07-31, loaded through the same pipeline. Read-only here: the simulator writes into sonyliv_demo, so this stays exactly as it was loaded. Peak 14,506 at 11:15. Its published rows are in serving_concurrency_minute, so /analytics is the surface for it — /live has no sealed rows for this dataset.",
		Windows: []window{
			{Key: "peak", Label: "Peak hour (31 Jul)", From: "2026-07-31 11:00:00", To: "2026-07-31 12:00:00"},
			{Key: "day", Label: "Whole day", From: "2026-07-31 00:00:00", To: "2026-08-01 00:00:00"},
			{Key: "span", Label: "Everything loaded", From: "2026-07-29 00:00:00", To: "2026-08-01 00:00:00"},
		},
	},
}

// resolveDatabase maps the request's `db` to an allowlisted name.
//
// Empty means the server's configured default, which keeps every existing caller
// working. An unrecognised value is an error rather than a fallback: silently
// charting a different dataset than the one asked for is the failure this whole
// selector exists to make impossible.
func resolveDatabase(requested, fallback string) (string, error) {
	if requested == "" {
		return fallback, nil
	}
	for _, d := range databases {
		if d.Name == requested {
			return d.Name, nil
		}
	}
	names := make([]string, 0, len(databases))
	for _, d := range databases {
		names = append(names, d.Name)
	}
	return "", fmt.Errorf("unknown database %q; selectable: %s",
		requested, strings.Join(names, ", "))
}

// databaseWritable reports whether a resolved database accepts writes.
// Unknown names are not writable, so a future entry defaults to safe.
func databaseWritable(name string) bool {
	for _, d := range databases {
		if d.Name == name {
			return d.Writable
		}
	}
	return false
}

// panel is one chart's query.
type panel struct {
	// title and unit are returned to the client so the labelling lives with the
	// query rather than being restated in the UI, where it would drift.
	title string
	unit  string

	// sql takes the database name; window bounds and the row cap are bound as
	// query parameters, never interpolated.
	sql func(db string) string
}

// panels is the whole surface. Adding a chart means adding an entry here.
var panels = map[string]panel{
	// The headline series. grouping='total' is the ONLY grouping that can answer
	// an unfiltered question: the minute layer holds eleven overlapping
	// aggregations of the same traffic, so summing across them measures 9,411.64
	// where the truth is 855.58.
	//
	// minute_peak and avg_concurrency are both returned because they answer
	// different questions and the difference is large — peak 2,305 against an
	// average of 855.58 over the same hour. A chart showing only one of them
	// invites the other to be inferred from it.
	"concurrency": {
		title: "Concurrency over time",
		unit:  "sessions",
		sql: func(db string) string {
			return fmt.Sprintf(`
SELECT
    toString(minute_start)                   AS minute,
    toUInt32(minute_peak)                    AS peak,
    round(active_ms / 60000.0, 3)            AS average
FROM %[1]s.serving_minute_current
WHERE grouping = 'total'
  AND minute_start >= toDateTime({from:String}, 'UTC')
  AND minute_start <  toDateTime({to:String},   'UTC')
ORDER BY minute_start
LIMIT {cap:UInt32}`, db)
		},
	},

	// Exact peak per platform, read from the platform-grain mask.
	//
	// This is the one panel where the mask choice is load-bearing rather than
	// merely efficient. A peak is exact only at its own grouping, so taking
	// max(minute_peak) over a finer mask and grouping by platform in the query
	// would return the busiest single (platform, title) pair, not the platform's
	// peak. peaked_at is returned alongside because the instants differ — measured
	// ANDROID_PHONE at 10:55 against SONY_ANDROID_TV at 10:53 — and that is the
	// evidence for why these bars must not be added together.
	"platform_peak": {
		title: "Exact peak by platform",
		unit:  "sessions",
		sql: func(db string) string {
			return fmt.Sprintf(`
SELECT
    dim_values                               AS platform,
    toUInt32(max(minute_peak))               AS peak,
    toString(argMax(minute_start, minute_peak)) AS peaked_at,
    round(sum(active_ms) / 3600000.0, 3)     AS viewer_hours
FROM %[1]s.serving_minute_current
WHERE grouping = 'platform'
  AND minute_start >= toDateTime({from:String}, 'UTC')
  AND minute_start <  toDateTime({to:String},   'UTC')
GROUP BY platform
ORDER BY peak DESC
LIMIT {cap:UInt32}`, db)
		},
	},

	// Title leaderboard, ranked by viewer-hours rather than by peak.
	//
	// viewer_hours is sum(active_ms), which is additive, so the ranking is
	// meaningful and the total is the sum of its parts. Ranking by peak would
	// order titles by their busiest instant, which rewards a brief spike over a
	// long watch and cannot be totalled.
	//
	// video_type and category resolve here even though this mask does not select
	// them, because both are functionally determined by content_id.
	"top_titles": {
		title: "Top titles by viewer-hours",
		unit:  "hours",
		sql: func(db string) string {
			return fmt.Sprintf(`
SELECT
    title,
    video_type,
    category,
    round(sum(active_ms) / 3600000.0, 3)     AS viewer_hours,
    toUInt32(max(minute_peak))               AS peak
FROM %[1]s.serving_minute_current
WHERE grouping = 'content'
  AND minute_start >= toDateTime({from:String}, 'UTC')
  AND minute_start <  toDateTime({to:String},   'UTC')
  AND title != ''
GROUP BY title, video_type, category
ORDER BY viewer_hours DESC
LIMIT {cap:UInt32}`, db)
		},
	},

	// Viewer-hours per catalogue category, from the category-grain mask.
	"category_hours": {
		title: "Viewer-hours by category",
		unit:  "hours",
		sql: func(db string) string {
			return fmt.Sprintf(`
SELECT
    dim_values                               AS category,
    round(sum(active_ms) / 3600000.0, 3)     AS viewer_hours,
    toUInt32(max(minute_peak))               AS peak
FROM %[1]s.serving_minute_current
WHERE grouping = 'category'
  AND minute_start >= toDateTime({from:String}, 'UTC')
  AND minute_start <  toDateTime({to:String},   'UTC')
GROUP BY category
ORDER BY viewer_hours DESC
LIMIT {cap:UInt32}`, db)
		},
	},

	// Content type: live against vod against unclassified.
	//
	// 'unknown' is a REAL value here, carried by 1,089 catalogue titles, so it is
	// charted rather than filtered out. Dropping it would silently remove real
	// viewing — measured 23.66 viewer-hours across 105 watched titles in the hot
	// hour — and a pie that does not sum to the total is worse than an ugly slice.
	"video_type_hours": {
		title: "Viewer-hours by content type",
		unit:  "hours",
		sql: func(db string) string {
			return fmt.Sprintf(`
SELECT
    dim_values                               AS video_type,
    round(sum(active_ms) / 3600000.0, 3)     AS viewer_hours,
    toUInt32(max(minute_peak))               AS peak
FROM %[1]s.serving_minute_current
WHERE grouping = 'video type'
  AND minute_start >= toDateTime({from:String}, 'UTC')
  AND minute_start <  toDateTime({to:String},   'UTC')
GROUP BY video_type
ORDER BY viewer_hours DESC
LIMIT {cap:UInt32}`, db)
		},
	},

	// How current each serving layer is. The first thing to read before treating
	// any recent dip as a drop: the minute layer publishes on a deliberate lag, so
	// unpublished minutes are ABSENT, not empty, and a stalled pipeline and an
	// outage have exactly the same shape on a chart.
	"freshness": {
		title: "Serving layer freshness",
		unit:  "seconds",
		sql: func(db string) string {
			return fmt.Sprintf(`
SELECT
    layer,
    toString(watermark_ts)                                  AS watermark,
    toUInt32(dateDiff('second', built_at, now()))           AS built_age_s,
    toUInt32(dateDiff('second', watermark_ts, now()))        AS data_lag_s,
    toUInt64(rows_out)                                      AS rows_out
FROM %[1]s.serving_watermark FINAL
ORDER BY layer
LIMIT {cap:UInt32}`, db)
		},
	},
}

// panelNames is the sorted key set, so the listing is stable.
func panelNames() []string {
	out := make([]string, 0, len(panels))
	for k := range panels {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

// handleAnalyticsList advertises the panels, so the UI does not hardcode a list
// that can drift from what the server actually serves.
func (s *Server) handleAnalyticsList(w http.ResponseWriter, _ *http.Request) {
	type entry struct {
		Name  string `json:"name"`
		Title string `json:"title"`
		Unit  string `json:"unit"`
	}
	out := make([]entry, 0, len(panels))
	for _, n := range panelNames() {
		p := panels[n]
		out = append(out, entry{Name: n, Title: p.title, Unit: p.unit})
	}
	// The databases ship with the panels so the UI has one source of truth. A
	// selector hardcoded in the browser would be a second list to keep in step,
	// and the one that drifts is always the one you cannot see from the server.
	writeJSON(w, http.StatusOK, map[string]any{
		"panels":    out,
		"databases": databases,
		"default":   s.client.Database,
	})
}

// handleAnalytics runs one named panel.
//
//	GET /api/analytics/{panel}?from=...&to=...&cap=200
//
// from/to are RFC3339 or 'YYYY-MM-DD HH:MM:SS'. Defaulting is deliberate rather
// than convenient: with no window this returns the last hour, which on this box
// is generator traffic and therefore always moving. The extract's hot hour is a
// preset the UI passes explicitly, because a dashboard whose default window is a
// fixed date in the past looks broken the first time anyone opens it.
func (s *Server) handleAnalytics(w http.ResponseWriter, r *http.Request) {
	name := r.PathValue("panel")
	p, ok := panels[name]
	if !ok {
		writeJSON(w, http.StatusNotFound, map[string]any{
			"error": fmt.Sprintf("unknown panel %q", name),
			"known": panelNames(),
		})
		return
	}

	db, err := resolveDatabase(r.URL.Query().Get("db"), s.client.Database)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": err.Error()})
		return
	}

	to := parseWhen(r.URL.Query().Get("to"), time.Now().UTC())
	from := parseWhen(r.URL.Query().Get("from"), to.Add(-time.Hour))
	if !from.Before(to) {
		writeJSON(w, http.StatusBadRequest, map[string]any{
			"error": "from must be before to",
		})
		return
	}
	// Capped at 5,000 regardless of what is asked for: the content grouping is
	// 31,537 rows an hour and a panel that returns all of them would be a slow
	// request producing a chart nobody can read.
	cap32 := uint32(500)
	if v := r.URL.Query().Get("cap"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			if n > 5000 {
				n = 5000
			}
			cap32 = uint32(n)
		}
	}

	// 30s: a cold service can take a few seconds on the first granule read, and a
	// dashboard that gives up at 5s looks like a broken panel rather than a slow
	// one. Still bounded, because a hung panel holds a connection.
	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
	defer cancel()

	cols, rows, err := runPanel(ctx, s.client, db, p, from, to, cap32)
	if err != nil {
		// 200 with an error field, not 5xx. Each panel is fetched independently and
		// the page renders the ones that worked; a status code would make SWR retry
		// a query that is going to fail again the same way, and the message is what
		// tells you which object is missing.
		writeJSON(w, http.StatusOK, map[string]any{
			"panel": name, "title": p.title, "unit": p.unit, "database": db,
			"from": from, "to": to,
			"columns": []string{}, "rows": [][]any{},
			"error": err.Error(),
		})
		return
	}
	// database is echoed back deliberately: with a selector in front of these
	// panels, a chart that does not say which dataset it came from is a chart that
	// can be screenshotted and attributed to the wrong one.
	writeJSON(w, http.StatusOK, map[string]any{
		"panel": name, "title": p.title, "unit": p.unit, "database": db,
		"from": from, "to": to,
		"columns": cols, "rows": rows,
	})
}

// runPanel executes a panel and returns column names plus untyped rows.
//
// Generic rather than one struct per panel: the shapes differ per chart and the
// client renders from columns anyway, so a struct per panel would be six types
// that exist only to be marshalled straight back to JSON.
func runPanel(ctx context.Context, c *chx.Client, db string, p panel,
	from, to time.Time, cap32 uint32) ([]string, [][]any, error) {

	const layout = "2006-01-02 15:04:05"
	// db comes from resolveDatabase, so it is one of the allowlisted literals and
	// never request text. See the comment on `database`.
	rows, err := c.Conn.Query(ctx, p.sql(db),
		chx.Named("from", from.UTC().Format(layout)),
		chx.Named("to", to.UTC().Format(layout)),
		chx.Named("cap", cap32),
	)
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()

	names := rows.Columns()
	types := rows.ColumnTypes()

	var out [][]any
	for rows.Next() {
		// Destinations from the driver's own ScanType. Scanning into *any is not
		// supported by clickhouse-go — it returns "converting String to
		// *interface {} is unsupported" — so the type has to come from the column.
		dest := make([]any, len(types))
		for i, ct := range types {
			dest[i] = reflect.New(ct.ScanType()).Interface()
		}
		if err := rows.Scan(dest...); err != nil {
			return nil, nil, err
		}
		rec := make([]any, len(dest))
		for i, d := range dest {
			rec[i] = reflect.ValueOf(d).Elem().Interface()
		}
		out = append(out, rec)
	}
	if err := rows.Err(); err != nil {
		return nil, nil, err
	}
	if out == nil {
		// Never null: the client distinguishes "no rows in this window" from "the
		// request failed", and a null array collapses the two.
		out = [][]any{}
	}
	return names, out, nil
}

// parseWhen accepts the two forms the UI sends, falling back rather than erroring.
func parseWhen(s string, def time.Time) time.Time {
	s = strings.TrimSpace(s)
	if s == "" {
		return def
	}
	for _, layout := range []string{time.RFC3339, "2006-01-02 15:04:05", "2006-01-02T15:04", "2006-01-02"} {
		if t, err := time.Parse(layout, s); err == nil {
			return t.UTC()
		}
	}
	return def
}
