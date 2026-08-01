// Command sonyliv-ingest loads the supplied CSV extracts into ClickHouse.
//
//	sonyliv-ingest schema                       apply the DDL (idempotent)
//	sonyliv-ingest content --file <content.csv> load the content catalogue
//	sonyliv-ingest events  --file <raw.csv>     load the event stream
//	sonyliv-ingest verify                       post-load integrity report
//
// Every subcommand reads connection settings from .env / the environment.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/signal"
	"path/filepath"
	"reflect"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/google/uuid"

	"github.com/sonyliv-clickathon/ingest/internal/chx"
	"github.com/sonyliv-clickathon/ingest/internal/config"
	"github.com/sonyliv-clickathon/ingest/internal/csvsrc"
	"github.com/sonyliv-clickathon/ingest/internal/model"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "\nerror: %v\n", err)
		os.Exit(1)
	}
}

func usage() {
	fmt.Fprint(os.Stderr, `sonyliv-ingest — CSV to ClickHouse loader

Usage:
  sonyliv-ingest schema
  sonyliv-ingest content --file <ch-hackathon-content-data.csv>
  sonyliv-ingest events  --file <ch-hackathon-raw-data.csv> [flags]
  sonyliv-ingest verify

Run "sonyliv-ingest <command> -h" for command flags.
`)
}

