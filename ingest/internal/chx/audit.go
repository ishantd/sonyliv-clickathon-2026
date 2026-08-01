package chx

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2"

	"github.com/sonyliv-clickathon/ingest/internal/model"
)

// AuditWriter buffers control-plane rows (batch audit, rejects) and flushes
// them on a timer.
//
// These rows arrive one at a time and are worth a few hundred bytes each — the
// exact shape client-side batching cannot fix, because there is nothing to
// batch with. Two mechanisms are stacked:
//
//   - a small in-process buffer, so a run producing thousands of batches does
//     not issue thousands of single-row INSERTs; and
//   - async_insert=1 with wait_for_async_insert=1 on the flush, so ClickHouse
//     coalesces what still arrives in dribs into properly sized parts and still
//     confirms durability before returning.
//
// wait_for_async_insert stays at 1 on purpose. Fire-and-forget would hide
// exactly the failures this table exists to record.
// [official: insert-async-small-batches]
type AuditWriter struct {
	client        *Client
	flushInterval time.Duration
	maxBuffered   int

	mu      sync.Mutex
	batches []model.BatchAudit
	rejects []model.Reject

	stop chan struct{}
	done chan struct{}

	errMu   sync.Mutex
	lastErr error
}

// NewAuditWriter starts the background flusher. Call Close to drain it.
func NewAuditWriter(ctx context.Context, client *Client) *AuditWriter {
	w := &AuditWriter{
		client:        client,
		flushInterval: 2 * time.Second,
		maxBuffered:   1000,
		stop:          make(chan struct{}),
		done:          make(chan struct{}),
	}
	go w.loop(ctx)
	return w
}

// Add queues one batch-audit row.
func (w *AuditWriter) Add(b model.BatchAudit) {
	w.mu.Lock()
	w.batches = append(w.batches, b)
	over := len(w.batches) >= w.maxBuffered
	w.mu.Unlock()
	if over {
		_ = w.Flush(context.Background())
	}
}

// AddReject queues one quarantined source row.
func (w *AuditWriter) AddReject(r model.Reject) {
	w.mu.Lock()
	w.rejects = append(w.rejects, r)
	over := len(w.rejects) >= w.maxBuffered
	w.mu.Unlock()
	if over {
		_ = w.Flush(context.Background())
	}
}

func (w *AuditWriter) loop(ctx context.Context) {
	defer close(w.done)
	t := time.NewTicker(w.flushInterval)
	defer t.Stop()
	for {
		select {
		case <-w.stop:
			return
		case <-ctx.Done():
			return
		case <-t.C:
			if err := w.Flush(ctx); err != nil {
				w.setErr(err)
			}
		}
	}
}

// Flush writes everything currently buffered.
func (w *AuditWriter) Flush(ctx context.Context) error {
	w.mu.Lock()
	batches, rejects := w.batches, w.rejects
	w.batches, w.rejects = nil, nil
	w.mu.Unlock()

	if len(batches) == 0 && len(rejects) == 0 {
		return nil
	}

	bctx := clickhouse.Context(ctx, clickhouse.WithSettings(clickhouse.Settings{
		"async_insert":          1,
		"wait_for_async_insert": 1,
	}))

	if len(batches) > 0 {
		stmt := insertStatement(w.client.Database, "sl_ingest_batches", model.BatchAuditInsertColumns)
		b, err := w.client.Conn.PrepareBatch(bctx, stmt)
		if err != nil {
			return fmt.Errorf("prepare audit batch: %w", err)
		}
		for i := range batches {
			if err := b.Append(batches[i].Values()...); err != nil {
				_ = b.Abort()
				return fmt.Errorf("append audit row: %w", err)
			}
		}
		if err := b.Send(); err != nil {
			return fmt.Errorf("send audit batch: %w", err)
		}
	}

	if len(rejects) > 0 {
		stmt := insertStatement(w.client.Database, "sl_ingest_rejects", model.RejectInsertColumns)
		b, err := w.client.Conn.PrepareBatch(bctx, stmt)
		if err != nil {
			return fmt.Errorf("prepare reject batch: %w", err)
		}
		for i := range rejects {
			if err := b.Append(rejects[i].Values()...); err != nil {
				_ = b.Abort()
				return fmt.Errorf("append reject row: %w", err)
			}
		}
		if err := b.Send(); err != nil {
			return fmt.Errorf("send reject batch: %w", err)
		}
	}
	return nil
}

// Close stops the flusher and drains the buffer.
func (w *AuditWriter) Close(ctx context.Context) error {
	close(w.stop)
	<-w.done
	if err := w.Flush(ctx); err != nil {
		return err
	}
	w.errMu.Lock()
	defer w.errMu.Unlock()
	return w.lastErr
}

func (w *AuditWriter) setErr(err error) {
	w.errMu.Lock()
	w.lastErr = err
	w.errMu.Unlock()
}
