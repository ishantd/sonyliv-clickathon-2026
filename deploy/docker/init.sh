#!/usr/bin/env bash
# init.sh — bring an empty ClickHouse up to a working SonyLIV stack, once.
#
# Runs as the `init` service in docker-compose.yml. Everything else in the
# compose file waits on this finishing successfully, so if it exits non-zero the
# stack does not come up half-built.
#
# Four steps, in order, each idempotent:
#
#   1. create the database          (sonyliv-ingest schema creates TABLES, not databases)
#   2. apply the schema             (CREATE ... IF NOT EXISTS plus MODIFY SETTING, converges)
#   3. load the CSVs, if present    (skipped when the tables already hold rows)
#   4. reload the content dictionary
#
# Step 3 is the only one that is conditional, and it is conditional on two
# separate things — whether the files are there, and whether the data is already
# loaded. Both are reported, because "no data" and "data already present" look
# identical from the dashboard and only one of them is a problem.

set -euo pipefail

: "${CLICKHOUSE_HOST:?CLICKHOUSE_HOST is not set}"
: "${CLICKHOUSE_DATABASE:?CLICKHOUSE_DATABASE is not set}"
CLICKHOUSE_USER="${CLICKHOUSE_USER:-default}"
CLICKHOUSE_PASSWORD="${CLICKHOUSE_PASSWORD:-}"

# The native port carries the loader; this is the HTTP port, used only for the
# two statements below that have to run BEFORE a database exists to connect to.
CLICKHOUSE_HTTP_PORT="${CLICKHOUSE_HTTP_PORT:-8123}"

DATA_DIR="${DATA_DIR:-/data}"
FORCE_LOAD="${FORCE_LOAD:-0}"

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }

# One statement over HTTP, as the configured user. Kept to the two cases that
# genuinely cannot go through the Go client.
ch() {
  curl -sS --fail-with-body --max-time 120 \
    "http://${CLICKHOUSE_HOST}:${CLICKHOUSE_HTTP_PORT}/" \
    --user "${CLICKHOUSE_USER}:${CLICKHOUSE_PASSWORD}" \
    --data-binary "$1"
}

# ---------------------------------------------------------------------------
# 1. The database
# ---------------------------------------------------------------------------
# Compose's healthcheck already gates this service on ClickHouse answering
# /ping, so this loop is a second line of defence rather than the primary one:
# /ping can answer before the server finishes loading its access-control files, and
# the failure then is an authentication error that looks like a wrong password.
say "waiting for ClickHouse at ${CLICKHOUSE_HOST}:${CLICKHOUSE_HTTP_PORT}"
for i in $(seq 1 90); do
  if ch "SELECT 1" >/dev/null 2>&1; then break; fi
  if [[ $i -eq 90 ]]; then
    echo "init: ClickHouse did not accept a query within 90s" >&2
    ch "SELECT 1" || true
    exit 1
  fi
  sleep 1
done

say "creating database ${CLICKHOUSE_DATABASE}"
ch "CREATE DATABASE IF NOT EXISTS ${CLICKHOUSE_DATABASE}"

# ---------------------------------------------------------------------------
# 2. The schema
# ---------------------------------------------------------------------------
# Applies every top-level file in ingest/sql/ in order. sql/manual/ is NOT
# applied — chx.SchemaStatements reads one directory deep and ReadDir does not
# recurse — which is deliberate: those files create users and run destructive
# mutations and must stay a human decision.
say "applying schema"
sonyliv-ingest schema

# ---------------------------------------------------------------------------
# 3. The extracts
# ---------------------------------------------------------------------------
# Globbed rather than named, so the same file works for the tuning extract
# (ch-hackathon-raw-data.csv) and the unseen day (ch-hackathon-raw-data_surprise.csv)
# without an env var telling it which one is mounted.
shopt -s nullglob
content_csv=( "${DATA_DIR}"/ch-hackathon-content-data*.csv )
events_csv=(  "${DATA_DIR}"/ch-hackathon-raw-data*.csv )
shopt -u nullglob

already="$(ch "SELECT count() FROM ${CLICKHOUSE_DATABASE}.events_raw" | tr -d '[:space:]')"

if [[ ${#content_csv[@]} -eq 0 && ${#events_csv[@]} -eq 0 ]]; then
  say "no CSVs in ${DATA_DIR} — starting empty"
  cat <<'EOF'

    The stack will come up with an empty database. That is a working demo, not a
    broken one: open the dashboard, create a fleet, and the concurrency curve
    builds from the simulator's own traffic.

    To load the supplied extracts instead, drop them into ./data and re-run
    `docker compose up`:

        ch-hackathon-content-data.csv           the catalogue  (~1.4 MB)
        ch-hackathon-raw-data.csv               the events     (~1.8 GB)

    The catalogue matters more than it looks. Without it every generated session
    resolves to '__unknown__' and the title, category and content-type panels
    collapse to a single bar. If you load only one file, load that one.

EOF
elif [[ "$already" != "0" && "$FORCE_LOAD" != "1" ]]; then
  say "events_raw already holds ${already} rows — skipping the load"
  echo "    set FORCE_LOAD=1 to load anyway (the loader dedupes retried batches," >&2
  echo "    but a second load of a DIFFERENT file is additive, not idempotent)"   >&2
else
  if [[ ${#content_csv[@]} -gt 0 ]]; then
    # The catalogue goes first. events_raw does not reference it, but the
    # content dictionary does, and a rollup that runs against an empty
    # dictionary stamps '__unknown__' into serving rows that no later reload
    # corrects — the enrichment is frozen at compaction time.
    say "loading catalogue ${content_csv[0]##*/}"
    sonyliv-ingest content --file "${content_csv[0]}"
  else
    say "no catalogue CSV — titles and categories will not resolve"
  fi

  if [[ ${#events_csv[@]} -gt 0 ]]; then
    say "loading events ${events_csv[0]##*/} (this is the slow one)"
    sonyliv-ingest events --file "${events_csv[0]}"
  fi
fi

# ---------------------------------------------------------------------------
# 4. The dictionary
# ---------------------------------------------------------------------------
# ClickHouse loads a dictionary lazily, on first use. Left alone, the first
# dictGet is whatever query happens to run first — which during a demo is the
# demo. Forcing it here makes the load synchronous and its failure visible now
# rather than as a chart full of '__unknown__' later.
#
# No ON CLUSTER: this is a single node. On the multi-replica Cloud service the
# same reload has to reach every replica, because the cache is per-replica and
# we have watched two replicas disagree — one LOADED with 33,464 elements, the
# other LOADED with 0, at the same instant.
say "loading the content dictionary"
ch "SYSTEM RELOAD DICTIONARY ${CLICKHOUSE_DATABASE}.content_dict"

ch "SELECT
      'content_dim'  AS table, count() AS rows FROM ${CLICKHOUSE_DATABASE}.content_dim
UNION ALL SELECT
      'events_raw',  count() FROM ${CLICKHOUSE_DATABASE}.events_raw
FORMAT PrettyCompactMonoBlock"

say "ready"
