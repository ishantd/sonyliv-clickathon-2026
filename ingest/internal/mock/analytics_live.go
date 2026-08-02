package mock

import (
	"fmt"

	"github.com/sonyliv-clickathon/ingest/concurrency"
)

// The Live sessions panel.
//
// In its own file, and registered from init() rather than written into the
// literal in analytics_panels.go, for one reason: this panel reads a table the
// OTHER pipeline in this service also owns, and it is the only panel whose
// statement has to run unchanged against a database this repo does not write.
// Keeping it separate makes that coupling visible instead of burying it in a
// catalogue entry. Package-level variables are initialised before any init()
// runs, so `panels` exists by the time this fires.
func init() {
	panels["live_sessions"] = panel{
		title: "Live sessions",
		unit:  "sessions",
		shape: shapeStatic,
		note: "Per-session CURRENT state, resolved through argMaxMerge over every revision a session " +
			"has — not a slice of the concurrency curve. It is best-effort and continuously rebuilt: " +
			"the open tail moves with every heartbeat, the lease is evaluated against now() at read " +
			"time, and a session that goes silent falls out of active_now with nothing written. This " +
			"is a different measurement from the minute tier, which is bucketed, sealed and published " +
			"on a lag — the two will not agree instant for instant, and neither is wrong.",
		static: liveSessionsSQL,
	}
}

// liveSessionsSQL is one statement that has to answer on both pipelines.
//
// `sonyliv` (the delta/checkpoint pipeline) and `sonyliv_demo` (the interval-array
// pipeline) each maintain their own session_live_state, with deliberately
// identical column names and aggregate signatures — see
// ingest/sql/012_session_live_state.sql. So the dataset selector changes the
// database and nothing else. That is only true while both DDLs agree; if one
// gains a column the other has not got, this panel is where it breaks.
//
// MISSING TABLE. sonyliv_prod and sonyliv_unseen are selectable and do NOT carry
// this table. No guard is needed and none is added: handleAnalytics returns HTTP
// 200 with the ClickHouse error in the response's `error` field, and the message
// ("Table sonyliv_prod.session_live_state does not exist") names the missing
// object, which is more use to a reader than an empty result set from a
// system.tables probe would be. Guarding would trade a precise error for a blank
// chart.
//
// NEVER FINAL. The table comment says so and docs/TABLE-CONTRACT.md explains
// why: -Merge under GROUP BY is exact against a table on which no merge has run,
// and on this service merges are eventual to the point of never — a two-part
// partition sat unmerged for 115 minutes with nothing scheduled. FINAL would also
// be wrong rather than merely slow here, because these are AggregateFunction
// columns holding one row per recompaction pass, not whole-row replacements.
func liveSessionsSQL(db string) string {
	return fmt.Sprintf(`SELECT
    platform,
    -- "Open" is the absence of a VideoSessionEnd, which is not the same as being
    -- active: a lapsed session can come back, a terminated one never can.
    countIf(is_terminated = 0)                                                     AS open_sessions,
    -- The lease is compared to now() HERE, at read time. It is a wall-clock
    -- instant at which by definition no event arrives, so nothing can write the
    -- moment it passes.
    countIf(is_terminated = 0 AND is_active_now = 1 AND lease_expiry > now64(3, 'UTC')) AS active_now,
    countIf(is_terminated = 1)                                                     AS terminated,
    -- How long ago the median open session's lease lapsed. Zero while it is still
    -- in the future, so a live cohort reads near zero and a settled one reads as
    -- the age of the data.
    --
    -- ifNotFinite is not defensive padding. A platform on which EVERY session is
    -- terminated gives medianIf an empty set, which returns nan, and toUInt32(nan)
    -- throws CANNOT_CONVERT_TYPE and takes the whole panel down — measured against
    -- sonyliv, where the row still has a real terminated count worth showing.
    toUInt32(ifNotFinite(medianIf(greatest(0, dateDiff('second', lease_expiry, now64(3, 'UTC'))), is_terminated = 0), 0)) AS median_lease_age_s
FROM
(
    SELECT
        session_key,
        argMaxMerge(platform)      AS platform,
        argMaxMerge(lease_expiry)  AS lease_expiry,
        argMaxMerge(is_active_now) AS is_active_now,
        argMaxMerge(is_terminated) AS is_terminated
    FROM %[1]s.session_live_state
    -- policy_version leads the sort key, so pinning it makes GROUP BY session_key
    -- an exact key prefix that streams instead of re-sorting.
    WHERE policy_version = '%[2]s'
    GROUP BY session_key
)
GROUP BY platform
ORDER BY open_sessions DESC
LIMIT {cap:UInt32}`, db, concurrency.DefaultPolicyVersion)
}
