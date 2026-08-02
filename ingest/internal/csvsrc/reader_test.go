package csvsrc

import (
	"io"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"
)

// writeTemp writes body to a uniquely-named file under the test's temp dir.
func writeTemp(t *testing.T, name, body string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), name)
	if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
		t.Fatalf("write %s: %v", name, err)
	}
	return path
}

func TestParseContentID(t *testing.T) {
	tests := []struct {
		name  string
		in    string
		want  int64
		isErr bool
	}{
		{"ordinary id", "21311522", 21311522, false},
		{"largest observed", "2078177474", 2078177474, false},
		// The catalogue stores -987654322 as an unsigned 64-bit value. Reading
		// it as a huge positive number would create a catalogue entry no event
		// can ever join to.
		{"negative cast to unsigned", "18446744072721897294", -987654322, false},
		{"already negative", "-987654322", -987654322, false},
		{"empty", "", 0, true},
		{"not a number", "abc", 0, true},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got, err := ParseContentID(tc.in)
			if tc.isErr {
				if err == nil {
					t.Fatalf("ParseContentID(%q) = %d, want error", tc.in, got)
				}
				return
			}
			if err != nil {
				t.Fatalf("ParseContentID(%q): unexpected error %v", tc.in, err)
			}
			if got != tc.want {
				t.Errorf("ParseContentID(%q) = %d, want %d", tc.in, got, tc.want)
			}
		})
	}
}

func TestParseEpochMillis(t *testing.T) {
	// A real timestamp from the extract.
	got, err := ParseEpochMillis("1785062007336")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if want := int64(1785062007336); got.UnixMilli() != want {
		t.Errorf("UnixMilli = %d, want %d", got.UnixMilli(), want)
	}
	if got.Location() != time.UTC {
		t.Errorf("location = %v, want UTC", got.Location())
	}

	// A producer rendering epochs as floats is tolerated when the fraction is
	// zero, and rejected when it would silently lose precision.
	if _, err := ParseEpochMillis("1785062007336.0"); err != nil {
		t.Errorf("trailing .0 should be accepted: %v", err)
	}
	if _, err := ParseEpochMillis("1785062007336.5"); err == nil {
		t.Error("sub-millisecond precision should be rejected, not truncated")
	}

	// Wrong-unit detection. A seconds-scale value would land the row in 1970
	// and quietly corrupt every concurrency bucket.
	for _, bad := range []string{"1785062007", "1785062007336000", "0", "-5", ""} {
		if _, err := ParseEpochMillis(bad); err == nil {
			t.Errorf("ParseEpochMillis(%q) should have failed", bad)
		}
	}
}

func TestNormalizeHexID(t *testing.T) {
	const lower = "94d660e9f4d438a91a80a351320be2b344b81faffe23a5be677f93a6684f8dac"
	const upper = "94D660E9F4D438A91A80A351320BE2B344B81FAFFE23A5BE677F93A6684F8DAC"

	// Case must normalize: the id is the session key, so 'a1b2' and 'A1B2' from
	// two producers must not become two different sessions.
	got, err := NormalizeHexID(lower)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != upper {
		t.Errorf("NormalizeHexID(lower) = %s, want %s", got, upper)
	}

	for _, bad := range []string{"", "ABC", upper + "0", upper[:63] + "Z"} {
		if _, err := NormalizeHexID(bad); err == nil {
			t.Errorf("NormalizeHexID(%q) should have failed", bad)
		}
	}
}

// TestEventReaderMapsColumnsByName is the property that protects the unseen
// day: the evaluation file comes from the same universe but nothing promises
// the same column order.
func TestEventReaderMapsColumnsByName(t *testing.T) {
	const sessionID = "94D660E9F4D438A91A80A351320BE2B344B81FAFFE23A5BE677F93A6684F8DAC"
	const userID = "7C7D3C62725140B3E15072BBD0166D5EA6C6811F0061AB2F53CA2179DF43858D"

	// Same data, columns in a deliberately different order from the source file.
	body := "user_id,video_session_id,event,event_type,platform,content_id," +
		"session_start_epoch,event_timestamp,app_version,country,audio_language," +
		"subtitle_language,player_version\n" +
		userID + "," + sessionID + ",Play,VideoPlay,JIO_ANDROID_TV,21311522," +
		"1785062007336,1785062009028,3.9.4,india,hin,OFF,1.8.2\n"

	path := filepath.Join(t.TempDir(), "shuffled.csv")
	if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}

	r, err := OpenEvents(path)
	if err != nil {
		t.Fatalf("OpenEvents: %v", err)
	}
	defer r.Close()

	ev, reject, err := r.Next()
	if err != nil || reject != nil {
		t.Fatalf("Next: err=%v reject=%+v", err, reject)
	}
	if ev.VideoSessionID != sessionID {
		t.Errorf("session id = %q", ev.VideoSessionID)
	}
	if ev.UserID != userID {
		t.Errorf("user id = %q", ev.UserID)
	}
	if ev.Platform != "JIO_ANDROID_TV" {
		t.Errorf("platform = %q", ev.Platform)
	}
	if ev.ContentID != 21311522 {
		t.Errorf("content id = %d", ev.ContentID)
	}
	if ev.EventTimestamp.UnixMilli() != 1785062009028 {
		t.Errorf("event time = %d", ev.EventTimestamp.UnixMilli())
	}
	if ev.SessionStartEpoch.UnixMilli() != 1785062007336 {
		t.Errorf("session start = %d", ev.SessionStartEpoch.UnixMilli())
	}

	if _, _, err := r.Next(); err != io.EOF {
		t.Errorf("expected EOF, got %v", err)
	}
}