func run() error {
	if len(os.Args) < 2 {
		usage()
		return errors.New("no command given")
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	switch os.Args[1] {
	case "schema":
		return cmdSchema(ctx, os.Args[2:])
	case "content":
		return cmdContent(ctx, os.Args[2:])
	case "events":
		return cmdEvents(ctx, os.Args[2:])
	case "verify":
		return cmdVerify(ctx, os.Args[2:])
	case "-h", "--help", "help":
		usage()
		return nil
	default:
		usage()
		return fmt.Errorf("unknown command %q", os.Args[1])
	}
}

// connect resolves configuration and opens ClickHouse, reporting where it went.
func connect(ctx context.Context, envPath string) (*chx.Client, error) {
	cfg, err := config.Load(envPath)
	if err != nil {
		return nil, err
	}
	client, err := chx.Open(ctx, cfg)
	if err != nil {
		return nil, err
	}
	version, err := client.ServerVersion(ctx)
	if err != nil {
		_ = client.Close()
		return nil, err
	}
	fmt.Printf("connected to %s (ClickHouse %s)\n", cfg.Redacted(), version)
	return client, nil
}

// ---------------------------------------------------------------- schema ----

func cmdSchema(ctx context.Context, args []string) error {
	fs := flag.NewFlagSet("schema", flag.ExitOnError)
	envPath := fs.String("env", "", "path to .env (default: nearest .env walking up)")
	dryRun := fs.Bool("dry-run", false, "print the DDL without executing it")
	_ = fs.Parse(args)

	if *dryRun {
		// Resolve {{db}} from config without connecting, and keep the password
		// redacted — dry-run output is meant to be pasted into a review.
		cfg, err := config.Load(*envPath)
		if err != nil {
			return err
		}
		stmts, err := chx.SchemaStatements()
		if err != nil {
			return err
		}
		r := strings.NewReplacer("{{db}}", cfg.Database, "{{ch_user}}", cfg.User, "{{ch_password}}", "********")
		for _, s := range stmts {
			fmt.Printf("-- %s [%d]\n%s;\n\n", s.File, s.Index, r.Replace(s.SQL))
		}
		return nil
	}

	client, err := connect(ctx, *envPath)
	if err != nil {
		return err
	}
	defer client.Close()

	fmt.Println("applying schema:")
	if err := client.ApplySchema(ctx, func(s string) { fmt.Println(s) }); err != nil {
		return err
	}
	fmt.Println("schema applied")
	return nil
}

// --------------------------------------------------------------- content ----

func cmdContent(ctx context.Context, args []string) error {
	fs := flag.NewFlagSet("content", flag.ExitOnError)
	envPath := fs.String("env", "", "path to .env")
	file := fs.String("file", "", "path to ch-hackathon-content-data.csv (required)")
	_ = fs.Parse(args)

	if *file == "" {
		return errors.New("--file is required")
	}

	client, err := connect(ctx, *envPath)
	if err != nil {
		return err
	}
	defer client.Close()

	fingerprint, err := csvsrc.FileSHA256(*file)
	if err != nil {
		return err
	}
	fmt.Printf("content source: %s (sha256 %s)\n", *file, fingerprint[:16])

	reader, err := csvsrc.OpenContent(*file)
	if err != nil {
		return err
	}
	defer reader.Close()

	runID := uuid.New()
	audit := chx.NewAuditWriter(ctx, client)
	defer func() {
		// Surfaced, not swallowed: a quarantine row that never reached
		// ClickHouse is a row the operator thinks was loaded.
		if err := audit.Close(ctx); err != nil {
			fmt.Fprintf(os.Stderr, "warning: audit flush: %v\n", err)
		}
	}()

	// The catalogue is 33K rows — one batch, well inside the recommended range.
	var rows []model.Content
	var rejected int
	for {
		c, reject, err := reader.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
		if reject != nil {
			rejected++
			audit.AddReject(model.Reject{
				RunID: runID, Source: "csv:content", SourceLine: reject.Line,
				Reason: reject.Reason, Detail: reject.Detail, RawRow: reject.Raw,
			})
			continue
		}
		rows = append(rows, *c)
	}

	// Wall-clock nanoseconds as the ReplacingMergeTree version: monotonic
	// across loads, so a later load always wins without a mutation.
	version := uint64(time.Now().UnixNano())
	started := time.Now()

	if err := client.InsertContent(ctx, rows, version, "content|"+fingerprint); err != nil {
		return err
	}
	if err := client.ReloadContentDictionary(ctx); err != nil {
		return err
	}

	fmt.Printf("loaded %d content rows in %s (%d rejected)\n",
		len(rows), time.Since(started).Round(time.Millisecond), rejected)

	n, err := client.CountRows(ctx, "sl_content_dim")
	if err != nil {
		return err
	}
	fmt.Printf("sl_content_dim now holds %d rows (pre-dedup; sl_content_current resolves them)\n", n)
	return nil
}

// ---------------------------------------------------------------- events ----

func cmdEvents(ctx context.Context, args []string) error {
	fs := flag.NewFlagSet("events", flag.ExitOnError)
	envPath := fs.String("env", "", "path to .env")
	file := fs.String("file", "", "path to ch-hackathon-raw-data.csv (required)")
	batchSize := fs.Int("batch-size", 50000, "rows per INSERT (recommended 10000-100000)")
	workers := fs.Int("workers", 6, "concurrent INSERT streams")
	retries := fs.Int("retries", 3, "retry attempts per batch (same dedup token)")
	async := fs.Bool("async", false, "route batches through the server-side async insert buffer")
	limit := fs.Int64("limit", 0, "stop after N accepted rows (0 = whole file)")
	_ = fs.Parse(args)

	if *file == "" {
		return errors.New("--file is required")
	}
	if *batchSize < 1000 {
		return fmt.Errorf("--batch-size %d is below the 1,000-row minimum; "+
			"small batches create one part each and overwhelm merges", *batchSize)
	}
	if *batchSize > 100000 && !*async {
		fmt.Printf("note: --batch-size %d is above the recommended 100,000 ceiling\n", *batchSize)
	}
	if err := chx.ValidateWritePath(*workers, *retries); err != nil {
		return err
	}

	client, err := connect(ctx, *envPath)
	if err != nil {
		return err
	}
	defer client.Close()

	fmt.Printf("fingerprinting %s (%.1f MB)...\n", *file, float64(csvsrc.FileSize(*file))/(1<<20))
	fingerprint, err := csvsrc.FileSHA256(*file)
	if err != nil {
		return err
	}

	source := "csv:" + baseName(*file)
	runID := uuid.New()
	fmt.Printf("source=%s sha256=%s run_id=%s\n", source, fingerprint[:16], runID)
	fmt.Printf("batch_size=%d workers=%d async=%t retries=%d\n\n",
		*batchSize, *workers, *async, *retries)

	audit := chx.NewAuditWriter(ctx, client)
	loader := chx.NewLoader(client, chx.LoaderOptions{
		Source:      source,
		RunID:       runID,
		Fingerprint: fingerprint,
		BatchSize:   *batchSize,
		Workers:     *workers,
		MaxRetries:  *retries,
		AsyncInsert: *async,
		Audit:       audit,
		Progress:    func(s chx.Stats) { fmt.Printf("  %s\n", s) },
	})

	reader, err := csvsrc.OpenEvents(*file)
	if err != nil {
		return err
	}
	defer reader.Close()

	// The reader cuts chunks; the workers only send them. Chunk boundaries are
	// therefore a function of the file, not of scheduling, which is what makes
	// the deduplication token identify the same bytes on a replay.
	chunks := make(chan *chx.Chunk, *workers*2)
	readErr := make(chan error, 1)

	go func() {
		defer close(chunks)
		var (
			ordinal  uint32
			buf      = make([]model.RawEvent, 0, *batchSize)
			accepted int64
			rejected int64
		)
		emit := func() bool {
			if len(buf) == 0 {
				return true
			}
			rows := make([]model.RawEvent, len(buf))
			copy(rows, buf)
			buf = buf[:0]
			select {
			case chunks <- &chx.Chunk{Ordinal: ordinal, Rows: rows}:
				ordinal++
				return true
			case <-ctx.Done():
				return false
			}
		}

		for {
			ev, reject, err := reader.Next()
			if err == io.EOF {
				break
			}
			if err != nil {
				readErr <- err
				return
			}
			if reject != nil {
				rejected++
				audit.AddReject(model.Reject{
					RunID: runID, Source: source, SourceLine: reject.Line,
					Reason: reject.Reason, Detail: reject.Detail, RawRow: reject.Raw,
				})
				continue
			}
			buf = append(buf, *ev)
			accepted++
			if len(buf) >= *batchSize {
				if !emit() {
					return
				}
			}
			if *limit > 0 && accepted >= *limit {
				break
			}
		}
		if !emit() {
			return
		}
		if rejected > 0 {
			fmt.Printf("\n%d rows quarantined in sl_ingest_rejects\n", rejected)
		}
		readErr <- nil
	}()

	started := time.Now()
	stats, loadErr := loader.Run(ctx, chunks)

	// Always flush the audit trail, including on failure: a failed run's batch
	// records are exactly what makes the failure diagnosable.
	if err := audit.Close(ctx); err != nil {
		fmt.Fprintf(os.Stderr, "warning: audit flush: %v\n", err)
	}
	if loadErr != nil {
		return loadErr
	}
	if err := <-readErr; err != nil {
		return err
	}

	fmt.Printf("\nload complete in %s\n  %s\n", time.Since(started).Round(time.Millisecond), stats)

	n, err := client.CountRows(ctx, "sl_raw_events")
	if err != nil {
		return err
	}
	fmt.Printf("  sl_raw_events now holds %d rows\n", n)
	fmt.Println("\nrun `sonyliv-ingest verify` for the integrity report")
	return nil
}

// ---------------------------------------------------------------- verify ----

// verifyChecks are read-only assertions over what was just loaded. They are
// cheap, they run against the serving cluster, and they are the difference
// between "the load finished" and "the load is correct".
var verifyChecks = []struct {
	name string
	sql  string
}{
	{
		"row counts",
		`SELECT
             formatReadableQuantity(count())                AS events,
             formatReadableQuantity(uniqExact(video_session_id)) AS sessions,
             formatReadableQuantity(uniqExact(user_id))     AS users,
             min(event_time)                                AS first_event,
             max(event_time)                                AS last_event
         FROM {db}.sl_raw_events`,
	},
	{
		"exact duplicate rows (identical payload, fingerprinted on the fly)",
		// The fingerprint is computed here rather than stored: a random 64-bit
		// hash is incompressible and would be the single largest column in the
		// table for a value nothing on the hot path reads.
		`SELECT
             count()                       AS total_rows,
             uniqExact(row_fingerprint)    AS distinct_rows,
             count() - uniqExact(row_fingerprint) AS duplicate_rows,
             round(100.0 * (count() - uniqExact(row_fingerprint)) / count(), 4) AS duplicate_pct
         FROM (
             SELECT xxHash64(concatWithSeparator('\x1F',
                        video_session_id, user_id, toString(content_id),
                        event_type, event, toString(toUnixTimestamp64Milli(event_time)),
                        platform, app_version, country,
                        audio_language, subtitle_language, player_version,
                        toString(toUnixTimestamp64Milli(session_start_time)))) AS row_fingerprint
             FROM {db}.sl_raw_events
         )`,
	},
	{
		"content dictionary join coverage (must be 0 misses)",
		`SELECT
             uniqExact(content_id) AS distinct_content_ids,
             uniqExactIf(content_id, dictGetOrDefault({db}.sl_content_dict, 'video_type', tuple(content_id), '__miss__') = '__miss__') AS unjoinable_ids,
             countIf(dictGetOrDefault({db}.sl_content_dict, 'video_type', tuple(content_id), '__miss__') = '__miss__') AS unjoinable_events
         FROM {db}.sl_raw_events`,
	},
	{
		"signal classification (normalized event taxonomy)",
		`SELECT signal, count() AS events, round(100.0 * count() / sum(count()) OVER (), 2) AS pct
         FROM {db}.sl_raw_events
         GROUP BY signal
         ORDER BY events DESC`,
	},
	{
		"language normalization effect",
		`SELECT
             uniqExact(subtitle_language)      AS raw_subtitle_values,
             uniqExact(subtitle_language_norm) AS normalized_subtitle_values,
             uniqExact(audio_language)         AS raw_audio_values,
             uniqExact(audio_language_norm)    AS normalized_audio_values
         FROM {db}.sl_raw_events`,
	},
	{
		"ingest batches",
		`SELECT
             source,
             count()          AS batches,
             sum(row_count)   AS rows,
             countIf(status = 'failed') AS failed,
             sum(attempt) - count()     AS retries,
             round(avg(duration_ms), 1) AS avg_ms,
             max(duration_ms)           AS max_ms
         FROM {db}.sl_ingest_batches
         GROUP BY source
         ORDER BY source`,
	},
	{
		"quarantined rows",
		`SELECT source, reason, count() AS rows
         FROM {db}.sl_ingest_rejects
         GROUP BY source, reason
         ORDER BY rows DESC`,
	},
	{
		"touched-session queue depth",
		`SELECT
             count()                        AS queue_rows,
             uniqExact(video_session_id)    AS distinct_sessions,
             min(last_ingested_at)          AS oldest,
             max(last_ingested_at)          AS newest
         FROM {db}.sl_dirty_sessions`,
	},
	{
		"part health (watch parts per partition, not total rows)",
		`SELECT
             table,
             count()                          AS parts,
             uniqExact(partition)             AS partitions,
             max(parts_in_partition)          AS max_parts_per_partition,
             formatReadableSize(sum(bytes_on_disk)) AS on_disk,
             formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed
         FROM (
             SELECT table, partition, bytes_on_disk, data_uncompressed_bytes,
                    count() OVER (PARTITION BY table, partition) AS parts_in_partition
             FROM system.parts
             WHERE active AND database = '{db}' AND table LIKE 'sl_%'
         )
         GROUP BY table
         ORDER BY table`,
	},
	{
		"compression by column of sl_raw_events (top 12 by on-disk size)",
		`SELECT
             column,
             formatReadableSize(sum(column_data_compressed_bytes))   AS compressed,
             formatReadableSize(sum(column_data_uncompressed_bytes)) AS uncompressed,
             round(sum(column_data_uncompressed_bytes) / greatest(sum(column_data_compressed_bytes), 1), 1) AS ratio
         FROM system.parts_columns
         WHERE active AND database = '{db}' AND table = 'sl_raw_events'
         GROUP BY column
         ORDER BY sum(column_data_compressed_bytes) DESC
         LIMIT 12`,
	},
}

func cmdVerify(ctx context.Context, args []string) error {
	fs := flag.NewFlagSet("verify", flag.ExitOnError)
	envPath := fs.String("env", "", "path to .env")
	_ = fs.Parse(args)

	client, err := connect(ctx, *envPath)
	if err != nil {
		return err
	}
	defer client.Close()

	for _, check := range verifyChecks {
		fmt.Printf("\n=== %s ===\n", check.name)
		if err := printQuery(ctx, client, check.sql); err != nil {
			fmt.Printf("  (failed: %v)\n", err)
		}
	}
	fmt.Println()
	return nil
}

// printQuery runs a query and prints the result as aligned text.
func printQuery(ctx context.Context, client *chx.Client, query string) error {
	q := strings.ReplaceAll(query, "{db}", client.Database)

	rows, err := client.Conn.Query(ctx, q)
	if err != nil {
		return err
	}
	defer rows.Close()

	cols := rows.Columns()
	// clickhouse-go will not scan into *any, so destinations are allocated from
	// the column types the driver reports for this result set.
	colTypes := rows.ColumnTypes()

	var table [][]string
	table = append(table, cols)

	for rows.Next() {
		vals := make([]any, len(cols))
		for i := range vals {
			if i < len(colTypes) && colTypes[i].ScanType() != nil {
				vals[i] = reflect.New(colTypes[i].ScanType()).Interface()
			} else {
				vals[i] = new(string)
			}
		}
		if err := rows.Scan(vals...); err != nil {
			return err
		}
		rec := make([]string, len(cols))
		for i, v := range vals {
			rec[i] = formatValue(reflect.ValueOf(v).Elem().Interface())
		}
		table = append(table, rec)
	}
	if err := rows.Err(); err != nil {
		return err
	}
	if len(table) == 1 {
		fmt.Println("  (no rows)")
		return nil
	}

	widths := make([]int, len(cols))
	for _, rec := range table {
		for i, cell := range rec {
			widths[i] = max(widths[i], len(cell))
		}
	}
	for r, rec := range table {
		fmt.Print("  ")
		for i, cell := range rec {
			fmt.Printf("%-*s", widths[i]+2, cell)
		}
		fmt.Println()
		if r == 0 {
			fmt.Print("  ")
			for i := range rec {
				fmt.Print(strings.Repeat("-", widths[i]), "  ")
			}
			fmt.Println()
		}
	}
	return nil
}

func formatValue(v any) string {
	switch t := v.(type) {
	case nil:
		return ""
	case time.Time:
		return t.UTC().Format("2006-01-02 15:04:05.000")
	case *time.Time:
		if t == nil {
			return ""
		}
		return t.UTC().Format("2006-01-02 15:04:05.000")
	case float64:
		return strconv.FormatFloat(t, 'f', -1, 64)
	case float32:
		return strconv.FormatFloat(float64(t), 'f', -1, 32)
	}
	// Dereference whatever pointer the driver's scan type produced.
	rv := reflect.ValueOf(v)
	if rv.Kind() == reflect.Pointer {
		if rv.IsNil() {
			return ""
		}
		return formatValue(rv.Elem().Interface())
	}
	return fmt.Sprint(v)
}

func baseName(path string) string { return filepath.Base(path) }
