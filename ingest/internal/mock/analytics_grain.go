package mock

import "strings"

// Time granularity for the concurrency series.
//
// WHY THIS IS A SERVER CONCERN AND NOT A CHART OPTION. Rolling minutes up to
// hours is not resampling a line — the two series on the curve aggregate
// differently and only one of them survives being averaged:
//
//   - peak is a MAXIMUM. The peak of an hour is the largest of its minutes'
//     peaks, so `max(minute_peak)` is exact at any coarser bucket. It is not the
//     mean of them, and it is not the peak of the hour's own summed traffic.
//   - average is TIME-WEIGHTED, so it is `sum(active_ms)` over the bucket's
//     wall-clock length. That divisor changes with the grain, and getting it
//     wrong scales the whole series by 60 without changing its shape — which is
//     exactly the kind of error a chart cannot show you.
//
// Doing it in SQL also means the wire carries 24 rows for a day at hour grain
// rather than 1,440, so the coarser grain is genuinely cheaper rather than the
// same payload drawn smaller.
//
// The set is closed and its members are compile-time literals. `grain` reaches
// the SQL as an interpolated expression, not a bound parameter — a bucket
// function cannot be one — so it must never be assembled from request text. The
// request selects a KEY FROM THIS TABLE; anything unrecognised falls back to
// minute rather than erroring, because a stale bookmark asking for a grain we
// removed should draw the finest series, not a red panel.

type grain struct {
	Key   string `json:"key"`
	Label string `json:"label"`
	// Seconds is the bucket's wall-clock length. The UI uses it to warn that a
	// window is too short to produce a useful number of buckets; the SQL uses it
	// as the time-weighted average's divisor.
	Seconds int `json:"seconds"`

	// bucket wraps minute_start in the ClickHouse function that floors it to this
	// grain. Unexported: it is SQL, and it has no business being on the wire.
	bucket string
}

// grains is the whole surface, in ascending order so the UI renders it as a
// scale rather than a menu.
//
// No week or month. The extract is thirteen days and the evaluation set is one,
// so a month bucket would produce a single bar on every dataset we have —
// a control whose every setting gives the same answer is furniture.
var grains = []grain{
	{Key: "minute", Label: "Minute", Seconds: 60, bucket: "minute_start"},
	{Key: "hour", Label: "Hour", Seconds: 3600, bucket: "toStartOfHour(minute_start)"},
	{Key: "day", Label: "Day", Seconds: 86400, bucket: "toStartOfDay(minute_start)"},
}

// defaultGrain is what an unspecified or unrecognised request gets.
//
// Minute, because it is the grain the serving tier is actually materialised at:
// it is the only setting where the chart and the storage agree row for row, and
// therefore the only honest default for a page whose whole claim is that the
// numbers come from a pre-aggregated tier rather than from a rescan.
const defaultGrain = "minute"

// resolveGrain maps a request's `grain` to one of the literals above.
//
// Never errors. See the note at the top of this file: an unknown grain is a
// stale link, and the finest series is a correct answer to it.
func resolveGrain(requested string) grain {
	for _, g := range grains {
		if g.Key == requested {
			return g
		}
	}
	for _, g := range grains {
		if g.Key == defaultGrain {
			return g
		}
	}
	return grains[0]
}

// panelNote rewrites the series panel's standing caveat for the grain that ran.
//
// The catalogue's note is written for minute grain — "the exact maximum inside
// each minute" — and served verbatim it becomes false the moment someone picks
// hour. That matters more than it reads: peak and average differ by roughly 2.7x
// over the hot hour, so a caption that misnames the bucket misdescribes the
// number a reader is about to quote.
//
// The invariance is stated here rather than left to be noticed, because it is
// the counter-intuitive half. Coarsening the bucket does NOT lower the peak —
// an hour's peak IS the largest of its minutes' peaks — so only the average
// moves. Someone who expects a smoother, smaller peak at day grain and gets the
// same number should be told why on the panel, not have to work it out.
//
// Only the series panel buckets. Everything else gets its note unchanged.
func panelNote(p panel, g grain) string {
	if p.shape != shapeSeries {
		return p.note
	}
	unit := strings.ToLower(g.Label)
	return "Peak is the exact maximum inside each " + unit +
		"; the second series is the time-weighted average over the " + unit + ". " +
		"Coarsening the grain does not change the peak — the peak of an hour is the largest of its " +
		"minutes' peaks — so only the average rescales."
}
