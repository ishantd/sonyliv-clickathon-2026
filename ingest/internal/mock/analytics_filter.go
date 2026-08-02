package mock

import (
	"fmt"
	"net/url"
	"sort"
	"strings"

	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"
	"github.com/sonyliv-clickathon/ingest/internal/chx"
)

// Dataset filters over the minute serving tier.
//
// WHY THIS FILE EXISTS. The track's submission guidelines make filters mandatory
// and require them to apply to the concurrency curve as well as to every other
// view. That is not a UI problem. `serving_minute_current` holds eleven
// overlapping aggregations of the same traffic, and which one a filtered
// question must be answered from depends on the exact SET of dimensions the
// question pins down. Choosing the wrong one does not error; it returns a
// plausible number that is wrong. So the mapping from "what the reader filtered"
// to "which rollup answers it" lives here, in one place, with the exactness of
// the answer carried alongside the answer.
//
// THE RULE, stated once. A peak is exact only at its own grouping. If the reader
// pins platform and the panel breaks down by title, the question is
// {platform, content} and only the `platform + content` rollup can answer it —
// taking max(minute_peak) over a finer rollup returns the busiest single
// combination, and over a coarser one returns a number that includes traffic the
// filter excluded. Viewer-hours (sum of active_ms) has no such problem: it is
// additive, so it is exact at any rollup that refines the question.

// A filterable dimension of the dataset.
//
// Column is the typed column on serving_minute_current, which is populated
// exactly for the dimensions its row's rollup carries. Grouping is the
// single-dimension rollup that carries it, used to list that dimension's values.
type dimension struct {
	Key      string `json:"key"`
	Label    string `json:"label"`
	Column   string `json:"column"`
	Grouping string `json:"grouping"`
	// Source names the column in the raw event stream that this filter ultimately
	// comes from. Returned to the client so the README's "which dataset column
	// backs each filter" table can be read straight off the running service
	// rather than maintained by hand.
	Source string `json:"source"`
}

// dimensions is the filter surface, in the order the UI shows them.
//
// content_id is deliberately NOT here as a separate filter. Title is what a
// reader recognises, it is functionally determined by content_id, and offering
// both would let the two disagree.
var dimensions = []dimension{
	{Key: "platform", Label: "Platform", Column: "platform", Grouping: "platform", Source: "events.platform"},
	{Key: "country", Label: "Country", Column: "country", Grouping: "country", Source: "events.country"},
	{Key: "video_type", Label: "Content type", Column: "video_type", Grouping: "video type", Source: "content_dim.video_type (via events.content_id)"},
	{Key: "category", Label: "Category", Column: "category", Grouping: "category", Source: "content_dim.category (via events.content_id)"},
	{Key: "app_version", Label: "App version", Column: "app_version", Grouping: "app version", Source: "events.app_version"},
	{Key: "title", Label: "Title", Column: "title", Grouping: "content", Source: "content_dim.title (via events.content_id)"},
}

func dimensionByKey(key string) (dimension, bool) {
	for _, d := range dimensions {
		if d.Key == key {
			return d, true
		}
	}
	return dimension{}, false
}

// rollups maps a SET of dimension keys to the grouping that answers it exactly.
//
// The keys are the dimension keys sorted and joined with "|", so the map is
// keyed by the set rather than by an order the caller happened to use.
//
// This list is not a policy choice made here — it is the set of masks
// pipeline/sql materialises, restated. Masks 6, 7, 10, 11, 13 and 14 of the
// bitmask are not built, which is why (for example) {country, video_type} is
// absent below. Adding one there without adding it to the pipeline would make
// this file lie.
var rollups = map[string]string{
	"":                    "total",
	"platform":            "platform",
	"country":             "country",
	"video_type":          "video type",
	"category":            "category",
	"app_version":         "app version",
	"title":               "content",
	"platform|title":      "platform + content",
	"country|platform":    "platform + country",
	"platform|video_type": "platform + video type",
	"app_version|category|country|platform|title|video_type": "all dimensions",
}

