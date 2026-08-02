# `pitch/` — the submission deck

| File | What it is |
|---|---|
| [`index.html`](index.html) | The deck. One self-contained file — fonts, logos and the chart are all embedded, so it renders identically offline. |
| [`pitch-deck.pdf`](pitch-deck.pdf) | The export. 15 pages, 960 × 540 pt (13.333 × 7.5 in = 16:9 landscape), ~1.55 MB. |

Handbook limits: ≤ 15 slides, ≤ 20 MB. This is exactly 15 slides and well under the size cap.

## Submission fields

- **Project title** (≤ 100 chars): `Counting Real Viewers, Not Ghosts`
- **Tagline** (≤ 160 chars): `Foreground-only concurrency at streaming scale — exact peaks, arithmetic corrections, and gates that fail loud on a day we cannot see.`

## Live demo

| | |
|---|---|
| [fastandfurious.live](https://fastandfurious.live) | The concurrency curve, building as sessions open, heartbeat and close. Apply a platform or content filter and the minute view answers instantly. |
| [chat.fastandfurious.live](https://chat.fastandfurious.live) | LibreChat + the ClickHouse MCP server over the serving tables — the follow-up question, in plain English. |

Both appear on the cover, on the integrations slide, and on the closing slide.

## How the deck maps to the brief

Read [`PROBLEM_STATEMENT.md`](https://github.com/sidagarwal04/click-a-thon-2026/tree/main/SonyLiv)
alongside it. Slide 3 answers the five questions the brief says the problem "turns on", verbatim,
and points at the slide where each is expanded. The close maps the deck to the five stated
evaluation axes. Specific requirements and where they are met:

| The brief asks for | Where |
|---|---|
| Active-interval definition under missing heartbeat / pause / background | Slides 4, 5 |
| Representation: intervals, deltas, or hybrid | Slides 4, 6, 7, 8 |
| Minute **and hour and day** peak + average without scanning raw history | Slides 4, 9, 11 |
| Filter-friendliness across platform, country, content, video type, time grain | Slides 4, 9, 14 |
| Still-open sessions whose ranges keep growing | Slides 4, 7, 10 |
| Cross-dimension peaks landing on different minutes | Slides 4, 9 — the SAMSUNG_HTML_TV case |
| Real-time content-metadata join | Slide 6 — `content_dict` |
| ClickStack or LibreChat, meaningfully integrated | Slide 14 |
| Optional: LLM + ClickStack concurrency-decline alerting | Slide 14 |
| 100× behaviour | Slide 12 |
| Unseen-day results with pipeline evidence | Slides 2, 9, 10, 11 — the whole deck runs on it |

## Re-exporting the PDF

The HTML is the source of truth. After editing it, regenerate:

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu --virtual-time-budget=5000 --no-pdf-header-footer --print-to-pdf="$PWD/pitch/pitch-deck.pdf" "file://$PWD/pitch/index.html"
```

Or by hand: open `index.html`, **Cmd/Ctrl + P**, destination *Save as PDF*, margins **None**,
**Background graphics on**. The page size comes from `@page { size: 13.3333in 7.5in }`, so
the layout does not depend on the printer dialog's paper setting.

## Layout contract

Each `<section class="slide">` is exactly `1280 × 720` CSS px, which is `13.333 × 7.5 in`
at 96 dpi and therefore exactly one PDF page. Two rules keep it that way:

- `.body > * { flex-shrink: 0 }` — a flex child must never squash its own content out of
  sight. Without it, an over-long slide silently clips its last paragraph instead of
  overflowing where you can see it.
- Content must end at or above `.foot`. Paste this in the console to check every slide;
  every value must be `≤ 0`:

  ```js
  [...document.querySelectorAll('.slide')].map((e,i)=>{
    const limit = e.querySelector('.foot').getBoundingClientRect().top;
    let worst = -999;
    e.querySelectorAll('.body *').forEach(n=>{ if(!n.offsetHeight) return;
      worst = Math.max(worst, Math.round(n.getBoundingClientRect().bottom - limit)); });
    return [i+1, worst];
  })
  ```

## Where the content comes from

Every figure on a slide is traceable to a file in this repo — the footer of each slide
names its source. Nothing is illustrative:

**Every figure is from the unseen day (2026-07-31), measured on the live `sonyliv` service.**
The tuning-day extract appears only where the deck deliberately contrasts the two.

- The curve on slides 1 and 9 is read straight from `concurrency_minute_versions`
  (`entity='session'`, `rollup_mask=0`, `service_date='2026-07-31'`), 09:45–11:27 UTC, one point
  per minute, peak **19,882 at 11:15 UTC**. The naive reference line (**24,069**) is recomputed
  from `events_clean`.
- Headline unseen-day figures: 7,000,000 events → 6,974,862 after dedup → **163,740 active
  intervals** over 96,844 sessions; conservation ratio **1.000**; 34.7% of sessions never close;
  only 6.51% carry both bg and fg; day peak+average answered in **5 ms reading 8,192 rows**
  against **476 ms / 13.9 M rows** to recompute it raw.
- Tuning-day profiling (used for contrast only): [`docs/EVIDENCE.md`](../docs/EVIDENCE.md).
- The five brief questions and the semantics behind them: [`solution/policy.yaml`](../solution/policy.yaml),
  [`docs/DECISIONS.md`](../docs/DECISIONS.md).
- Exactness, replay convergence, serving latency: [`prototype/RESULTS.md`](../prototype/RESULTS.md).
- Live-service figures and the read-path rewrite: [`optimizations/README.md`](../optimizations/README.md),
  [`pipeline/sql/022_populate_serving.sql`](../pipeline/sql/022_populate_serving.sql).
- The nine silent-failure findings on slide 11: [`CLAUDE.md`](../CLAUDE.md).

If a number in the repo changes, change it here too — a deck that disagrees with the
verifier is worse than no deck.

## Brand marks

Both logos are inline SVG in `<defs>`, so there are no external image files.

- **ClickHouse** — the exact official geometry (four bars on a 9 × 8 grid, a half-height
  cursor dash, and the red unit square at the bottom left), in `#FC0` and `#F00`, taken
  from the mark published in `ClickHouse/clickhouse-docs`.
- **SonyLIV** — rebuilt as vector from the 2020 app icon. The ribbon and `liv` gradient
  stops are colour-sampled from that artwork (`#2CAEEC` → `#3A52D0` → `#9440F0` →
  `#E256FD`, and gold `#FFD66D` → `#FFBA0D`).

The deck's own accent is ClickHouse's web yellow `#FAFF69`, used for verified figures;
the SonyLIV violet–magenta spectrum marks the data/signal path; `#FF4D5E` marks anything
wrong or naive. Type is Archivo (variable, expanded for display) and Chivo Mono for every
numeral — both subset and base64-embedded, so the PDF carries its own fonts.
