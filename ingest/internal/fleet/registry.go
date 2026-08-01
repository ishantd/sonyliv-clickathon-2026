package fleet

import (
	"errors"
	"fmt"
	"math/rand"
	"sort"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/sonyliv-clickathon/ingest/internal/model"
)

// Limits. MaxPerCreate is the form's ceiling; MaxLive bounds total memory and,
// more importantly, bounds the ClickHouse comparison query in curve.go, which
// scopes by an IN list of session ids.
const (
	MaxPerCreate = 2000
	MaxLive      = 10000

	DefaultCadence = 30 * time.Second
	MinCadence     = 5 * time.Second
	MaxCadence     = 10 * time.Minute
)

// ErrTooMany is returned when a create would exceed MaxLive.
var ErrTooMany = errors.New("registry is full; clear ended sessions first")

// View is a session flattened for the wire, with the derived fields the UI needs.
//
// A flat copy rather than an embedded *Session: the live struct is mutated under
// the registry lock, and handing a pointer to it across the HTTP boundary would be
// a data race that usually presents as a field that disagrees with itself.
type View struct {
	ID           string `json:"video_session_id"`
	UserID       string `json:"user_id"`
	ContentID    int64  `json:"content_id"`
	ContentTitle string `json:"content_title"`
	VideoType    string `json:"video_type"`

	Platform   string `json:"platform"`
	AppVersion string `json:"app_version"`
	Country    string `json:"country"`

	StartEpoch     time.Time `json:"start_epoch"`
	CadenceSeconds int       `json:"cadence_seconds"`

	Phase  Phase `json:"phase"`
	Active bool  `json:"active"`

	Started      bool `json:"started"`
	Ended        bool `json:"ended"`
	Foreground   bool `json:"foreground"`
	Playing      bool `json:"playing"`
	Heartbeating bool `json:"heartbeating"`

	LastEligible time.Time `json:"last_eligible"`
	LeaseExpires time.Time `json:"lease_expires"`
	NextTick     time.Time `json:"next_tick"`

	EventsSent int        `json:"events_sent"`
	ActiveMS   int64      `json:"active_ms"`
	Intervals  []Interval `json:"intervals"`
}

// Filter narrows the listing and the curve. Zero fields mean "any".
type Filter struct {
	ContentID  int64
	VideoType  string
	Platform   string
	AppVersion string
	Country    string
	Phase      string
}

// matches tests a session directly rather than a built View.
//
// Deliberately not View-based: building a View copies the session's interval slice,
// and the listing and the curve both filter every session on a two-second poll. At
// MaxLive that would be tens of thousands of throwaway allocations per second to
// answer a question that only reads six scalar fields.
//
// phase is passed in because it is the one predicate that needs the clock, and the
// callers already have `now`.
func (f Filter) matches(s *Session, phase Phase) bool {
	switch {
	case f.ContentID != 0 && s.ContentID != f.ContentID:
		return false
	case f.VideoType != "" && s.VideoType != f.VideoType:
		return false
	case f.Platform != "" && s.Platform != f.Platform:
		return false
	case f.AppVersion != "" && s.AppVersion != f.AppVersion:
		return false
	case f.Country != "" && s.Country != f.Country:
		return false
	case f.Phase != "" && string(phase) != f.Phase:
		return false
	}
	return true
}

// selects reconciles a session and reports whether the filter admits it.
func (r *Registry) selects(s *Session, f Filter, now time.Time) bool {
	s.reconcile(now, r.timeout)
	return f.matches(s, s.phase(now, r.timeout))
}

// Stats is the fleet header: how many sessions, and in what state.
type Stats struct {
	Total        int `json:"total"`
	Active       int `json:"active"`
	Paused       int `json:"paused"`
	Backgrounded int `json:"backgrounded"`
	Expired      int `json:"expired"`
	Ended        int `json:"ended"`
	EventsSent   int `json:"events_sent"`
}

// Registry owns the live sessions.
//
// One mutex guards everything. At MaxLive sessions a sweep holds it for well under
// a millisecond, and the alternative — a lock per session plus one for the map —
// buys nothing while making the interval bookkeeping in session.go race-prone.
//
// No IO and no goroutines live here, and every method takes `now` explicitly. That
// is what makes the state machine testable without a clock or a ClickHouse.
type Registry struct {
	mu       sync.Mutex
	sessions map[string]*Session
	order    []string
	timeout  time.Duration
	rng      *rand.Rand
}

// NewRegistry builds an empty registry. timeout is the liveness lease and must
// match what the pipeline evaluates with, or the fleet's own graph line will
// disagree with ClickHouse for reasons that have nothing to do with either.
func NewRegistry(timeout time.Duration, seed int64) *Registry {
	return &Registry{
		sessions: make(map[string]*Session),
		timeout:  timeout,
		rng:      rand.New(rand.NewSource(seed)),
	}
}

// Timeout exposes the lease so handlers can report it alongside a session.
func (r *Registry) Timeout() time.Duration { return r.timeout }

