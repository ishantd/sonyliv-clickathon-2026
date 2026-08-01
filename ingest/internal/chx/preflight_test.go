package chx

import (
	"strings"
	"testing"
)

// The engine_full ClickHouse actually returns for sl_raw_events. Kept verbatim
// because the ORDER BY tuple's commas are the thing that broke the first
// parser: splitting the whole string on "," puts "event) SETTINGS
// non_replicated_deduplication_window" in one chunk, and the first setting
// silently reads as unset — a false clean bill of health from `doctor`.
const rawEventsEngineFull = "MergeTree PARTITION BY toYYYYMMDD(session_start_time) " +
	"ORDER BY (video_session_id, event_time, event_type, event) " +
	"SETTINGS non_replicated_deduplication_window = 1000, " +
	"replicated_deduplication_window = 1000, " +
	"replicated_deduplication_window_seconds = 2592000, index_granularity = 8192"

func TestSettingFromParsesPastTheOrderByTuple(t *testing.T) {
	for _, tc := range []struct{ name, want string }{
		{"non_replicated_deduplication_window", "1000"},
		{"replicated_deduplication_window", "1000"},
		{"replicated_deduplication_window_seconds", "2592000"},
		{"index_granularity", "8192"},
		{"not_a_setting", ""},
	} {
		if got := settingFrom(rawEventsEngineFull, tc.name); got != tc.want {
			t.Errorf("settingFrom(%s) = %q, want %q", tc.name, got, tc.want)
		}
	}

	// A setting name must not match as a prefix of a longer one.
	short := "MergeTree ORDER BY a SETTINGS replicated_deduplication_window_seconds = 2592000"
	if got := settingFrom(short, "replicated_deduplication_window"); got != "" {
		t.Errorf("prefix match leaked: got %q, want empty", got)
	}

	if got := settingFrom("MergeTree ORDER BY a", "anything"); got != "" {
		t.Errorf("a table with no SETTINGS clause returned %q", got)
	}
}

func TestIsReplicatedEngine(t *testing.T) {
	// SharedMergeTree is what ClickHouse Cloud substitutes for MergeTree, and
	// it deduplicates through the replicated window.
	for _, e := range []string{"ReplicatedMergeTree", "SharedMergeTree", "SharedReplacingMergeTree"} {
		if !IsReplicatedEngine(e) {
			t.Errorf("%s should be treated as replicated", e)
		}
	}
	for _, e := range []string{"MergeTree", "ReplacingMergeTree", ""} {
		if IsReplicatedEngine(e) {
			t.Errorf("%s should not be treated as replicated", e)
		}
	}
}

// TestProblemsCatchesTheCloudDedupTrap covers the case a single-node test
// cluster cannot produce: a SharedMergeTree carrying the server defaults. The
// load would succeed and the idempotency guarantee would be quietly gone.
func TestProblemsCatchesTheCloudDedupTrap(t *testing.T) {
	report := &PreflightReport{
		Tables: []TableSettings{{
			Name:   "sl_raw_events",
			Exists: true,
			Engine: "SharedMergeTree",
			// Set on the table, but the timer is left at the default.
			NonReplicatedWindow:     "1000",
			ReplicatedWindow:        "1000",
			ReplicatedWindowSeconds: defaultReplicatedWindowSeconds,
		}},
	}

	problems := report.Problems("default")
	if len(problems) != 1 {
		t.Fatalf("got %d problems, want 1: %v", len(problems), problems)
	}
	if !strings.Contains(problems[0], "replicated_deduplication_window_seconds") {
		t.Errorf("problem does not name the expiring window: %s", problems[0])
	}
}

func TestProblemsCatchesAnUnsetReplicatedWindow(t *testing.T) {
	report := &PreflightReport{
		Tables: []TableSettings{{
			Name:                    "sl_content_dim",
			Exists:                  true,
			Engine:                  "SharedReplacingMergeTree",
			NonReplicatedWindow:     "100",
			ReplicatedWindow:        "0",
			ReplicatedWindowSeconds: "2592000",
		}},
	}
	problems := report.Problems("default")
	if len(problems) != 1 || !strings.Contains(problems[0], "duplicate rows") {
		t.Fatalf("an unset replicated window was not flagged: %v", problems)
	}
}

// TestProblemsIgnoresTheLocalEngine: the non-replicated window has no timer, so
// the same settings that are a problem on Cloud are correct on a laptop.
// Flagging them there would train the operator to ignore the warning.
func TestProblemsIsQuietOnANonReplicatedEngine(t *testing.T) {
	report := &PreflightReport{
		Tables: []TableSettings{{
			Name:                    "sl_raw_events",
			Exists:                  true,
			Engine:                  "MergeTree",
			NonReplicatedWindow:     "1000",
			ReplicatedWindow:        "10000",
			ReplicatedWindowSeconds: defaultReplicatedWindowSeconds,
		}},
	}
	if problems := report.Problems("default"); len(problems) != 0 {
		t.Errorf("a correctly configured local table was flagged: %v", problems)
	}
}

func TestProblemsSkipsTablesThatDoNotExistYet(t *testing.T) {
	report := &PreflightReport{
		Tables: []TableSettings{{Name: "sl_raw_events", Exists: false}},
	}
	if problems := report.Problems("default"); len(problems) != 0 {
		t.Errorf("a not-yet-created table was flagged: %v", problems)
	}
}

func TestProblemsReportsMissingGrants(t *testing.T) {
	report := &PreflightReport{MissingGrants: []string{"SELECT from system tables"}}
	problems := report.Problems("readonly_user")
	if len(problems) != 1 || !strings.Contains(problems[0], "readonly_user") {
		t.Fatalf("missing grant not reported against the user: %v", problems)
	}
}
