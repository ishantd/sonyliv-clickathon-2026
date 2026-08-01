package generator

import (
	"context"
	"testing"
	"time"

	"github.com/sonyliv-clickathon/ingest/internal/chx"
	"github.com/sonyliv-clickathon/ingest/internal/model"
)

func testContent() []chx.ContentRef {
	return []chx.ContentRef{
		{ContentID: 21311522, VideoType: "vod"},
		{ContentID: 2049025011, VideoType: "vod"},
		{ContentID: 2078177474, VideoType: "live"},
	}
}

func baseConfig() Config {
	return Config{
		Seed:              7,
		StartTime:         time.Date(2026, 8, 5, 9, 0, 0, 0, time.UTC),
		Duration:          10 * time.Minute,
		TargetConcurrency: 50,
		RampUp:            10 * time.Second,
	}
}

// collect runs a generator to completion and returns every row it produced,
// plus the chunk boundaries it chose.
func collect(t *testing.T, cfg Config, batchSize int) ([]model.RawEvent, []uint32, Summary) {
	t.Helper()

	g, err := New(cfg, testContent())
	if err != nil {
		t.Fatalf("New: %v", err)
	}

	out := make(chan *chx.Chunk, 64)
	done := make(chan Summary, 1)
	errc := make(chan error, 1)
	go func() {
		s, err := g.Run(context.Background(), out, batchSize)
		errc <- err
		done <- s
	}()

	var rows []model.RawEvent
	var sizes []uint32
	for c := range out {
		sizes = append(sizes, uint32(len(c.Rows)))
		rows = append(rows, c.Rows...)
	}
	if err := <-errc; err != nil {
		t.Fatalf("Run: %v", err)
	}
	return rows, sizes, <-done
}

// TestDeterministicForSameSeed is the property the loader's deduplication token
// depends on: identical seed and config must produce identical rows in
// identical batches, or a re-run stops being a no-op and becomes a double load.
func TestDeterministicForSameSeed(t *testing.T) {
	rowsA, sizesA, sumA := collect(t, baseConfig(), 5000)
	rowsB, sizesB, sumB := collect(t, baseConfig(), 5000)

	if len(rowsA) != len(rowsB) {
		t.Fatalf("row counts differ: %d vs %d", len(rowsA), len(rowsB))
	}
	if len(rowsA) == 0 {
		t.Fatal("generator produced no rows")
	}
	if sumA != sumB {
		t.Errorf("summaries differ:\n %+v\n %+v", sumA, sumB)
	}
	if len(sizesA) != len(sizesB) {
		t.Fatalf("chunk counts differ: %d vs %d", len(sizesA), len(sizesB))
	}
	for i := range sizesA {
		if sizesA[i] != sizesB[i] {
			t.Fatalf("chunk %d size differs: %d vs %d", i, sizesA[i], sizesB[i])
		}
	}
	for i := range rowsA {
		a, b := rowsA[i], rowsB[i]
		if a.VideoSessionID != b.VideoSessionID || a.EventTime != b.EventTime ||
			a.Event != b.Event || a.EventType != b.EventType ||
			a.ContentID != b.ContentID || a.Platform != b.Platform {
			t.Fatalf("row %d differs:\n %+v\n %+v", i, a, b)
		}
	}
}

func TestDifferentSeedProducesDifferentStream(t *testing.T) {
	cfgA := baseConfig()
	cfgB := baseConfig()
	cfgB.Seed = 8

	rowsA, _, _ := collect(t, cfgA, 5000)
	rowsB, _, _ := collect(t, cfgB, 5000)

	if len(rowsA) == len(rowsB) && rowsA[0].VideoSessionID == rowsB[0].VideoSessionID {
		t.Error("changing the seed did not change the stream")
	}
	if cfgA.Fingerprint() == cfgB.Fingerprint() {
		t.Error("fingerprint must change with the seed, or a different load is silently deduplicated")
	}
}

