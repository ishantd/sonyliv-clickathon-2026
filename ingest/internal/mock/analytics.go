package mock

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"reflect"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2"
	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"

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
// NAMED PANELS, NOT ARBITRARY SQL. Every panel is a shape chosen at compile time
// in analytics_panels.go; the request supplies a window, a row cap, and values
// for an allowlisted set of dimension filters. That is not defensive
// boilerplate — /api/ is reachable with a bearer token that the browser has to
// hold in localStorage, so a `?sql=` parameter here would turn a token leak into
// "run anything against production", including reads of the per-user event
// tables the MCP server exists to keep out of reach. The panel name is a map
// key, the columns come from a compile-time list, and every filter VALUE is a
// bound parameter. There is nothing in a statement whose text a caller chose.
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
// ALLOWLISTED, AND THAT IS THE SECURITY BOUNDARY. The chosen name is
// interpolated into panel SQL as a schema identifier, and a schema name cannot
// be a bound query parameter -- so if the request's `db` were passed through,
// this endpoint would be a SQL injection point reachable with the browser's
// bearer token. The request selects a NAME FROM THIS LIST; it never introduces
// one. Anything unrecognised is rejected, not defaulted, so a typo fails loudly
// instead of silently charting the wrong dataset.
//
// The list is seeded from the table below and then completed by discovery
// against the server itself (see discoverDatabases) — never from request text.
//
// One connection serves all of them. The panel SQL fully qualifies every table
// (`db.table`), and the service user holds grants on each, so switching
// databases needs no second client and no reconnect.
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

// preferredDefault is the dataset the UI opens on.
//
// `sonyliv` is the submission's own database: the pipeline's DDL, the interval
// tier and the serving tier all target it, and it is what the README and the
// deck quote figures from. `sonyliv_prod` is a separate, diverged deployment
// that happens to live on the same service — it is the server's WRITE target,
// which is why it used to be the default here, but defaulting a READ to it means
// the dashboard opens on numbers that agree with nothing else we publish.
//
// Falls back to the server's configured database when `sonyliv` is not present,
// so this is a preference rather than a requirement.
const preferredDefault = "sonyliv"

// curated is the hand-written metadata for the databases we know about.
//
// Discovery finds the databases; this supplies the labels, the notes and — most
// importantly — the windows, because the interesting hour is a fact about the
// data that no query can infer a good LABEL for. A discovered database that is
// not listed here still appears, with windows derived from its own contents.
var curated = map[string]database{
	preferredDefault: {
		Name:     preferredDefault,
		Label:    "Submission pipeline",
		Writable: false,
		Note: "The submission's own database: every table, view and materialized view built by " +
			"pipeline/sql, loaded through scripts/bootstrap.sh. This is the dataset the README, the " +
			"deck and the benchmark all quote, and what every panel here opens on.",
		// The FIRST window is what the page opens on, so it is the one that has to
		// show the shape of the day rather than the most quotable number in it.
		//
		// Measured off this dataset: traffic sits under 50 concurrent until 09:59,
		// ramps to 11,898 by 11:00, peaks at 14,506 at 11:15 and drains to single
		// digits by 11:32 — the events simply stop there. An 11:00–12:00 window
		// therefore spends half its width on the drain and opens on a curve that
		// falls off a cliff, which reads as a broken pipeline rather than as the
		// end of a match. 10:00–11:35 is the event: ramp, peak and fall, which is
		// what "one full window of interest, with visible peaks and ramps" means.
		Windows: []window{
			{Key: "event", Label: "Match window (31 Jul)", From: "2026-07-31 10:20:00", To: "2026-07-31 11:35:00"},
			{Key: "peak", Label: "Peak hour", From: "2026-07-31 11:00:00", To: "2026-07-31 12:00:00"},
			{Key: "day", Label: "Whole day", From: "2026-07-31 00:00:00", To: "2026-08-01 00:00:00"},
			{Key: "all", Label: "Everything published", From: "2026-07-26 00:00:00", To: "2026-08-05 00:00:00"},
			{Key: "1h", Label: "Last hour", RelMinutes: 60},
		},
	},
	"sonyliv_prod": {
		Name:     "sonyliv_prod",
		Label:    "Mock ingestion",
		Writable: true,
		Note: "The graded July extract plus everything the generator, fleet and API have written since. " +
			"Writable, and the only dataset the simulator writes into. The hot hour reproduces the " +
			"canonical 2,305 / 855.578199.",
		Windows: []window{
			{Key: "hot", Label: "Hot hour (26 Jul)", From: "2026-07-26 10:00:00", To: "2026-07-26 11:00:00"},
			{Key: "extract", Label: "Whole extract", From: "2026-07-14 00:00:00", To: "2026-07-27 00:00:00"},
			{Key: "1h", Label: "Last hour", RelMinutes: 60},
			{Key: "6h", Label: "Last 6 hours", RelMinutes: 360},
		},
	},
	"sonyliv_unseen": {
		Name:     "sonyliv_unseen",
		Label:    "Evaluation set — 31 Jul",
		Writable: false,
		Note: "7,000,000 events for 2026-07-31, loaded through the same pipeline. Read-only here: the " +
			"simulator will not write into it, so it stays exactly as it was loaded. Peak 14,506 at 11:15.",
		Windows: []window{
			{Key: "peak", Label: "Peak hour (31 Jul)", From: "2026-07-31 11:00:00", To: "2026-07-31 12:00:00"},
			{Key: "day", Label: "Whole day", From: "2026-07-31 00:00:00", To: "2026-08-01 00:00:00"},
			{Key: "span", Label: "Everything loaded", From: "2026-07-26 00:00:00", To: "2026-08-04 00:00:00"},
		},
	},
}

