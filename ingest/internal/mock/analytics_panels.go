package mock

import (
	"fmt"
)

// The panel catalogue.
//
// Split out of analytics.go when panels stopped being fixed statements and
// became statements built from the reader's filter. The build is still not
// string-assembly-from-request-text: the database is an allowlisted literal, the
// column names come from `dimensions`, the rollup comes from `resolveMask`, and
// every VALUE is a bound parameter. There is nothing in a built statement that a
// caller chose the text of.

// panelShape names how a panel answers, which is what decides its SQL.
type panelShape int

const (
	// shapeSeries is one row per minute: the concurrency curve.
	shapeSeries panelShape = iota
	// shapeBreakdown is one row per value of a dimension.
	shapeBreakdown
	// shapeStatic is a fixed statement with no filter surface at all.
	shapeStatic
)

// panel is one chart's query.
type panel struct {
	// title and unit are returned to the client so the labelling lives with the
	// query rather than being restated in the UI, where it would drift.
	title string
	unit  string
	shape panelShape

	// breakdown is the dimension key a shapeBreakdown panel groups by. It joins
	// the reader's filter to form the question's dimension set, which is what
	// resolveMask answers.
	breakdown string

	// note is the panel's standing caveat, served with it rather than written in
	// the UI so the caveat and the query cannot drift apart.
	note string

	// static is the whole statement for shapeStatic panels.
	static func(db string) string
}

// panels is the whole surface. Adding a chart means adding an entry here.
var panels = map[string]panel{
	// The headline series.
	//
	// With no filter this reads the 'total' rollup, which is the ONLY rollup that
	// can answer an unfiltered question: the minute layer holds eleven
	// overlapping aggregations of the same traffic, so summing across them
	// measures 9,411.64 where the truth is 855.58.
	//
	// peak and average are both returned because they answer different questions
	// and the difference is large — peak 2,305 against an average of 855.58 over
	// the same hour. A chart showing only one of them invites the other to be
	// inferred from it.
	"concurrency": {
		title: "Concurrency over time",
		unit:  "sessions",
		shape: shapeSeries,
		note: "Peak is the exact maximum inside each minute; the second series is the time-weighted average. " +
			"They differ by roughly 2.7× over the hot hour, which is why both are drawn.",
	},

	// Exact peak per platform, read from whichever rollup carries
	// {platform} ∪ the reader's filter.
	//
	// This is the panel where the rollup choice is load-bearing rather than
	// merely efficient. peaked_at is returned alongside because the instants
	// differ — measured ANDROID_PHONE at 10:55 against SONY_ANDROID_TV at 10:53 —
	// and that is the evidence for why these bars must not be added together.
	"platform_peak": {
		title:     "Peak by platform",
		unit:      "sessions",
		shape:     shapeBreakdown,
		breakdown: "platform",
		note: "Each bar is that platform's own peak. They must not be added: the platforms peak at " +
			"different instants, so their sum exceeds the true total.",
	},

	// Content type: live against vod against unclassified.
	//
	// 'unknown' is a REAL value here, carried by 1,089 catalogue titles, so it is
	// charted rather than filtered out. Dropping it would silently remove real
	// viewing — measured 23.66 viewer-hours across 105 watched titles in the hot
	// hour — and a chart that does not sum to the total is worse than an ugly bar.
	"video_type_hours": {
		title:     "Viewer-hours by content type",
		unit:      "hours",
		shape:     shapeBreakdown,
		breakdown: "video_type",
		note: "'unknown' is a real catalogue value carried by 1,089 titles, not a missing one, " +
			"so it is charted rather than dropped.",
	},

	"category_hours": {
		title:     "Viewer-hours by category",
		unit:      "hours",
		shape:     shapeBreakdown,
		breakdown: "category",
		note: "Viewer-hours is sum(active_ms), which is additive across every dimension — so unlike " +
			"the peak panels, these bars do total correctly.",
	},

	"country_hours": {
		title:     "Viewer-hours by country",
		unit:      "hours",
		shape:     shapeBreakdown,
		breakdown: "country",
		note:      "Ranked by viewer-hours. The extract carries a single country, so this is a one-bar chart on it.",
	},

	"app_version_peak": {
		title:     "Peak by app version",
		unit:      "sessions",
		shape:     shapeBreakdown,
		breakdown: "app_version",
		note:      "Useful as a rollout signal: a version whose peak collapses between two windows is the one to look at.",
	},

	// Title leaderboard, ranked by viewer-hours rather than by peak.
	//
	// viewer_hours is sum(active_ms), which is additive, so the ranking is
	// meaningful and the total is the sum of its parts. Ranking by peak would
	// order titles by their busiest instant, which rewards a brief spike over a
	// long watch and cannot be totalled.
	"top_titles": {
		title:     "Top titles by viewer-hours",
		unit:      "hours",
		shape:     shapeBreakdown,
		breakdown: "title",
		note: "Ranked by viewer-hours, not peak: ranking by peak rewards a brief spike over a long watch, " +
			"and peaks cannot be totalled.",
	},

	// How current each serving layer is. The first thing to read before treating
	// any recent dip as a drop: the minute layer publishes on a deliberate lag, so
	// unpublished minutes are ABSENT, not empty, and a stalled pipeline and an
	// outage have exactly the same shape on a chart.
	//
	// Static: freshness is a property of the pipeline, not of a slice of traffic,
	// so a dimension filter would be meaningless on it.
	"freshness": {
		title: "Serving layer freshness",
		unit:  "seconds",
		shape: shapeStatic,
		note: "Read this before treating any recent dip as a drop. The minute layer publishes on a deliberate " +
			"lag, so unpublished minutes are absent rather than zero — a stalled pipeline and an outage have " +
			"the same shape on a chart.",
		static: func(db string) string {
			return fmt.Sprintf(`SELECT
    layer,
    toString(watermark_ts)                            AS watermark,
    toUInt32(dateDiff('second', built_at, now()))     AS built_age_s,
    toUInt32(dateDiff('second', watermark_ts, now())) AS data_lag_s,
    toUInt64(rows_out)                                AS rows_out
FROM %[1]s.serving_watermark FINAL
ORDER BY layer
LIMIT {cap:UInt32}`, db)
		},
	},
}