func (r *Registry) view(s *Session, now time.Time) *View {
	return &View{
		ID: s.ID, UserID: s.UserID,
		ContentID: s.ContentID, ContentTitle: s.ContentTitle, VideoType: s.VideoType,
		Platform: s.Platform, AppVersion: s.AppVersion, Country: s.Country,
		StartEpoch:     s.StartEpoch,
		CadenceSeconds: int(s.Cadence / time.Second),
		Phase:          s.phase(now, r.timeout),
		Active:         s.isActive(now, r.timeout),
		Started:        s.started, Ended: s.ended,
		Foreground: s.foreground, Playing: s.playing, Heartbeating: s.heartbeating,
		LastEligible: s.lastEligible,
		LeaseExpires: s.leaseExpiry(r.timeout),
		NextTick:     s.nextTick,
		EventsSent:   s.eventsSent,
		ActiveMS:     s.activeMS(now, r.timeout),
		Intervals:    s.activeIntervals(now, r.timeout),
	}
}

// Create mints n sessions and returns the events that start them.
//
// Each session emits VideoSessionStart and Play at the same instant, so the whole
// batch is active from creation — create 500 and the graph reads 500, with no
// buffering ramp to explain away. The pair cannot conflict at one millisecond:
// session_start sets only foreground, Play sets only playing, and neither is a
// stop, so stop-wins precedence never engages.
func (r *Registry) Create(sp Spec, now time.Time) ([]*View, []model.RawEvent, error) {
	if sp.Count <= 0 {
		return nil, nil, errors.New("count must be at least 1")
	}
	if sp.Count > MaxPerCreate {
		return nil, nil, fmt.Errorf("count %d exceeds the %d limit", sp.Count, MaxPerCreate)
	}
	if sp.ContentID == 0 {
		return nil, nil, errors.New("content_id is required — pick from the catalogue")
	}
	if sp.Platform == "" {
		sp.Platform = "ANDROID_PHONE"
	}
	if sp.AppVersion == "" {
		sp.AppVersion = "6.34.8"
	}
	if sp.Country == "" {
		sp.Country = "india"
	}
	cadence := time.Duration(sp.CadenceSeconds) * time.Second
	if cadence == 0 {
		cadence = DefaultCadence
	}
	if cadence < MinCadence || cadence > MaxCadence {
		return nil, nil, fmt.Errorf("cadence must be between %s and %s", MinCadence, MaxCadence)
	}
	sp.CadenceSeconds = int(cadence / time.Second)

	r.mu.Lock()
	defer r.mu.Unlock()

	if len(r.sessions)+sp.Count > MaxLive {
		return nil, nil, fmt.Errorf("%w (%d live, %d requested, cap %d)",
			ErrTooMany, len(r.sessions), sp.Count, MaxLive)
	}

	batchID := uuid.New()
	views := make([]*View, 0, sp.Count)
	rows := make([]model.RawEvent, 0, sp.Count*2)
	var seq uint32

	for i := 0; i < sp.Count; i++ {
		s := newSession(sp, now)
		// Stagger the first tick uniformly across the cadence. Without this every
		// session fires on the same instant and the insert rate is a spike every
		// `cadence` seconds — a sawtooth that is an artifact of the simulator, not
		// a property of the workload it is meant to imitate.
		s.nextTick = now.Add(time.Duration(r.rng.Int63n(int64(cadence))))

		rows = append(rows, s.apply(model.PairSessionStart, now, r.timeout, batchID, seq))
		seq++
		rows = append(rows, s.apply(model.PairPlay, now, r.timeout, batchID, seq))
		seq++

		r.sessions[s.ID] = s
		r.order = append(r.order, s.ID)
		views = append(views, r.view(s, now))
	}
	return views, rows, nil
}

// Get returns one session's view.
func (r *Registry) Get(id string, now time.Time) (*View, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	s, ok := r.sessions[id]
	if !ok {
		return nil, false
	}
	// Reconcile on read so a detail page never shows an interval the lease already
	// closed. Cheap, and it keeps the page honest between sweeps.
	s.reconcile(now, r.timeout)
	return r.view(s, now), true
}

// List returns a filtered page in creation order, plus the filtered total.
//
// Creation order rather than newest-first: the fleet is created in bulk, so a
// stable order is what makes "session 3 of 500" mean anything across polls.
func (r *Registry) List(f Filter, offset, limit int, now time.Time) ([]*View, int) {
	if limit <= 0 || limit > 500 {
		limit = 50
	}
	r.mu.Lock()
	defer r.mu.Unlock()

	// Count every match but materialise only the page. The alternative — build all
	// the views then slice — allocates an interval copy per session to return fifty
	// of them.
	page := make([]*View, 0, limit)
	total := 0
	for _, id := range r.order {
		s, ok := r.sessions[id]
		if !ok {
			continue
		}
		if !r.selects(s, f, now) {
			continue
		}
		if total >= offset && len(page) < limit {
			page = append(page, r.view(s, now))
		}
		total++
	}
	return page, total
}