// safeIdent is the gate every discovered name passes before it can be
// interpolated as a schema identifier.
//
// Discovery reads system.databases, so the names come from the server rather
// than from a request — but "not attacker-controlled today" is a weaker property
// than "cannot be quoted out of", and only one of the two survives someone later
// deciding a database name can be created from user input. A name that does not
// match is skipped, not escaped: there is no legitimate dataset here that needs
// a character outside this class.
var safeIdent = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*$`)

// discoveryMatch is the substring a database name must carry to be offered.
//
// Every dataset in this project is a `sony…` database, and the service also
// hosts `default`, `system` and ClickHouse's own internal schemas, which are not
// datasets and must never appear in a dataset picker.
const discoveryMatch = "sony"

// catalogue holds the resolved database list.
//
// Discovery runs once, lazily, on the first request that needs it, rather than
// at construction: the service can be started against a cold ClickHouse Cloud
// instance, and a boot that blocks on waking it turns a fast start into a
// 30-second one. A failed discovery is not cached, so the next request retries.
type catalogue struct {
	mu   sync.Mutex
	list []database
}

var dbCatalogue catalogue

// databases returns the selectable datasets, discovering them if needed.
//
// A database is offered only if it (a) carries `sony` in its name, (b) is a safe
// identifier, and (c) actually holds `serving_minute_current`. The third test is
// the one that earns its keep: `sonyliv` was excluded from this list by hand for
// weeks precisely because its serving layer was empty, and a hand-maintained
// exclusion is a fact that goes stale silently. Asking the server removes the
// class of bug rather than the instance.
func (s *Server) databases(ctx context.Context) []database {
	dbCatalogue.mu.Lock()
	defer dbCatalogue.mu.Unlock()
	if dbCatalogue.list != nil {
		return dbCatalogue.list
	}

	found, err := s.discoverDatabases(ctx)
	if err != nil || len(found) == 0 {
		// Fall back to the curated names rather than to nothing: an empty picker
		// makes every panel unreachable, which is a worse failure than a list that
		// might contain a dataset this service cannot read.
		if err != nil {
			log.Printf("analytics: database discovery failed (%v); falling back to the curated list", err)
		}
		out := make([]database, 0, len(curated))
		for _, name := range curatedOrder() {
			out = append(out, curated[name])
		}
		return out
	}

	dbCatalogue.list = found
	return found
}

// curatedOrder puts the preferred default first and the rest alphabetically, so
// the picker's first option is the one the dashboard opens on.
func curatedOrder() []string {
	names := make([]string, 0, len(curated))
	for n := range curated {
		if n != preferredDefault {
			names = append(names, n)
		}
	}
	sort.Strings(names)
	if _, ok := curated[preferredDefault]; ok {
		names = append([]string{preferredDefault}, names...)
	}
	return names
}

// discoverDatabases asks the server which `sony…` databases carry a serving tier.
func (s *Server) discoverDatabases(ctx context.Context) ([]database, error) {
	ctx, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()

	// Two steps, because a span cannot be read across databases in one statement:
	// find the candidates, then ask each one that needs windows for its own span.
	names, err := s.discoverNames(ctx)
	if err != nil {
		return nil, err
	}

	out := make([]database, 0, len(names))
	for _, n := range names {
		d, ok := curated[n]
		if !ok {
			d = database{
				Name:     n,
				Label:    n,
				Writable: false,
				Note:     "Discovered on this service. Windows below are derived from what the minute tier has published.",
			}
		}
		d.Name = n
		// Writable is a property of THIS server's connection, not of the dataset:
		// the write paths use s.client.Database and nothing else, so exactly one
		// entry can truthfully claim it.
		d.Writable = n == s.client.Database
		if len(d.Windows) == 0 {
			d.Windows = s.deriveWindows(ctx, n)
		}
		out = append(out, d)
	}

	// Preferred default first, then the rest in the order discovery returned
	// (alphabetical), so the picker is stable across restarts.
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].Name == preferredDefault {
			return true
		}
		if out[j].Name == preferredDefault {
			return false
		}
		return out[i].Name < out[j].Name
	})
	return out, nil
}

// discoverNames lists the candidate databases that carry a minute serving tier.
func (s *Server) discoverNames(ctx context.Context) ([]string, error) {
	rows, err := s.client.Conn.Query(ctx, `
