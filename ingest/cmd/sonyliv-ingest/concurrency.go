package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"time"

	"github.com/sonyliv-clickathon/ingest/concurrency"
)

// cmdConcurrency drives the serving layers.
//
//	sonyliv-ingest concurrency --layer all               full rebuild from scratch
//	sonyliv-ingest concurrency --layer live --loop 10s   keep the live dashboard moving
//	sonyliv-ingest concurrency --layer minute --day D    rebuild one UTC day
//
// The three layers are separate flags rather than one command because they have
// genuinely different cadences: intervals is the expensive per-session step, live
// runs every few seconds over a short window, and minute rebuilds a whole day at a
// time on a lag. Collapsing them would force the cheapest work to pay the cost of
// the most expensive.
func cmdConcurrency(ctx context.Context, args []string) error {
	fs := flag.NewFlagSet("concurrency", flag.ExitOnError)
	envPath := fs.String("env", "", "path to .env (default: nearest .env walking up)")
	layer := fs.String("layer", "all",
		"which layer to build: intervals | live | minute | all")
	day := fs.String("day", "",
		"UTC day for --layer minute, YYYY-MM-DD (default: every day with active time)")
	liveWindow := fs.Duration("live-window", 30*time.Minute,
		"how much trailing time the live layer rebuilds each pass")
	lag := fs.Duration("lag", 5*time.Minute,
		"how far behind the ingest watermark the minute layer publishes, so the late-arrival window has closed")
	loop := fs.Duration("loop", 0,
		"repeat every interval instead of running once (0 = run once)")
	full := fs.Bool("full", false,
		"recompute every session rather than only those dirtied since the last pass")
	timeoutMS := fs.Uint64("heartbeat-timeout-ms", concurrency.DefaultHeartbeatTimeoutMS,
		"liveness lease in milliseconds; must match the policy the numbers are defended under")
	policy := fs.String("policy-version", concurrency.DefaultPolicyVersion,
		"semantic contract stamped onto every row")
	dirtyCap := fs.Int("dirty-cap", 50_000,
		"most sessions one incremental pass will recompute before it insists on --full")
	_ = fs.Parse(args)

	client, err := connect(ctx, *envPath)
	if err != nil {
		return err
	}
	defer client.Close()

	r := concurrency.NewRunner(client)
	r.HeartbeatTimeoutMS = *timeoutMS
	r.PolicyVersion = *policy

	switch *layer {
	case "intervals", "live", "minute", "all":
	default:
		return fmt.Errorf("unknown --layer %q (want intervals, live, minute or all)", *layer)
	}
	if *day != "" && *layer != "minute" {
		return errors.New("--day only applies to --layer minute")
	}

	// lastPass seeds the dirty-session query. Zero on the first pass means "every
	// session dirtied at any point", which is the correct cold start.
	var lastPass time.Time

	pass := func() error {
		switch *layer {
		case "intervals":
			return runIntervals(ctx, r, *full, *dirtyCap, &lastPass)
		case "live":
			if err := runIntervals(ctx, r, *full, *dirtyCap, &lastPass); err != nil {
				return err
			}
			return runLive(ctx, r, *liveWindow)
		case "minute":
			return runMinute(ctx, r, *day, *lag)
		case "all":
			if err := runIntervals(ctx, r, true, *dirtyCap, &lastPass); err != nil {
				return err
			}
			if err := runLive(ctx, r, *liveWindow); err != nil {
				return err
			}
			return runMinute(ctx, r, "", *lag)
		}
		return nil
	}

	if *loop == 0 {
		return pass()
	}

	fmt.Printf("looping every %s; Ctrl-C to stop\n", *loop)
	ticker := time.NewTicker(*loop)
	defer ticker.Stop()
	for {
		if err := pass(); err != nil {
			// A transient failure must not kill a long-running loop — the next
			// tick recomputes the same window from scratch, so one lost pass
			// leaves no gap behind it.
			fmt.Printf("pass failed, retrying next tick: %v\n", err)
		}
		select {
		case <-ctx.Done():
			fmt.Println("\nstopping")
			return nil
		case <-ticker.C:
		}
	}
}