// finest is the rollup that refines every question, used when no rollup answers
// the asked-for set exactly. It carries all six dimensions, so filtering it by
// any subset selects exactly the traffic asked for — which makes sums exact and
// peaks unavailable, not approximate.
const finest = "all dimensions"

// maskChoice is the resolved answer to "which rollup, and can it carry a peak".
type maskChoice struct {
	// Grouping is the value to match on serving_minute_current.grouping.
	Grouping string `json:"grouping"`
	// ExactPeak reports whether max(minute_peak) over this rollup is the peak of
	// the question that was asked. False means the peak is WITHHELD, not
	// estimated: the panel returns NULL for it and the UI says why.
	ExactPeak bool `json:"exact_peak"`
	// Why explains the choice in one sentence, and is rendered in the UI. A
	// reader who cannot see why a peak is missing will assume the pipeline is
	// broken.
	Why string `json:"why"`
}

// resolveMask picks the rollup for a question pinned to the given dimension set.
//
// keys may repeat or arrive in any order; the set is what matters.
func resolveMask(keys []string) maskChoice {
	seen := map[string]bool{}
	set := make([]string, 0, len(keys))
	for _, k := range keys {
		if k == "" || seen[k] {
			continue
		}
		if _, ok := dimensionByKey(k); !ok {
			continue
		}
		seen[k] = true
		set = append(set, k)
	}
	sort.Strings(set)

	if g, ok := rollups[strings.Join(set, "|")]; ok {
		return maskChoice{
			Grouping:  g,
			ExactPeak: true,
			Why:       fmt.Sprintf("Read from the %q rollup, which is materialised at exactly this combination, so the peak is exact.", g),
		}
	}
	return maskChoice{
		Grouping:  finest,
		ExactPeak: false,
		Why: fmt.Sprintf("No rollup is materialised at this combination (%s), so this reads the %q rollup. "+
			"Viewer-hours stays exact because it is additive; the peak is withheld, because the maximum over a finer "+
			"grain is the busiest single combination and not the peak of this slice.",
			strings.Join(set, " + "), finest),
	}
}

// analyticsFilter is the reader's selection: dimension key -> pinned value.
type analyticsFilter struct {
	values map[string]string
}

// parseFilter reads the dimension parameters off a query string.
//
// Unknown parameters are ignored rather than rejected: the window, the row cap
// and the database all travel in the same query string, and a strict reader here
// would reject every legitimate request.
func parseFilter(q url.Values) analyticsFilter {
	f := analyticsFilter{values: map[string]string{}}
	for _, d := range dimensions {
		if v := strings.TrimSpace(q.Get(d.Key)); v != "" {
			f.values[d.Key] = v
		}
	}
	return f
}

// keys returns the pinned dimensions, sorted.
func (f analyticsFilter) keys() []string {
	out := make([]string, 0, len(f.values))
	for k := range f.values {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

func (f analyticsFilter) empty() bool { return len(f.values) == 0 }

// predicates renders the filter as SQL, with every VALUE bound rather than
// interpolated.
//
// The column names come from `dimensions`, which is a compile-time list, and the
// values are named parameters — so nothing a caller sends reaches the statement
// as text. That matters more here than on the unfiltered panels: these values
// are free-form strings a reader types into a title box.
func (f analyticsFilter) predicates() (sql string, args []driver.NamedValue) {
	for _, k := range f.keys() {
		d, ok := dimensionByKey(k)
		if !ok {
			continue
		}
		param := "f_" + d.Key
		sql += fmt.Sprintf("\n  AND %s = {%s:String}", d.Column, param)
		args = append(args, chx.Named(param, f.values[k]))
	}
	return sql, args
}

// describe renders the filter for a caption, e.g. `platform = ANDROID_TV`.
func (f analyticsFilter) describe() string {
	parts := make([]string, 0, len(f.values))
	for _, k := range f.keys() {
		parts = append(parts, fmt.Sprintf("%s = %s", k, f.values[k]))
	}
	return strings.Join(parts, " · ")
}
