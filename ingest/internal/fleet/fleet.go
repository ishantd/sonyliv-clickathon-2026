package fleet

import (
	"context"
	"errors"
	"log"
	"sync"
	"time"

	"github.com/sonyliv-clickathon/ingest/internal/model"
)

// Sink is where generated events go.
//
// The fleet knows nothing about ClickHouse, HTTP or JSON — it hands over batches of
// rows and that is the entire contract. internal/mock implements this over the
// existing chx.Loader and APISink, so the fleet inherits their retry, deduplication
// -token and batch-audit behaviour rather than opening a third insert path.
type Sink interface {
	Send(ctx context.Context, rows []model.RawEvent) error
}

// Tuning for the run loop.
const (
	// sweepInterval is how often lease expiries are noticed and due heartbeats
	// emitted. Well below the 5s minimum cadence, so a tick is never missed, and
	// far cheaper than it looks: a sweep of 10,000 sessions is a map walk.
	sweepInterval = 250 * time.Millisecond

	// flushInterval and flushRows bound insert batching. One insert per second
	// beats one per event by three orders of magnitude at fleet scale — the
	// stepper's habit of building a fresh loader per event is exactly what this
	// avoids.
	flushInterval = time.Second
	flushRows     = 5000

	enqueueTimeout = 5 * time.Second
)

// ErrQueueFull is returned when the write queue cannot accept a batch in time.
var ErrQueueFull = errors.New("event write queue is full; ClickHouse may be unreachable")

// WriteStats is the health of the write path, surfaced so the UI can explain a
// fleet line that has no ClickHouse line under it.
type WriteStats struct {
	Rows      uint64 `json:"rows"`
	Batches   uint64 `json:"batches"`
	Errors    uint64 `json:"errors"`
	LastError string `json:"last_error,omitempty"`
	Queued    int    `json:"queued"`
}

// Fleet is the registry plus the goroutine that drives it.
type Fleet struct {
	*Registry

	sink Sink
	out  chan []model.RawEvent

	mu    sync.Mutex
	stats WriteStats
}

// New builds a fleet. timeout is the liveness lease; it must match the pipeline's.
func New(sink Sink, timeout time.Duration, seed int64) *Fleet {
	return &Fleet{
		Registry: NewRegistry(timeout, seed),
		sink:     sink,
		out:      make(chan []model.RawEvent, 1024),
	}
}

// Emit queues rows produced by an HTTP handler.
//
// Bounded wait rather than a non-blocking send: silently dropping events would make
// the fleet's own curve disagree with ClickHouse for a reason that is invisible in
// both, which is the one failure this whole design exists to detect. Better to fail
// the request and say so.
func (f *Fleet) Emit(ctx context.Context, rows []model.RawEvent) error {
	if len(rows) == 0 {
		return nil
	}
	select {
	case f.out <- rows:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	case <-time.After(enqueueTimeout):
		return ErrQueueFull
	}
}

// Run drives the fleet until ctx is cancelled.
//
// One goroutine owns both the sweep and the write buffer, so the buffer needs no
// lock and there is no ordering question between a sweep's heartbeats and a
// handler's commands. Rows are always appended in the order they were produced.
func (f *Fleet) Run(ctx context.Context) {
	sweep := time.NewTicker(sweepInterval)
	defer sweep.Stop()
	flush := time.NewTicker(flushInterval)
	defer flush.Stop()

	buf := make([]model.RawEvent, 0, flushRows)

	// Flush with a context that outlives cancellation, so the final partial batch
	// still lands on shutdown instead of being discarded.
	send := func(rows []model.RawEvent) {
		if len(rows) == 0 {
			return
		}
		sctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 2*time.Minute)
		defer cancel()

		err := f.sink.Send(sctx, rows)
		f.mu.Lock()
		if err != nil {
			f.stats.Errors++
			f.stats.LastError = err.Error()
			log.Printf("fleet: write %d rows: %v", len(rows), err)
		} else {
			f.stats.Rows += uint64(len(rows))
			f.stats.Batches++
		}
		f.mu.Unlock()
	}

	for {
		select {
		case <-ctx.Done():
			send(buf)
			return

		case <-sweep.C:
			buf = append(buf, f.Sweep(time.Now().UTC().Truncate(time.Millisecond))...)

		case rows := <-f.out:
			buf = append(buf, rows...)

		case <-flush.C:
			if len(buf) > 0 {
				send(buf)
				buf = buf[:0]
			}
			continue
		}

		// Size-triggered flush, checked after any append. Without it a 2,000-session
		// create would sit in the buffer for up to a second before moving.
		if len(buf) >= flushRows {
			send(buf)
			buf = buf[:0]
		}
	}
}

// WriteStats reports the write path's health.
func (f *Fleet) WriteStats() WriteStats {
	f.mu.Lock()
	defer f.mu.Unlock()
	s := f.stats
	s.Queued = len(f.out)
	return s
}
