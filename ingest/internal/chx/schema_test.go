package chx

import (
	"strings"
	"testing"
)

// TestSplitStatementsIsCommentAware guards the DDL loader against the thing a
// naive strings.Split(sql, ";") gets wrong: the schema is heavily commented and
// those comments contain both semicolons and apostrophes.
func TestSplitStatementsIsCommentAware(t *testing.T) {
	sql := `
-- A comment with a semicolon; and an apostrophe's worth of trouble.
CREATE TABLE a (x UInt8) ENGINE = Memory;

/* block comment;
   spanning lines; with semicolons */
CREATE TABLE b (
    y String DEFAULT 'a;b',            -- literal containing a semicolon
    z String MATERIALIZED splitByChar('-', y)[1]
) ENGINE = Memory;
`
	got := splitStatements(sql)
	if len(got) != 2 {
		t.Fatalf("got %d statements, want 2:\n%q", len(got), got)
	}
	if !strings.HasPrefix(got[0], "CREATE TABLE a") {
		t.Errorf("statement 0 = %q", got[0])
	}
	if !strings.Contains(got[1], `'a;b'`) {
		t.Errorf("statement 1 lost its literal: %q", got[1])
	}
	if !strings.Contains(got[1], `splitByChar('-', y)`) {
		t.Errorf("statement 1 lost the quoted dash: %q", got[1])
	}
	for i, s := range got {
		if strings.Contains(s, "block comment") || strings.Contains(s, "worth of trouble") {
			t.Errorf("statement %d retained a comment: %q", i, s)
		}
	}
}

// TestSplitStatementsHandlesEscapes: the schema uses '\x1F' in a string literal.
func TestSplitStatementsHandlesEscapes(t *testing.T) {
	sql := `SELECT concatWithSeparator('\x1F', a, b); SELECT 1;`
	got := splitStatements(sql)
	if len(got) != 2 {
		t.Fatalf("got %d statements, want 2: %q", len(got), got)
	}
	if !strings.Contains(got[0], `'\x1F'`) {
		t.Errorf("escape sequence mangled: %q", got[0])
	}
}

// TestSchemaStatementsLoad checks the embedded DDL parses into the expected
// objects — a missing file or a stray semicolon would otherwise only show up
// against a live server.
func TestSchemaStatementsLoad(t *testing.T) {
	stmts, err := SchemaStatements()
	if err != nil {
		t.Fatalf("SchemaStatements: %v", err)
	}
	if len(stmts) == 0 {
		t.Fatal("no statements loaded from the embedded sql/ directory")
	}

	joined := strings.ToUpper(strings.Join(func() []string {
		out := make([]string, len(stmts))
		for i, s := range stmts {
			out[i] = s.SQL
		}
		return out
	}(), "\n"))

	for _, want := range []string{
		"SL_CONTENT_DIM", "SL_CONTENT_CURRENT", "SL_CONTENT_DICT",
		"SL_RAW_EVENTS", "SL_DIRTY_SESSIONS", "SL_RAW_TO_DIRTY_MV",
		"SL_INGEST_BATCHES", "SL_INGEST_REJECTS",
	} {
		if !strings.Contains(joined, want) {
			t.Errorf("embedded schema is missing %s", want)
		}
	}

	// Every statement must be idempotent, or `schema` stops being re-runnable.
	// ALTER ... MODIFY SETTING qualifies: it is metadata-only and converges to
	// the same state however many times it runs. It is also the only way a
	// settings correction reaches a database that already has the tables, since
	// CREATE TABLE IF NOT EXISTS is a no-op there.
	for _, s := range stmts {
		u := strings.ToUpper(s.SQL)
		idempotent := strings.Contains(u, "IF NOT EXISTS") ||
			strings.Contains(u, "OR REPLACE") ||
			strings.Contains(u, "MODIFY SETTING")
		if !idempotent {
			t.Errorf("%s[%d] is not idempotent: %s", s.File, s.Index, s.Summary())
		}
	}
}

