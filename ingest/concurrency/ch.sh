#!/usr/bin/env bash
# ch.sh — run a query against the configured ClickHouse service over HTTPS.
#
# Exists so that every ad-hoc check in this project is a reviewable artifact
# rather than a shell-history one-liner. Reads the same .env the Go binaries do
# and never echoes the password.
#
#   ./ingest/concurrency/ch.sh "SELECT count() FROM session_intervals FINAL"
#   ./ingest/concurrency/ch.sh --file ingest/concurrency/sql/090_validate_serving.sql
#   ./ingest/concurrency/ch.sh --format Pretty "SELECT 1"
#
# Parameters for the parameterized rollup SQL are passed through as
# --param_<name>=<value>, matching clickhouse-client:
#
#   ./ingest/concurrency/ch.sh --file ingest/concurrency/sql/020_rollup_live.sql \
#       --param_window_start='2026-08-02 10:00:00' ...
#
# {{db}} in a file is substituted with $CLICKHOUSE_DATABASE before sending, the
# same way chx.Client.Render does it for the Go path.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Walk up for .env the way config.findEnvFile does, so this works from a git
# worktree whose .env lives in the parent checkout.
env_file=""
dir="$repo_root"
for _ in 1 2 3 4 5 6; do
  if [[ -f "$dir/.env" ]]; then env_file="$dir/.env"; break; fi
  dir="$(dirname "$dir")"
done
# .env fills in what the environment has NOT already set -- it does not override it.
#
# `set -a; . .env` was doing the opposite, and it cost a wrong-database run: an
# explicit `CLICKHOUSE_DATABASE=sonyliv_unseen ./ch.sh --file 090_validate...` was
# silently clobbered back to .env's sonyliv_prod, and the suite then reported a
# full table of PASSes -- for the wrong database. Nothing errored, because both
# databases have the same schema; only the numbers were from somewhere else.
#
# So the precedence is the conventional one: explicit environment beats file. Read
# with `read -r` on a filtered stream rather than sourcing, so a value containing a
# space or a `#` survives and nothing in .env can execute.
if [[ -n "$env_file" ]]; then
  while IFS='=' read -r key val; do
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    # Already set and non-empty: leave it alone. This is the whole point.
    [[ -n "${!key:-}" ]] && continue
    # Strip one layer of surrounding quotes, as a shell would have.
    val="${val%$'\r'}"
    # Length guard: ${val:1:-1} on a 0- or 1-character value is a bash error
    # ("substring expression < 0"), which printed on every run before this.
    if (( ${#val} >= 2 )); then
      case "$val" in
        \"*\"|\'*\') val="${val:1:${#val}-2}" ;;
      esac
    fi
    export "$key=$val"
  done < <(grep -vE '^[[:space:]]*(#|$)' "$env_file")
fi

: "${CLICKHOUSE_HOST:?CLICKHOUSE_HOST is not set (no .env found?)}"
: "${CLICKHOUSE_USER:?CLICKHOUSE_USER is not set}"
: "${CLICKHOUSE_PASSWORD:?CLICKHOUSE_PASSWORD is not set}"
db="${CLICKHOUSE_DATABASE:-default}"

format="TabSeparatedWithNames"
sql=""
sql_file=""
params=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)     sql_file="$2"; shift 2 ;;
    --format)   format="$2";   shift 2 ;;
    --param_*)  params+=("$1"); shift ;;
    --)         shift; break ;;
    *)          sql="$1"; shift ;;
  esac
done

if [[ -n "$sql_file" ]]; then
  sql="$(sed "s/{{db}}/${db}/g" "$sql_file")"
fi
[[ -n "$sql" ]] || { echo "ch.sh: no query given" >&2; exit 2; }

url="https://${CLICKHOUSE_HOST}:8443/?database=${db}&default_format=${format}"

# Query parameters must ride in the URL because the request body is the SQL, so
# they need real percent-encoding — timestamps contain spaces and colons.
for p in "${params[@]:-}"; do
  [[ -z "$p" ]] && continue
  kv="${p#--}"
  url+="&${kv%%=*}=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1],safe=""))' "${kv#*=}")"
done

curl -sS --fail-with-body --max-time 300 "$url" \
  --user "${CLICKHOUSE_USER}:${CLICKHOUSE_PASSWORD}" \
  --data-binary "$sql"
