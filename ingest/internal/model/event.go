// Package model defines the wire shape of a raw event row and the canonical
// row fingerprint every producer must agree on.
package model

import (
	"time"

	"github.com/google/uuid"
)

// RawEvent mirrors the non-materialized columns of default.sl_raw_events, in
// the order the INSERT statement declares them.
//
// Values are source-faithful: the producer parses and validates but never
// corrects. Semantic normalization is a materialized column server-side, so
// that every producer — this loader, the generator, a future Kafka consumer —
// gets identical results by construction.
type RawEvent struct {
	IngestBatchID uuid.UUID
	BatchRowSeq   uint32

	VideoSessionID string // 64-char uppercase hex
	UserID         string // 64-char uppercase hex
	ContentID      int64

	EventType        string
	Event            string
	EventTime        time.Time
	SessionStartTime time.Time

	Platform         string
	AppVersion       string
	Country          string
	AudioLanguage    string
	SubtitleLanguage string
	PlayerVersion    string
}

// InsertColumns is the column list of the raw-event INSERT, matching the field
// order of AppendTo. Kept next to the struct so the two cannot drift.
var InsertColumns = []string{
	"ingest_batch_id",
	"batch_row_seq",
	"video_session_id",
	"user_id",
	"content_id",
	"event_type",
	"event",
	"event_time",
	"session_start_time",
	"platform",
	"app_version",
	"country",
	"audio_language",
	"subtitle_language",
	"player_version",
}

// Values returns the row as positional arguments for a driver batch Append.
func (e *RawEvent) Values() []any {
	return []any{
		e.IngestBatchID,
		e.BatchRowSeq,
		e.VideoSessionID,
		e.UserID,
		e.ContentID,
		e.EventType,
		e.Event,
		e.EventTime,
		e.SessionStartTime,
		e.Platform,
		e.AppVersion,
		e.Country,
		e.AudioLanguage,
		e.SubtitleLanguage,
		e.PlayerVersion,
	}
}

// Content is one row of the content catalogue.
type Content struct {
	ContentID int64
	Title     string
	VideoType string
	Category  string
}

// ContentInsertColumns matches Content.Values plus the load version.
var ContentInsertColumns = []string{
	"content_id",
	"title",
	"video_type",
	"category",
	"source_version",
}

// Values returns the catalogue row plus its load version.
func (c *Content) Values(sourceVersion uint64) []any {
	return []any{c.ContentID, c.Title, c.VideoType, c.Category, sourceVersion}
}

// Reject is a row the producer refused to land, held for quarantine.
type Reject struct {
	RunID      uuid.UUID
	Source     string
	SourceLine uint64
	Reason     string
	Detail     string
	RawRow     string
}

// RejectInsertColumns matches Reject.Values.
var RejectInsertColumns = []string{
	"run_id", "source", "source_line", "reason", "detail", "raw_row",
}

// Values returns the reject as positional insert arguments.
func (r *Reject) Values() []any {
	return []any{r.RunID, r.Source, r.SourceLine, r.Reason, r.Detail, r.RawRow}
}

// BatchAudit is one row of default.sl_ingest_batches.
type BatchAudit struct {
	IngestBatchID     uuid.UUID
	RunID             uuid.UUID
	Source            string
	SourceFingerprint string
	BatchOrdinal      uint32
	DedupToken        string
	RowCount          uint32
	RejectedCount     uint32
	BytesEstimate     uint64
	FirstEventTime    time.Time
	LastEventTime     time.Time
	StartedAt         time.Time
	CompletedAt       time.Time
	DurationMS        uint32
	Attempt           uint8
	Status            string
	Error             string
}

// BatchAuditInsertColumns matches BatchAudit.Values.
var BatchAuditInsertColumns = []string{
	"ingest_batch_id", "run_id", "source", "source_fingerprint", "batch_ordinal",
	"dedup_token", "row_count", "rejected_count", "bytes_estimate",
	"first_event_time", "last_event_time", "started_at", "completed_at",
	"duration_ms", "attempt", "status", "error",
}

// Values returns the audit row as positional insert arguments.
func (b *BatchAudit) Values() []any {
	return []any{
		b.IngestBatchID, b.RunID, b.Source, b.SourceFingerprint, b.BatchOrdinal,
		b.DedupToken, b.RowCount, b.RejectedCount, b.BytesEstimate,
		b.FirstEventTime, b.LastEventTime, b.StartedAt, b.CompletedAt,
		b.DurationMS, b.Attempt, b.Status, b.Error,
	}
}
