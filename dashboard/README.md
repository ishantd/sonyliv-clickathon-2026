# dashboard

Next.js 16 App Router UI for `sonyliv-mock`.

| route | purpose |
|---|---|
| `/analytics` | **the concurrency curve, its dataset filters and the SQL behind both** |
| `/live` | live concurrency, generator against ClickHouse |
| `/fleet`, `/fleet/new`, `/fleet/session` | a controllable population of simulated sessions |
| `/` | load simulator — viewer count, content, pace; live ingest telemetry |
| `/manual` | event stepper — drive one session by hand, watch derived state |

## `/analytics` — the submission surface

This is the page the track's guidelines are about. Three things live here.

**The concurrency curve.** Foreground-only concurrent sessions per minute over a
selectable window, read from `serving_minute_current`. Two series: the exact
maximum inside each minute, and the time-weighted average, because they differ by
roughly 2.7× and a chart showing one invites the other to be guessed from it. The
window defaults to the match window on 31 July — a full ramp, peak and drain —
rather than to a clock hour that would spend half its width on the drain.

**Dataset filters.** Six, applied to the curve *and* to every breakdown beneath
it. Each maps to a dimension the minute tier is genuinely rolled up by:

| filter | backing dataset column | rollup that carries it |
|---|---|---|
| Platform | `events.platform` | `platform` |
| Country | `events.country` | `country` |
| Content type | `content_dim.video_type` (via `events.content_id`) | `video type` |
| Category | `content_dim.category` (via `events.content_id`) | `category` |
| App version | `events.app_version` | `app version` |
| Title | `content_dim.title` (via `events.content_id`) | `content` |

All six land in `serving_minute_current` as typed columns of the same name; the
mapping is served by `GET /api/analytics` and rendered in the filter bar itself,
so this table cannot drift from what the product does.

**Which rollup answers, and when the peak is withheld.** A peak is exact only at
its own grouping. The selected filters plus whatever a panel breaks down by form a
dimension *set*, and the server resolves that set to the rollup materialised at
exactly it. Materialised combinations are the empty set, each single dimension,
`platform + content`, `platform + country`, `platform + video type`, and all six
together. For any other combination the query falls back to the finest rollup —
where viewer-hours stays exact, because it is additive, and the peak is returned
as `NULL` and reported as **withheld**. It is not estimated: a maximum over a
finer grain is the busiest single combination, not the peak of the slice asked
for. The filter bar says so before the request is made.

**What every query cost.** Each panel prints the ClickHouse execution time, rows
read, bytes scanned and the rollup it used, taken from the driver's own progress
counters rather than a stopwatch. The unfiltered curve reads 8,192 rows in ~10 ms;
the same question answered from the fallback rollup reads 378,411. Both numbers
are on screen, which is the point.

**The statement itself.** Every panel carries a disclosure with the exact SQL that
produced the rows beside it, in two forms — runnable, with the bound parameters
substituted, and as sent, with the `{name:Type}` placeholders and a table of what
was bound — plus the API URL. The server returns the statement with the result, so
the query shown is the query that ran.

## Architecture

**Static export served by Go.** `next build` emits `./out`, which is copied into
`ingest/internal/mock/web/` and embedded with `go:embed`. The Go binary serves it,
so a deploy is one artifact: no second Node process, no reverse proxy, and the API
is same-origin.

Consequences that shape the code — the full list of what `output: 'export'`
forbids is in `node_modules/next/dist/docs/01-app/02-guides/static-exports.md`:

- **No rewrites**, so `/api` cannot be proxied through `next.config`. The API base
  is `NEXT_PUBLIC_API_BASE` instead: set in `.env.development`, empty in
  production. That cross-origin dev hop is why the Go server takes
  `--cors-origin`.
- **No Route Handlers or Server Actions.** The Go service is the API.
- Pages are Client Components fetching through SWR, which is the pattern the
  static-export guide recommends.

**Inter through `next/font`, self-hosted into the export.** Inter is the face
`sonyliv.com` actually renders, and "the closest installed font" is a failure
rather than a fallback on a surface meant to be SonyLIV's. The cost is real and
bounded: `next build` needs network access to fetch the face, which only affects
`make web` — the export is committed, so `make build` still needs no toolchain and
no network. Mono stays the system stack, and carries only measurements,
timestamps and ids.

**Dark only, deliberately.** This is read next to a terminal; the semantic colours
are tuned for one ground rather than compromised across two.

## Develop

Requires **Node >= 20.9** (Next 16). Two processes: the Go service holds the
ClickHouse connection and is the only thing that talks to the database, and
`next dev` serves the UI.

```bash
cd ../ingest && make build
./bin/sonyliv-mock --env .env --cors-origin http://localhost:3000
```

```bash
cd ../dashboard && npm run dev          # http://localhost:3000
```

`.env.development` points the browser at the Go service:

```
NEXT_PUBLIC_API_BASE=http://localhost:8088
```

That cross-origin hop is why the Go server takes `--cors-origin`; in production
both are served from the same binary and the base is empty. `ingest/.env` holds
the ClickHouse credentials and is gitignored — `sonyliv-mock` exits on a bad
password rather than starting and failing per request.

## Ship a change

```bash
cd ../ingest && make web    # builds, then stages out/ into internal/mock/web/
make build                  # embeds it into the binary
```

The export is committed so `make build` needs no Node toolchain. Run `make web`
only after changing this directory.

## Verify

```bash
npm run lint       # eslint (Next 16 removed `next lint` and the eslint key in next.config)
npm run build      # also typechecks; fails the build on a type error
```