// buildSQL renders a panel against a database, a resolved rollup and a filter.
//
// It returns the statement only. The caller binds from/to/cap and the filter's
// values as named parameters — see analyticsFilter.predicates.
func buildSQL(db string, p panel, m maskChoice, f analyticsFilter, g grain) string {
	if p.shape == shapeStatic {
		return p.static(db)
	}

	where, _ := f.predicates()

	// peak is emitted as a real column only when the rollup answers the question
	// exactly. Otherwise it is a typed NULL, so the column still exists — the
	// client renders one shape whether or not the peak is available, and the
	// absence is a value rather than a missing key.
	peakExpr := "CAST(NULL AS Nullable(UInt32))"
	if m.ExactPeak {
		peakExpr = "toUInt32(max(minute_peak))"
	}

	if p.shape == shapeSeries {
		// The column stays named `minute` at every grain, and that is deliberate
		// rather than lazy. It is the series' time axis; renaming it to `hour` on
		// one setting would make the client match on the grain to find its own
		// x-values, which is exactly the coupling `col(d, "minute")` exists to
		// avoid. The grain is reported as its own field in the response.
		//
		// The average's divisor comes from the grain, not from a literal 60000.
		// sum(active_ms) over an hour of minute rows is milliseconds of viewing
		// inside that hour, so the time-weighted mean concurrency is that over the
		// hour's own length. Leaving the minute divisor in place would multiply
		// the hour series by 60 while leaving its shape untouched — a wrong
		// answer that looks entirely plausible next to a correct peak.
		return fmt.Sprintf(`SELECT
    toString(%[4]s)                     AS minute,
    %[2]s                               AS peak,
    round(sum(active_ms) / %[5]d.0, 3)  AS average
FROM %[1]s.serving_minute_current
WHERE grouping = {grouping:String}
  AND minute_start >= toDateTime({from:String}, 'UTC')
  AND minute_start <  toDateTime({to:String},   'UTC')%[3]s
GROUP BY %[4]s
ORDER BY %[4]s
LIMIT {cap:UInt32}`, db, peakExpr, where, g.bucketExpr(), g.Seconds*1000)
	}

	// shapeBreakdown.
	d, ok := dimensionByKey(p.breakdown)
	if !ok {
		// Unreachable via the catalogue above; a panel with an unknown breakdown is
		// a programming error, and returning a statement that fails loudly beats
		// returning one that quietly answers a different question.
		return fmt.Sprintf("SELECT throwIf(1, 'panel %s has unknown breakdown %q')", p.title, p.breakdown)
	}

	// peaked_at is only meaningful when the peak itself is.
	peakedAt := "''"
	if m.ExactPeak {
		peakedAt = "toString(argMax(minute_start, minute_peak))"
	}

	return fmt.Sprintf(`SELECT
    %[2]s                                    AS %[2]s,
    %[3]s                                    AS peak,
    %[4]s                                    AS peaked_at,
    round(sum(active_ms) / 3600000.0, 3)     AS viewer_hours
FROM %[1]s.serving_minute_current
WHERE grouping = {grouping:String}
  AND minute_start >= toDateTime({from:String}, 'UTC')
  AND minute_start <  toDateTime({to:String},   'UTC')
  AND %[2]s != ''%[5]s
GROUP BY %[2]s
ORDER BY %[6]s DESC
LIMIT {cap:UInt32}`, db, d.Column, peakExpr, peakedAt, where, breakdownOrder(p, m))
}

// breakdownOrder ranks a breakdown by the quantity its unit names.
//
// A peak panel ranked by viewer-hours puts the tallest bar somewhere other than
// first, which reads as a rendering bug rather than as a sort choice. When the
// peak is withheld there is nothing to rank by but viewer-hours, which is exact
// at every rollup.
func breakdownOrder(p panel, m maskChoice) string {
	if p.unit == "sessions" && m.ExactPeak {
		return "peak"
	}
	return "viewer_hours"
}

// questionKeys is the dimension set a panel's question pins down: whatever the
// reader filtered, plus whatever the panel breaks down by.
func questionKeys(p panel, f analyticsFilter) []string {
	keys := f.keys()
	if p.shape == shapeBreakdown && p.breakdown != "" {
		keys = append(keys, p.breakdown)
	}
	return keys
}

// filterSummary renders the resolved question for the UI's caption line.
func filterSummary(_ panel, f analyticsFilter) string {
	if f.empty() {
		return "no filter"
	}
	return f.describe()
}