SELECT database
FROM system.tables
WHERE name = 'serving_minute_current'
  AND positionCaseInsensitive(database, {match:String}) > 0
GROUP BY database
ORDER BY database`, chx.Named("match", discoveryMatch))
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []string
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			return nil, err
		}
		if !safeIdent.MatchString(name) {
			log.Printf("analytics: skipping database %q — not a plain identifier", name)
			continue
		}
		out = append(out, name)
	}
	return out, rows.Err()
}

// deriveWindows builds a window list for a database nobody wrote one for.
//
// The busiest hour is found rather than guessed, which is the only way this can
// be right on a dataset that did not exist when the code was written.
func (s *Server) deriveWindows(ctx context.Context, db string) []window {
	rel := []window{
		{Key: "1h", Label: "Last hour", RelMinutes: 60},
		{Key: "6h", Label: "Last 6 hours", RelMinutes: 360},
	}

	// db is an allowlisted, safeIdent-checked name by the time it reaches here.
	row := s.client.Conn.QueryRow(ctx, fmt.Sprintf(`
SELECT
    toString(toStartOfHour(argMax(minute_start, minute_peak))) AS peak_hour,
    toString(toStartOfDay(min(minute_start)))                  AS lo,
    toString(toStartOfDay(max(minute_start)) + INTERVAL 1 DAY) AS hi