// TestEventReaderMissingColumnFailsFast: a missing required column must abort
// the load, not produce 905K silently-wrong rows.
func TestEventReaderMissingColumnFailsFast(t *testing.T) {
	path := filepath.Join(t.TempDir(), "truncated.csv")
	if err := os.WriteFile(path, []byte("video_session_id,user_id\nA,B\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := OpenEvents(path); err == nil {
		t.Fatal("expected an error naming the missing columns")
	}
}

// TestEventReaderQuarantinesBadRows: a malformed row is held with its line
// number, and the rest of the file still loads.
func TestEventReaderQuarantinesBadRows(t *testing.T) {
	const good = "94D660E9F4D438A91A80A351320BE2B344B81FAFFE23A5BE677F93A6684F8DAC"
	const user = "7C7D3C62725140B3E15072BBD0166D5EA6C6811F0061AB2F53CA2179DF43858D"
	header := "video_session_id,user_id,content_id,event_type,event,event_timestamp," +
		"platform,app_version,country,audio_language,subtitle_language,player_version,session_start_epoch\n"
	rowFmt := func(sid, ts string) string {
		return sid + "," + user + ",21311522,VideoPlay,Play," + ts +
			",IPHONE,6.34.8,india,hin,OFF,1.8.2,1785062007336\n"
	}
	body := header +
		rowFmt(good, "1785062009028") + // ok
		rowFmt("TOOSHORT", "1785062009028") + // bad session id
		rowFmt(good, "17") + // bad timestamp
		rowFmt(good, "1785062009030") // ok

	path := filepath.Join(t.TempDir(), "dirty.csv")
	if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
	r, err := OpenEvents(path)
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()

	var accepted int
	var reasons []string
	for {
		ev, reject, err := r.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			t.Fatalf("Next: %v", err)
		}
		if reject != nil {
			reasons = append(reasons, reject.Reason)
			if reject.Line == 0 {
				t.Error("reject is missing its source line number")
			}
			continue
		}
		if ev != nil {
			accepted++
		}
	}
	if accepted != 2 {
		t.Errorf("accepted %d rows, want 2", accepted)
	}
	if len(reasons) != 2 {
		t.Fatalf("quarantined %d rows (%v), want 2", len(reasons), reasons)
	}
	if reasons[0] != ReasonBadSessionID || reasons[1] != ReasonBadTimestamp {
		t.Errorf("reasons = %v, want [%s %s]", reasons, ReasonBadSessionID, ReasonBadTimestamp)
	}
}

func TestContentReaderMapsEmptyToUnknown(t *testing.T) {
	// 1,089 catalogue rows have an empty video_type, 142 of them actually
	// played. Left empty, every GROUP BY grows a nameless bucket.
	body := "content_id,title,video_type,category\n2049025011,cirar fac,,\n"
	path := filepath.Join(t.TempDir(), "content.csv")
	if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
	r, err := OpenContent(path)
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()

	c, reject, err := r.Next()
	if err != nil || reject != nil {
		t.Fatalf("Next: err=%v reject=%+v", err, reject)
	}
	if c.VideoType != "unknown" || c.Category != "unknown" {
		t.Errorf("video_type=%q category=%q, want both %q", c.VideoType, c.Category, "unknown")
	}
}