// TestFingerprintCoversEveryKnob: if a flag can change the data but not the
// fingerprint, the loader would treat a genuinely different run as a replay and
// drop it.
func TestFingerprintCoversEveryKnob(t *testing.T) {
	base := baseConfig()
	mutations := map[string]func(*Config){
		"Seed":               func(c *Config) { c.Seed++ },
		"StartTime":          func(c *Config) { c.StartTime = c.StartTime.Add(time.Hour) },
		"Duration":           func(c *Config) { c.Duration += time.Minute },
		"Drain":              func(c *Config) { c.Drain = !c.Drain },
		"TargetConcurrency":  func(c *Config) { c.TargetConcurrency++ },
		"RampUp":             func(c *Config) { c.RampUp += time.Second },
		"MaxEvents":          func(c *Config) { c.MaxEvents += 100 },
		"HeartbeatInterval":  func(c *Config) { c.HeartbeatInterval = 30 * time.Second },
		"SessionMedian":      func(c *Config) { c.SessionMedian = 5 * time.Minute },
		"SessionP99":         func(c *Config) { c.SessionP99 = 90 * time.Minute },
		"BackgroundEpisodes": func(c *Config) { c.BackgroundEpisodes = 2 },
		"PauseEpisodes":      func(c *Config) { c.PauseEpisodes = 4 },
		"ErrorProbability":   func(c *Config) { c.ErrorProbability = 0.5 },
		"LateFraction":       func(c *Config) { c.LateFraction = 0.5 },
		"LateMax":            func(c *Config) { c.LateMax = time.Hour },
		"DuplicateFraction":  func(c *Config) { c.DuplicateFraction = 0.5 },
		"UserPoolSize":       func(c *Config) { c.UserPoolSize = 12345 },
		"BotSessionShare":    func(c *Config) { c.BotSessionShare = 0.5 },
		"FlushEvery":         func(c *Config) { c.FlushEvery = time.Minute },
	}

	baseline := base.Fingerprint()
	for name, mutate := range mutations {
		cfg := base
		mutate(&cfg)
		if cfg.Fingerprint() == baseline {
			t.Errorf("changing %s does not change the fingerprint", name)
		}
	}
}

// TestConcurrencyConverges: concurrency, not row count, is the primary dial.
func TestConcurrencyConverges(t *testing.T) {
	cfg := baseConfig()
	cfg.TargetConcurrency = 250
	cfg.RampUp = 5 * time.Second

	_, _, sum := collect(t, cfg, 100000)

	if sum.PeakConcurrency != cfg.TargetConcurrency {
		t.Errorf("peak concurrency = %d, want exactly %d", sum.PeakConcurrency, cfg.TargetConcurrency)
	}
	// The hard cutoff must leave the steady-state population open — this is the
	// "sessions still open when the day ends" case the problem statement calls out.
	if sum.SessionsOpen != int64(cfg.TargetConcurrency) {
		t.Errorf("open sessions at cutoff = %d, want %d", sum.SessionsOpen, cfg.TargetConcurrency)
	}
}

func TestMaxEventsIsAHardCap(t *testing.T) {
	cfg := baseConfig()
	cfg.Duration = 0
	cfg.MaxEvents = 4321
	cfg.TargetConcurrency = 200

	rows, _, sum := collect(t, cfg, 500)
	if int64(len(rows)) != cfg.MaxEvents {
		t.Errorf("emitted %d rows, want exactly %d", len(rows), cfg.MaxEvents)
	}
	if sum.Events != cfg.MaxEvents {
		t.Errorf("summary reports %d events, want %d", sum.Events, cfg.MaxEvents)
	}
}

func TestRequiresATerminationCondition(t *testing.T) {
	cfg := baseConfig()
	cfg.Duration = 0
	cfg.MaxEvents = 0
	if _, err := New(cfg, testContent()); err == nil {
		t.Error("a config with neither --duration nor --max-events must be rejected, not run forever")
	}
}

func TestRequiresContent(t *testing.T) {
	if _, err := New(baseConfig(), nil); err == nil {
		t.Error("an empty content catalogue must be rejected: generated events would never join")
	}
}

// TestEmitsOutOfOrderArrivals: a stream delivered in perfect time order would
// validate nothing, since 99.65% of real sessions contain a late event.
func TestEmitsOutOfOrderArrivals(t *testing.T) {
	cfg := baseConfig()
	cfg.LateFraction = 0.1
	cfg.LateMax = time.Minute

	rows, _, sum := collect(t, cfg, 100000)
	if sum.LateEvents == 0 {
		t.Fatal("no late events were generated")
	}

	var outOfOrder int
	var runningMax time.Time
	for _, r := range rows {
		if r.EventTime.Before(runningMax) {
			outOfOrder++
		} else {
			runningMax = r.EventTime
		}
	}
	if outOfOrder == 0 {
		t.Error("late events did not actually arrive out of order in the emitted stream")
	}
}