// runIntervals recomputes session_intervals, incrementally unless asked not to.
//
// The incremental path reads dirty_sessions, which an insert-time materialized
// view on events_raw maintains. That makes a pass proportional to what actually
// changed rather than to the size of the history — the difference between a
// ten-second loop being viable and not.
func runIntervals(ctx context.Context, r *concurrency.Runner, full bool, dirtyCap int, lastPass *time.Time) error {
	watermark, err := r.Watermark(ctx)
	if err != nil {
		return fmt.Errorf("read ingest watermark: %w", err)
	}

	var keys []uint64
	if !full {
		keys, err = r.DirtySessions(ctx, *lastPass, dirtyCap)
		if err != nil {
			return fmt.Errorf("read dirty sessions: %w", err)
		}
		if len(keys) == 0 {
			// Nothing new. Say so rather than rewriting every interval for no
			// reason — a quiet pass is the normal state of a live loop.
			fmt.Printf("intervals  no sessions dirtied since %s, skipped\n",
				lastPass.UTC().Format("15:04:05"))
			*lastPass = time.Now().UTC()
			return nil
		}
		if len(keys) >= dirtyCap {
			return fmt.Errorf("%d sessions dirtied, at or above --dirty-cap %d: "+
				"run once with --full rather than catching up in slices", len(keys), dirtyCap)
		}
	}

	st, err := r.Intervals(ctx, keys, watermark)
	if err != nil {
		return err
	}
	fmt.Println(st)
	// The cursor is wall-clock, not the event watermark, because
	// dirty_sessions.last_ingested_at records when a row was inserted rather than
	// when it happened. An event-time cursor would re-read the same sessions
	// forever whenever the stream replays history — which is what a backfill is.
	*lastPass = time.Now().UTC()
	return nil
}

func runLive(ctx context.Context, r *concurrency.Runner, window time.Duration) error {
	end := time.Now().UTC()
	st, err := r.Live(ctx, end.Add(-window), end)
	if err != nil {
		return err
	}
	fmt.Println(st)
	return nil
}

// runMinute rebuilds either one named day or every day holding active time.
//
// The lag is applied by refusing to rebuild a day whose end has not yet cleared
// the watermark minus lag. That is what makes this the correctable layer: it does
// not publish a minute until late events for it have had time to arrive.
func runMinute(ctx context.Context, r *concurrency.Runner, day string, lag time.Duration) error {
	if day != "" {
		d, err := time.ParseInLocation("2006-01-02", day, time.UTC)
		if err != nil {
			return fmt.Errorf("--day %q: %w", day, err)
		}
		st, err := r.Minute(ctx, d)
		if err != nil {
			return err
		}
		fmt.Printf("%s day=%s\n", st, day)
		return nil
	}

	days, err := r.ServiceDays(ctx)
	if err != nil {
		return fmt.Errorf("list service days: %w", err)
	}
	if len(days) == 0 {
		fmt.Println("minute     session_intervals holds no active time, nothing to build")
		return nil
	}

	watermark, err := r.Watermark(ctx)
	if err != nil {
		return err
	}
	cutoff := watermark.Add(-lag)

	var built, held int
	for _, d := range days {
		// A day is publishable once its own minutes are all older than the
		// cutoff, OR when it is the current open day — the open day is rebuilt
		// every pass by design, since that is where new data lands.
		if d.After(cutoff) {
			held++
			continue
		}
		st, err := r.Minute(ctx, d)
		if err != nil {
			return err
		}
		fmt.Printf("%s day=%s\n", st, d.Format("2006-01-02"))
		built++
	}
	if held > 0 {
		fmt.Printf("minute     %d day(s) held back: not yet %s behind the watermark %s\n",
			held, lag, watermark.Format("2006-01-02 15:04:05"))
	}
	fmt.Printf("minute     %d day(s) rebuilt\n", built)
	return nil
}