// Command applies an operator action and returns the events it wrote.
//
// Silence and unsilence write nothing, which is the point of them: the pipeline
// cannot observe an app being killed, so the fleet must not tell it.
func (r *Registry) Command(id string, cmd Command, now time.Time) (*View, []model.RawEvent, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	s, ok := r.sessions[id]
	if !ok {
		return nil, nil, fmt.Errorf("unknown session %s", id)
	}
	if s.ended && cmd != CmdEnd {
		return nil, nil, errors.New("session has ended; no further commands apply")
	}

	batchID := uuid.New()
	var rows []model.RawEvent
	add := func(p model.EventPair) {
		rows = append(rows, s.apply(p, now, r.timeout, batchID, uint32(len(rows))))
	}

	switch cmd {
	case CmdPause:
		add(model.PairPause)
	case CmdResume:
		add(model.PairResume)
	case CmdBackground:
		add(model.PairBackground)
	case CmdForeground:
		add(model.PairForeground)
	case CmdSilence:
		s.reconcile(now, r.timeout)
		s.heartbeating = false
	case CmdUnsilence:
		s.reconcile(now, r.timeout)
		s.heartbeating = true
		s.nextTick = now
	case CmdEnd:
		if s.ended {
			return r.view(s, now), nil, nil
		}
		add(model.PairSessionEnd)
	default:
		return nil, nil, fmt.Errorf("unknown command %q", cmd)
	}
	return r.view(s, now), rows, nil
}

// Sweep advances the clock: it closes lease-expired intervals and emits the
// heartbeats that are due.
//
// Returns the rows to write. It does NOT write them itself, so the caller can send
// them without the registry lock held — sending under the lock would let a slow
// ClickHouse stall every HTTP handler.
func (r *Registry) Sweep(now time.Time) []model.RawEvent {
	r.mu.Lock()
	defer r.mu.Unlock()

	batchID := uuid.New()
	var rows []model.RawEvent
	for _, id := range r.order {
		s, ok := r.sessions[id]
		if !ok {
			continue
		}
		s.reconcile(now, r.timeout)
		if s.ended || !s.heartbeating || now.Before(s.nextTick) {
			continue
		}
		rows = append(rows, s.apply(model.PairHeartbeat, now, r.timeout, batchID, uint32(len(rows))))
		// ±10% jitter each tick, so sessions created in one batch do not re-converge
		// on a single instant after the first stagger.
		j := time.Duration(r.rng.Int63n(int64(s.Cadence/5))) - s.Cadence/10
		s.nextTick = now.Add(s.Cadence + j)
	}
	return rows
}

// Stats counts sessions by phase.
func (r *Registry) Stats(now time.Time) Stats {
	r.mu.Lock()
	defer r.mu.Unlock()

	st := Stats{Total: len(r.sessions)}
	for _, s := range r.sessions {
		s.reconcile(now, r.timeout)
		st.EventsSent += s.eventsSent
		switch s.phase(now, r.timeout) {
		case PhaseActive:
			st.Active++
		case PhasePaused:
			st.Paused++
		case PhaseBackgrounded:
			st.Backgrounded++
		case PhaseExpired:
			st.Expired++
		case PhaseEnded:
			st.Ended++
		}
	}
	return st
}

// RemoveEnded drops ended sessions from the registry and reports how many went.
//
// Not a per-session delete — the delete button ends a session cleanly and leaves
// it visible, which is what was asked for. This exists because MaxLive is a hard
// cap: without a way to reclaim ended sessions you eventually cannot create more.
// Events already in ClickHouse are untouched.
func (r *Registry) RemoveEnded() int {
	r.mu.Lock()
	defer r.mu.Unlock()

	kept := make([]string, 0, len(r.order))
	removed := 0
	for _, id := range r.order {
		s, ok := r.sessions[id]
		if !ok {
			continue
		}
		if s.ended {
			delete(r.sessions, id)
			removed++
			continue
		}
		kept = append(kept, id)
	}
	r.order = kept
	return removed
}

// Dimensions reports the distinct values present, for populating filter dropdowns
// from what actually exists rather than from a hardcoded list.
func (r *Registry) Dimensions() map[string][]string {
	r.mu.Lock()
	defer r.mu.Unlock()

	sets := map[string]map[string]struct{}{
		"platform": {}, "app_version": {}, "country": {}, "video_type": {},
	}
	for _, s := range r.sessions {
		sets["platform"][s.Platform] = struct{}{}
		sets["app_version"][s.AppVersion] = struct{}{}
		sets["country"][s.Country] = struct{}{}
		if s.VideoType != "" {
			sets["video_type"][s.VideoType] = struct{}{}
		}
	}
	out := make(map[string][]string, len(sets))
	for k, set := range sets {
		vals := make([]string, 0, len(set))
		for v := range set {
			vals = append(vals, v)
		}
		sort.Strings(vals)
		out[k] = vals
	}
	return out
}

// SessionIDs returns the ids matching a filter, for scoping the ClickHouse
// comparison query.
func (r *Registry) SessionIDs(f Filter, now time.Time) []string {
	r.mu.Lock()
	defer r.mu.Unlock()

	out := make([]string, 0, len(r.order))
	for _, id := range r.order {
		s, ok := r.sessions[id]
		if !ok {
			continue
		}
		if r.selects(s, f, now) {
			out = append(out, id)
		}
	}
	return out
}