FROM %s.serving_minute_current
WHERE grouping = 'total'`, db))

	var peakHour, lo, hi string
	if err := row.Scan(&peakHour, &lo, &hi); err != nil || lo == "" {
		return rel
	}

	peakEnd := ""
	if t, err := time.Parse("2006-01-02 15:04:05", peakHour); err == nil {
		peakEnd = t.Add(time.Hour).Format("2006-01-02 15:04:05")
	}

	out := make([]window, 0, 4)
	if peakEnd != "" {
		out = append(out, window{Key: "peak", Label: "Busiest hour", From: peakHour, To: peakEnd})
	}
	out = append(out, window{Key: "all", Label: "Everything published", From: lo, To: hi})
	return append(out, rel...)
}

// resolveDatabase maps the request's `db` to an allowlisted name.
//
// Empty means the dashboard's preferred default, which is the submission's own
// database. An unrecognised value is an error rather than a fallback: silently
// charting a different dataset than the one asked for is the failure this whole
// selector exists to make impossible.
func (s *Server) resolveDatabase(ctx context.Context, requested string) (string, error) {
	list := s.databases(ctx)
	if requested == "" {
		return s.defaultDatabase(ctx), nil
	}
	for _, d := range list {
		if d.Name == requested {
			return d.Name, nil
		}
	}
	names := make([]string, 0, len(list))
	for _, d := range list {
		names = append(names, d.Name)
	}
	return "", fmt.Errorf("unknown database %q; selectable: %s",
		requested, strings.Join(names, ", "))
}

// defaultDatabase is `sonyliv` when the service can see it, and the connection's
// own database otherwise.
func (s *Server) defaultDatabase(ctx context.Context) string {
	for _, d := range s.databases(ctx) {
		if d.Name == preferredDefault {
			return d.Name
		}
	}
	return s.client.Database
}

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

// handleAnalyticsList advertises the panels, the datasets and the filter
// surface, so the UI does not hardcode lists that can drift from what the server
// actually serves.
func (s *Server) handleAnalyticsList(w http.ResponseWriter, r *http.Request) {
	type entry struct {
		Name  string `json:"name"`
		Title string `json:"title"`
		Unit  string `json:"unit"`
		Note  string `json:"note"`
		// Breakdown is empty for the time series, which lets the UI lay the curve
		// out differently from the bars without matching on panel names.
		Breakdown string `json:"breakdown,omitempty"`
	}
	out := make([]entry, 0, len(panels))
	for _, n := range panelNames() {
		p := panels[n]
		out = append(out, entry{Name: n, Title: p.title, Unit: p.unit, Note: p.note, Breakdown: p.breakdown})
	}

	ctx, cancel := context.WithTimeout(r.Context(), 25*time.Second)
	defer cancel()

	// The datasets, the filter surface and the rollup table all ship with the
	// panels so the UI has one source of truth. A copy in the browser would be a
	// second list to keep in step, and the one that drifts is always the one you
	// cannot see from the server.
	writeJSON(w, http.StatusOK, map[string]any{
		"panels":     out,
		"databases":  s.databases(ctx),
		"default":    s.defaultDatabase(ctx),
		"dimensions": dimensions,
		// The materialised combinations, so the UI can tell a reader BEFORE they
		// pick one that a given pair cannot carry an exact peak.
		"rollups": rollups,
	})
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

// handleAnalyticsDimensions lists the values each filter can take, for a
// database and window.
//
//	GET /api/analytics/dimensions?db=…&from=…&to=…
//
// SCOPED TO THE WINDOW, deliberately. A filter offering a value that has no rows
// in the window on screen produces an empty chart and reads as a broken panel.
// Titles are capped and ranked by viewer-hours, because the content dimension
// has thousands of values and a select with all of them is not a control.
func (s *Server) handleAnalyticsDimensions(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
	defer cancel()

	db, err := s.resolveDatabase(ctx, q.Get("db"))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": err.Error()})
		return
	}
	to := parseWhen(q.Get("to"), time.Now().UTC())
	from := parseWhen(q.Get("from"), to.Add(-time.Hour))

	const perDim = 200
	values := map[string][]string{}
	for _, d := range dimensions {
		vals, err := s.dimensionValues(ctx, db, d, from, to, perDim)
		if err != nil {
			writeJSON(w, http.StatusOK, map[string]any{
				"database": db, "values": values, "error": err.Error(),
			})
			return
		}
		values[d.Key] = vals
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"database":   db,
		"dimensions": dimensions,
		"values":     values,
		"capped_at":  perDim,
	})
}

// dimensionValues reads one dimension's values from the rollup that carries it.
//
// Ranked by viewer-hours rather than alphabetically: when the list is capped,
// the values that get cut should be the ones nobody watched.
func (s *Server) dimensionValues(ctx context.Context, db string, d dimension,
	from, to time.Time, limit int) ([]string, error) {

	const layout = "2006-01-02 15:04:05"
	rows, err := s.client.Conn.Query(ctx, fmt.Sprintf(`
SELECT %[2]s AS value
FROM %[1]s.serving_minute_current
WHERE grouping = {grouping:String}
  AND minute_start >= toDateTime({from:String}, 'UTC')
  AND minute_start <  toDateTime({to:String},   'UTC')
  AND %[2]s != ''