// TestDedupSettingsCoverBothEngineFamilies.
//
// Which deduplication window a table honours is chosen by the engine, not by
// the DDL: a local MergeTree reads non_replicated_deduplication_window, and the
// SharedMergeTree that ClickHouse Cloud creates from the same statement reads
// the replicated_* pair instead. Setting only the first is the trap — it passes
// every local test and silently stops deduplicating in production.
func TestDedupSettingsCoverBothEngineFamilies(t *testing.T) {
	stmts, err := SchemaStatements()
	if err != nil {
		t.Fatalf("SchemaStatements: %v", err)
	}

	// Tables that carry a deduplication guarantee, and the statement kinds that
	// must state it for both engine families.
	for _, table := range []string{"SL_RAW_EVENTS", "SL_CONTENT_DIM"} {
		var stated bool
		for _, s := range stmts {
			u := strings.ToUpper(s.SQL)
			if !strings.Contains(u, table) {
				continue
			}
			if !strings.Contains(u, "NON_REPLICATED_DEDUPLICATION_WINDOW") {
				continue
			}
			if !strings.Contains(u, "REPLICATED_DEDUPLICATION_WINDOW =") {
				t.Errorf("%s states non_replicated_deduplication_window without the replicated "+
					"equivalent: deduplication would be off on ClickHouse Cloud", table)
			}
			// The replicated window also expires on a timer (server default
			// 3600s) where the non-replicated one never does.
			if !strings.Contains(u, "REPLICATED_DEDUPLICATION_WINDOW_SECONDS") {
				t.Errorf("%s does not override replicated_deduplication_window_seconds: "+
					"replay stops being a no-op an hour after the load", table)
			}
			stated = true
		}
		if !stated {
			t.Errorf("no deduplication settings found for %s", table)
		}
	}
}

// TestContentDictionaryKeepsASignedKey.
//
// A simple-key dictionary key is always UInt64 — ClickHouse coerces the
// declared Int64 without complaint and then throws on any lookup of a negative
// id. The catalogue contains one (-987654322), so a plain LAYOUT(HASHED())
// makes enrichment fail on real data while looking correct in the DDL. This is
// asserted statically because reproducing it needs both a live server and an
// event that references that specific id.
func TestContentDictionaryKeepsASignedKey(t *testing.T) {
	stmts, err := SchemaStatements()
	if err != nil {
		t.Fatalf("SchemaStatements: %v", err)
	}

	var dict string
	for _, s := range stmts {
		if strings.Contains(strings.ToUpper(s.SQL), "CREATE OR REPLACE DICTIONARY") {
			dict = strings.ToUpper(s.SQL)
			break
		}
	}
	if dict == "" {
		t.Fatal("no CREATE DICTIONARY statement found in the embedded schema")
	}

	if !strings.Contains(dict, "COMPLEX_KEY_HASHED") {
		t.Error("the content dictionary must use COMPLEX_KEY_HASHED: a simple key is " +
			"coerced to UInt64 and every lookup of the catalogue's negative content_id throws")
	}
	if !strings.Contains(dict, "CONTENT_ID  INT64") {
		t.Error("the dictionary key must stay Int64 to match sl_content_dim")
	}
}

// TestRenderRedactsPassword: dry-run output and error messages are meant to be
// pasted into a review, so the dictionary's credentials must not ride along.
func TestRenderRedactsPassword(t *testing.T) {
	c := &Client{Database: "default", user: "svc", password: "s3cr3t"}

	const tmpl = `SOURCE(CLICKHOUSE(DB '{{db}}' USER '{{ch_user}}' PASSWORD '{{ch_password}}'))`

	redacted := c.Render(tmpl, true)
	if strings.Contains(redacted, "s3cr3t") {
		t.Errorf("redacted render leaked the password: %s", redacted)
	}
	if !strings.Contains(redacted, "'default'") || !strings.Contains(redacted, "'svc'") {
		t.Errorf("redacted render dropped non-secret substitutions: %s", redacted)
	}

	live := c.Render(tmpl, false)
	if !strings.Contains(live, "'s3cr3t'") {
		t.Errorf("live render did not substitute the password: %s", live)
	}
}

func TestEscapeSQLString(t *testing.T) {
	// A password containing a quote must not be able to close the literal.
	got := escapeSQLString(`pa'ss\word`)
	if want := `pa\'ss\\word`; got != want {
		t.Errorf("escapeSQLString = %q, want %q", got, want)
	}
}
