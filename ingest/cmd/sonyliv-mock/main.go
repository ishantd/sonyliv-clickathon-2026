// Command sonyliv-mock serves two interactive event producers over HTTP.
//
//	/        load simulator — set a viewer count, pick content, watch the curve
//	/manual  stepper — drive one session by hand and watch the derived state
//
// Both write into events_raw through the same chx.Loader the CSV path uses, so
// what they exercise is the real write path rather than a parallel one.
//
// The stepper is the more useful of the two for correctness work: it makes the
// foreground x playing independence visible. Start, Play, Background, Pause,
// Foreground leaves a session INACTIVE, and being able to show that in five
// clicks is worth more than the paragraph explaining it.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/sonyliv-clickathon/ingest/internal/chx"
	"github.com/sonyliv-clickathon/ingest/internal/config"
	"github.com/sonyliv-clickathon/ingest/internal/mock"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	fs := flag.NewFlagSet("sonyliv-mock", flag.ExitOnError)
	// Loopback by default, deliberately. This endpoint writes to your
	// ClickHouse; it must not become publicly reachable because a deploy script
	// put the binary on an EC2 box with an open security group. Reach it over an
	// SSH tunnel:
	//   ssh -N -L 8088:127.0.0.1:8088 ec2-user@host
	// and set --token before binding anywhere else.
	listen := fs.String("listen", "127.0.0.1:8088", "address to serve on")
	token := fs.String("token", os.Getenv("MOCK_TOKEN"), "bearer token gating /api/ (empty = no auth; only safe on loopback)")
	envPath := fs.String("env", "", "path to .env")
	timeoutMS := fs.Int64("heartbeat-timeout-ms", 120_000,
		"liveness lease the stepper evaluates against; must match the pipeline's")
	// Only needed for `next dev`, which serves the dashboard from :3000 while this
	// serves :8088. A next.config rewrite would normally bridge that, but rewrites
	// are unsupported under output: 'export'. Empty in production, where this binary
	// serves the exported files itself and the API is same-origin.
	corsOrigin := fs.String("cors-origin", "",
		"single origin allowed to call /api/ (dev only, e.g. http://localhost:3000)")

	if err := fs.Parse(os.Args[1:]); err != nil {
		return err
	}

	if *token == "" && !isLoopback(*listen) {
		return fmt.Errorf("--listen %s is not loopback and --token is empty: "+
			"refusing to expose an unauthenticated write endpoint to ClickHouse", *listen)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	cfg, err := config.Load(*envPath)
	if err != nil {
		return err
	}
	client, err := chx.Open(ctx, cfg)
	if err != nil {
		return err
	}
	defer func() { _ = client.Close() }()

	version, err := client.ServerVersion(ctx)
	if err != nil {
		return err
	}
	fmt.Printf("connected to %s (ClickHouse %s)\n", cfg.Redacted(), version)

	// The generator's "api" sink POSTs back into this same process, so it needs a
	// URL that resolves from here. A bare ":8088" or "0.0.0.0:8088" is a valid
	// listen address but not a valid target, so normalise it to loopback.
	selfURL := "http://" + *listen
	if h := (*listen)[:max(lastColon(*listen), 0)]; h == "" || h == "0.0.0.0" || h == "[::]" {
		selfURL = "http://127.0.0.1" + (*listen)[lastColon(*listen):]
	}

	srv := mock.NewServer(client, *token, *corsOrigin, selfURL, *timeoutMS)
	httpSrv := &http.Server{
		Addr:              *listen,
		Handler:           srv.Handler(),
		ReadHeaderTimeout: 10 * time.Second,
		// No WriteTimeout: a load-run start resolves content from ClickHouse
		// first, and a cold catalogue read on a large database can outlast a
		// short deadline. ReadHeaderTimeout is the one that matters for
		// slow-loris protection.
	}

	errCh := make(chan error, 1)
	go func() {
		fmt.Printf("load simulator  http://%s/\n", *listen)
		fmt.Printf("event stepper   http://%s/manual\n", *listen)
		if *token == "" {
			fmt.Println("no --token set: /api/ is unauthenticated (fine on loopback)")
		}
		if *corsOrigin != "" {
			fmt.Printf("CORS: allowing %s (for `next dev`)\n", *corsOrigin)
		}
		if err := httpSrv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
		}
	}()

	select {
	case err := <-errCh:
		return err
	case <-ctx.Done():
		fmt.Println("\nshutting down...")
	}

	// Cancel any in-flight load run before closing the server, so the generator
	// goroutine and its loader workers unwind while the ClickHouse connection is
	// still open. Closing the client underneath a running insert produces a
	// confusing error on a clean shutdown.
	srv.StopRun()

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	return httpSrv.Shutdown(shutdownCtx)
}

// isLoopback reports whether the listen address is bound to localhost only.
func isLoopback(addr string) bool {
	host := addr
	if i := lastColon(addr); i >= 0 {
		host = addr[:i]
	}
	switch host {
	case "127.0.0.1", "localhost", "::1", "[::1]":
		return true
	}
	return false
}

func lastColon(s string) int {
	for i := len(s) - 1; i >= 0; i-- {
		if s[i] == ':' {
			return i
		}
	}
	return -1
}