// TestContentReaderQuarantinesBadRows: the catalogue reader must honour the
// same contract as the event reader. One malformed row aborting the load would
// leave the whole catalogue — and the enrichment dictionary built from it —
// stale, which is a far worse outcome than one quarantined title.
func TestContentReaderQuarantinesBadRows(t *testing.T) {
	body := "content_id,title,video_type,category\n" +
		"2049025011,cirar fac,vod,drama\n" +
		"1,too,many,fields,here\n" + // structural: wrong field count
		"notanumber,bad id,vod,drama\n" + // semantic: unparseable id
		"2078177474,late fac,live,sport\n"

	path := filepath.Join(t.TempDir(), "dirty-content.csv")
	if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
	r, err := OpenContent(path)
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()

	var accepted int
	var reasons []string
	for {
		c, reject, err := r.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			t.Fatalf("a bad catalogue row aborted the load: %v", err)
		}
		if reject != nil {
			reasons = append(reasons, reject.Reason)
			if reject.Line == 0 {
				t.Error("reject is missing its source line number")
			}
			continue
		}
		if c != nil {
			accepted++
		}
	}

	if accepted != 2 {
		t.Errorf("accepted %d rows, want the 2 good ones", accepted)
	}
	if len(reasons) != 2 {
		t.Fatalf("quarantined %d rows (%v), want 2", len(reasons), reasons)
	}
	if reasons[0] != ReasonBadRow || reasons[1] != ReasonBadContentID {
		t.Errorf("reasons = %v, want [%s %s]", reasons, ReasonBadRow, ReasonBadContentID)
	}
}

// The unseen-day export (data/surprise_spec.md) adds video_resolution to the
// events and show_name to the catalogue. One binary must read both shapes: the
// original extract without the columns, and the new file with them.
//
// The absence case is the one worth a test. rec[idx[col]] returns field 0 for a
// missing column because Go zero-values the map lookup, so a naive reader would
// have written video_session_id into video_resolution for every row of the
// original extract — silently, and only visible as a nonsense dashboard filter.
func TestOptionalColumnsPresentAndAbsent(t *testing.T) {
	base := "video_session_id,user_id,content_id,event_type,event,event_timestamp," +
		"platform,app_version,country,audio_language,subtitle_language,player_version,session_start_epoch"
	sid := strings.Repeat("A", 64)
	uid := strings.Repeat("B", 64)
	row := sid + "," + uid + ",42,VideoPlay,play,1769424000000,IPHONE,1.0,india,en,en,p1,1769424000000"

	for _, tc := range []struct {
		name       string
		header     string
		line       string
		wantRes    string
		wantOption []string
	}{
		{"absent (original extract)", base, row, "", nil},
		{"present (unseen day)", base + ",video_resolution", row + ",1080p", "1080p", []string{"video_resolution"}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			path := writeTemp(t, "ev.csv", tc.header+"\n"+tc.line+"\n")
			r, err := OpenEvents(path)
			if err != nil {
				t.Fatalf("OpenEvents: %v", err)
			}
			defer r.Close()

			if got := r.OptionalColumns(); !slices.Equal(got, tc.wantOption) {
				t.Errorf("OptionalColumns() = %v, want %v", got, tc.wantOption)
			}
			ev, rej, err := r.Next()
			if err != nil || rej != nil {
				t.Fatalf("Next() err=%v reject=%+v", err, rej)
			}
			if ev.VideoResolution != tc.wantRes {
				t.Errorf("VideoResolution = %q, want %q", ev.VideoResolution, tc.wantRes)
			}
			// The regression: absence must not alias another column.
			if ev.VideoResolution == ev.VideoSessionID && tc.wantRes == "" {
				t.Error("absent video_resolution read field 0 (video_session_id)")
			}
			// Required columns must still parse correctly in both shapes.
			if ev.Platform != "IPHONE" || ev.ContentID != 42 {
				t.Errorf("required columns corrupted: platform=%q content_id=%d", ev.Platform, ev.ContentID)
			}
		})
	}
}

func TestContentShowNameOptional(t *testing.T) {
	for _, tc := range []struct {
		name, header, line, want string
	}{
		{"absent", "content_id,title,video_type,category", "7,T,live,sport", ""},
		{"present", "content_id,title,video_type,category,show_name", "7,T,live,sport,My Show", "My Show"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			path := writeTemp(t, "c.csv", tc.header+"\n"+tc.line+"\n")
			r, err := OpenContent(path)
			if err != nil {
				t.Fatalf("OpenContent: %v", err)
			}
			defer r.Close()
			c, rej, err := r.Next()
			if err != nil || rej != nil {
				t.Fatalf("Next() err=%v reject=%+v", err, rej)
			}
			if c.ShowName != tc.want {
				t.Errorf("ShowName = %q, want %q", c.ShowName, tc.want)
			}
			if c.Title != "T" || c.ContentID != 7 {
				t.Errorf("required columns corrupted: title=%q id=%d", c.Title, c.ContentID)
			}
		})
	}
}
