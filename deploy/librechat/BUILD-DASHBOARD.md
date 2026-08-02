# Building the fleet dashboard for the shared host

The demo box terminates TLS once, on `:443`, and LibreChat owns `/` there. The fleet
dashboard is mounted at `/build/` by `deploy/nginx/sonyliv.conf`.

Three env vars must be set **at build time** — they are inlined into the static export, so
setting them at runtime does nothing:

```bash
cd dashboard
NEXT_PUBLIC_BASE_PATH=/build \
NEXT_PUBLIC_API_BASE=/build \
NEXT_PUBLIC_CLICKSTACK_URL='https://console.clickhouse.cloud/...' \
NEXT_PUBLIC_LANGFUSE_URL='https://cloud.langfuse.com/project/...' \
  npm run build

cd ../ingest && make web   # restages out/ into internal/mock/web and re-embeds
```

Node **>= 20.9** is required (Next 16). If `npm ci` was ever run under an older Node,
delete `node_modules` first — tailwind's native binary is installed per-ABI and the build
fails on a stale one with a module-resolution error inside `@tailwindcss/node`.

## Why each variable

| var | what breaks without it |
|---|---|
| `NEXT_PUBLIC_BASE_PATH` | assets and links resolve to `/`, where LibreChat answers with its own SPA shell — 200, wrong app |
| `NEXT_PUBLIC_API_BASE` | `basePath` does not rewrite `fetch()` strings, so the app calls `/api/...` and reaches **LibreChat's** API |
| `NEXT_PUBLIC_CLICKSTACK_URL` / `NEXT_PUBLIC_LANGFUSE_URL` | the tab is simply not rendered — empty means absent, by design |

Standalone builds (no nginx) omit all four and the app serves from root as before.

## Verifying without nginx

nginx strips `/build/` before proxying, so the upstream sees root paths. Run the binary and
request the *stripped* paths — every one must be 200:

```bash
ingest/bin/sonyliv-mock --listen 127.0.0.1:8091
for p in / /_next/static/chunks/*.js /live/ /manual/ /fleet/ /sonyliv-mark.png /healthz; do
  curl -so /dev/null -w "$p %{http_code}\n" "http://127.0.0.1:8091$p"
done
```

Then confirm the served HTML still asks for the prefix — `curl -s http://127.0.0.1:8091/ |
grep '/build/'` — because that is the half nginx undoes.