GROUP BY value
ORDER BY sum(active_ms) DESC
LIMIT {cap:UInt32}`, db, d.Column),
		chx.Named("grouping", d.Grouping),
		chx.Named("from", from.UTC().Format(layout)),
		chx.Named("to", to.UTC().Format(layout)),
		chx.Named("cap", uint32(limit)))
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []string{}
	for rows.Next() {
		var v string
		if err := rows.Scan(&v); err != nil {
			return nil, err
		}
		out = append(out, v)
	}
	return out, rows.Err()
}

// queryStats is what a panel cost, measured rather than estimated.
//
// WHY IT IS RETURNED WITH EVERY PANEL. The whole claim of this project is that a
// pre-aggregated serving tier answers in milliseconds what costs hundreds of
// milliseconds and fourteen million rows to recompute from events. A dashboard
// that asserts that in prose is making a claim; one that prints rows_read beside
// every chart is showing its working. These come from the driver's own progress
// stream — the server's counters, not a stopwatch around a fetch.
type queryStats struct {
	// ElapsedMS is the round trip this process measured: connection time, server
	// execution and row decoding. It is what a user actually waited for.
	ElapsedMS float64 `json:"elapsed_ms"`
	// ServerMS is what ClickHouse itself reported spending, which is the number
	// comparable to system.query_log.
	ServerMS float64 `json:"server_ms"`
	// RowsRead and BytesRead are what the query touched in storage — the figure
	// that separates "read 8,192 rows from a rollup" from "scanned 14M events".
	RowsRead    uint64 `json:"rows_read"`
	BytesRead   uint64 `json:"bytes_read"`
	ResultRows  int    `json:"result_rows"`
	Grouping    string `json:"grouping"`
	ExactPeak   bool   `json:"exact_peak"`
	MaskReason  string `json:"mask_reason"`
	FilterSlice string `json:"filter"`
}

// handleAnalytics runs one named panel.
//
//	GET /api/analytics/{panel}?db=…&from=…&to=…&cap=200&platform=…&title=…
//
// from/to are RFC3339 or 'YYYY-MM-DD HH:MM:SS'. Defaulting is deliberate rather
// than convenient: with no window this returns the last hour, which on this box
// is generator traffic and therefore always moving. The interesting hour is a
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

	// 30s: a cold service can take a few seconds on the first granule read, and a
	// dashboard that gives up at 5s looks like a broken panel rather than a slow
	// one. Still bounded, because a hung panel holds a connection.
	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
	defer cancel()

	q := r.URL.Query()
	db, err := s.resolveDatabase(ctx, q.Get("db"))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": err.Error()})
		return
	}

	to := parseWhen(q.Get("to"), time.Now().UTC())
	from := parseWhen(q.Get("from"), to.Add(-time.Hour))
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
	if v := q.Get("cap"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			if n > 5000 {
				n = 5000
			}
			cap32 = uint32(n)
		}
	}

	filter := parseFilter(q)
	mask := resolveMask(questionKeys(p, filter))
	sql := buildSQL(db, p, mask, filter)

	cols, rows, stats, err := runPanel(ctx, s.client, sql, mask, filter, from, to, cap32)
	stats.Grouping = mask.Grouping
	stats.ExactPeak = mask.ExactPeak
	stats.MaskReason = mask.Why
	stats.FilterSlice = filterSummary(p, filter)
	if p.shape == shapeStatic {
		// A static panel answers a question with no dimensions, so reporting a
		// rollup and an exactness for it would be noise dressed as rigour.
		stats.Grouping = ""
		stats.MaskReason = ""
		stats.ExactPeak = true
	}

	body := map[string]any{
		"panel": name, "title": p.title, "unit": p.unit, "note": p.note,
		// database is echoed back deliberately: with a selector in front of these
		// panels, a chart that does not say which dataset it came from is a chart
		// that can be screenshotted and attributed to the wrong one.
		"database": db,
		"from":     from, "to": to,
		// The statement is served with its result. Judges are asked to look at how
		// concurrency is modelled, not just at the chart, and a query pasted into a
		// README is a query that can drift from the one that ran. This one cannot:
		// it is the exact text that produced the rows beside it.
		"sql":    sql,
		"params": queryParams(mask, filter, from, to, cap32),
		"mask":   mask,
		"stats":  stats,
	}
	if err != nil {
		// 200 with an error field, not 5xx. Each panel is fetched independently and
		// the page renders the ones that worked; a status code would make SWR retry
		// a query that is going to fail again the same way, and the message is what
		// tells you which object is missing.
		body["columns"] = []string{}
		body["rows"] = [][]any{}
		body["error"] = err.Error()
		writeJSON(w, http.StatusOK, body)
		return
	}
	body["columns"] = cols
	body["rows"] = rows
	writeJSON(w, http.StatusOK, body)
}

// queryParams echoes the bound values beside the statement.
//
// Without them the served SQL is unrunnable — it is full of {name:Type}
// placeholders — and "here is the query" would be a half-truth. With them a
// reader can paste both into a ClickHouse client and get the same rows.
func queryParams(m maskChoice, f analyticsFilter, from, to time.Time, cap32 uint32) map[string]string {
	const layout = "2006-01-02 15:04:05"
	out := map[string]string{
		"grouping": m.Grouping,
		"from":     from.UTC().Format(layout),
		"to":       to.UTC().Format(layout),
		"cap":      strconv.FormatUint(uint64(cap32), 10),
	}
	for k, v := range f.values {
		out["f_"+k] = v
	}
	return out
}

// runPanel executes a statement and returns column names, untyped rows and what
// the query cost.
//
// Generic rather than one struct per panel: the shapes differ per chart and the
// client renders from columns anyway, so a struct per panel would be eight types
// that exist only to be marshalled straight back to JSON.
func runPanel(ctx context.Context, c *chx.Client, sql string, m maskChoice,
	f analyticsFilter, from, to time.Time, cap32 uint32) ([]string, [][]any, queryStats, error) {

	const layout = "2006-01-02 15:04:05"

	var stats queryStats

	// Progress arrives as a stream of increments during execution, so rows and
	// bytes accumulate while the reported elapsed is cumulative and is taken as-is.
	// Read on this goroutine only: Query blocks until the rows are ready, and the
	// callbacks fire inside it.
	qctx := clickhouse.Context(ctx, clickhouse.WithProgress(func(p *clickhouse.Progress) {
		stats.RowsRead += p.Rows
		stats.BytesRead += p.Bytes
		if ms := float64(p.Elapsed.Microseconds()) / 1000.0; ms > stats.ServerMS {
			stats.ServerMS = ms
		}
	}))

	args := []driver.NamedValue{
		chx.Named("from", from.UTC().Format(layout)),
		chx.Named("to", to.UTC().Format(layout)),
		chx.Named("cap", cap32),
	}
	// grouping is bound rather than interpolated even though it comes from a
	// compile-time map, because there is no reason for it not to be.
	if m.Grouping != "" && strings.Contains(sql, "{grouping:String}") {
		args = append(args, chx.Named("grouping", m.Grouping))
	}
	fargs := func() []driver.NamedValue { _, a := f.predicates(); return a }()
	args = append(args, fargs...)

	started := time.Now()
	anyArgs := make([]any, len(args))
	for i, a := range args {
		anyArgs[i] = a
	}
	rows, err := c.Conn.Query(qctx, sql, anyArgs...)
	if err != nil {
		stats.ElapsedMS = float64(time.Since(started).Microseconds()) / 1000.0
		return nil, nil, stats, err
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
			stats.ElapsedMS = float64(time.Since(started).Microseconds()) / 1000.0
			return nil, nil, stats, err
		}
		rec := make([]any, len(dest))
		for i, d := range dest {
			rec[i] = deref(reflect.ValueOf(d).Elem())
		}
		out = append(out, rec)
	}
	if err := rows.Err(); err != nil {
		stats.ElapsedMS = float64(time.Since(started).Microseconds()) / 1000.0
		return nil, nil, stats, err
	}
	if out == nil {
		// Never null: the client distinguishes "no rows in this window" from "the
		// request failed", and a null array collapses the two.
		out = [][]any{}
	}

	stats.ElapsedMS = float64(time.Since(started).Microseconds()) / 1000.0
	stats.ResultRows = len(out)
	return names, out, stats, nil
}

// deref unwraps the pointer a Nullable column scans into.
//
// A withheld peak is Nullable(UInt32), which the driver scans into **uint32. Left
// alone it marshals as a number-shaped object; unwrapped it marshals as a number
// or as JSON null, and null is exactly what "this rollup cannot answer that"
// should look like on the wire.
func deref(v reflect.Value) any {
	if v.Kind() == reflect.Ptr {
		if v.IsNil() {
			return nil
		}
		return deref(v.Elem())
	}
	return v.Interface()
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