// TestEmitsExactDuplicates: 0.465% of source rows are byte-identical repeats.
func TestEmitsExactDuplicates(t *testing.T) {
	cfg := baseConfig()
	cfg.DuplicateFraction = 0.05

	rows, _, sum := collect(t, cfg, 100000)
	if sum.Duplicates == 0 {
		t.Fatal("no duplicates were generated")
	}

	type key struct {
		session string
		event   string
		ts      int64
	}
	seen := make(map[key]int, len(rows))
	var dups int
	for _, r := range rows {
		k := key{r.VideoSessionID, r.Event, r.EventTime.UnixMilli()}
		seen[k]++
		if seen[k] > 1 {
			dups++
		}
	}
	if dups == 0 {
		t.Error("duplicates were counted but no identical rows reached the output")
	}
}

// TestSessionLifecycleIsWellFormed checks the state machine rather than the
// row count: a start precedes every other event of its session, and no event
// carries a session-start time later than its own event time.
func TestSessionLifecycleIsWellFormed(t *testing.T) {
	cfg := baseConfig()
	cfg.LateFraction = 0 // arrival order == event order, so ordering is checkable
	cfg.DuplicateFraction = 0

	rows, _, _ := collect(t, cfg, 100000)

	firstSeen := map[string]string{}
	byTime := map[string]time.Time{}
	for _, r := range rows {
		if r.EventTime.Before(r.SessionStartTime) {
			t.Fatalf("event at %s precedes its session start %s", r.EventTime, r.SessionStartTime)
		}
		if _, ok := firstSeen[r.VideoSessionID]; !ok {
			firstSeen[r.VideoSessionID] = r.EventType
			byTime[r.VideoSessionID] = r.EventTime
		}
	}
	if len(firstSeen) == 0 {
		t.Fatal("no sessions generated")
	}
	for id, et := range firstSeen {
		if et != "VideoSessionStart" {
			t.Errorf("session %s opens with %s, want VideoSessionStart", id[:8], et)
		}
	}
}

// TestDrainClosesEverySession: the opposite of the default cutoff behaviour.
func TestDrainClosesEverySession(t *testing.T) {
	cfg := baseConfig()
	cfg.Drain = true
	cfg.Duration = 2 * time.Minute
	cfg.TargetConcurrency = 20

	rows, _, _ := collect(t, cfg, 100000)

	started := map[string]bool{}
	ended := map[string]bool{}
	for _, r := range rows {
		switch r.EventType {
		case "VideoSessionStart":
			started[r.VideoSessionID] = true
		case "VideoSessionEnd":
			ended[r.VideoSessionID] = true
		}
	}
	if len(started) == 0 {
		t.Fatal("no sessions generated")
	}
	for id := range started {
		if !ended[id] {
			t.Fatalf("--drain left session %s open", id[:8])
		}
	}
}

// TestLognormalMatchesItsQuantiles: session and background durations are fitted
// from measured quantiles, and getting the tail wrong would make the generated
// stream easier than reality.
func TestLognormalMatchesItsQuantiles(t *testing.T) {
	g, err := New(baseConfig(), testContent())
	if err != nil {
		t.Fatal(err)
	}

	const n = 200000
	samples := make([]time.Duration, n)
	for i := range samples {
		samples[i] = g.lognormal(35100*time.Millisecond, 511600*time.Millisecond, z90)
	}
	// Checked by counting how many samples fall below each fitted quantile —
	// cheaper than sorting 200K values and it tests exactly the property.
	var belowMedian, belowP90 int
	for _, s := range samples {
		if s <= 35100*time.Millisecond {
			belowMedian++
		}
		if s <= 511600*time.Millisecond {
			belowP90++
		}
	}
	medianFrac := float64(belowMedian) / n
	p90Frac := float64(belowP90) / n
	if medianFrac < 0.48 || medianFrac > 0.52 {
		t.Errorf("median quantile = %.3f, want ~0.50", medianFrac)
	}
	if p90Frac < 0.88 || p90Frac > 0.92 {
		t.Errorf("p90 quantile = %.3f, want ~0.90", p90Frac)
	}
}
