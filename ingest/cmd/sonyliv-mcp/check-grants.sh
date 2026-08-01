#!/usr/bin/env bash
# check-grants.sh — prove the sonyliv_mcp grant set is exactly the serving layer.
#
#   MCP_CH_PASSWORD=... ./ingest/cmd/sonyliv-mcp/check-grants.sh
#
# Runs against ClickHouse directly as sonyliv_mcp, bypassing the MCP server, so it tests
# the boundary that actually holds rather than the validator in front of it. The negative
# cases are the point: an allowlist is only proven by what it refuses.
set -uo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
dir="$repo"
for _ in 1 2 3 4 5 6; do
  [[ -f "$dir/.env" ]] && { set -a; . "$dir/.env"; set +a; break; }
  dir="$(dirname "$dir")"
done

host="${CLICKHOUSE_HOST:?CLICKHOUSE_HOST not set}"
db="${CLICKHOUSE_DATABASE:-sonyliv_prod}"
user="${MCP_CH_USER:-sonyliv_mcp}"
pass="${MCP_CH_PASSWORD:?set MCP_CH_PASSWORD to the sonyliv_mcp password}"

pass_n=0; fail_n=0

# q <sql> -> body on stdout, sets RC
q() {
  /usr/bin/curl -sS --max-time 30 -u "${user}:${pass}" \
    --data-binary "$1" "https://${host}:8443/?database=${db}" 2>&1
}

allow() { # allow <label> <sql>
  local out; out="$(q "$2")"
  if printf '%s' "$out" | grep -q 'DB::Exception'; then
    printf 'FAIL  allowed but refused: %-42s %.110s\n' "$1" "$out"; fail_n=$((fail_n+1))
  else
    printf 'PASS  readable          : %s\n' "$1"; pass_n=$((pass_n+1))
  fi
}

deny() { # deny <label> <sql>
  local out; out="$(q "$2")"
  if printf '%s' "$out" | grep -qE 'ACCESS_DENIED|Not enough privileges|UNKNOWN_TABLE|readonly'; then
    printf 'PASS  refused           : %s\n' "$1"; pass_n=$((pass_n+1))
  else
    printf 'FAIL  NOT REFUSED       : %-42s %.110s\n' "$1" "$out"; fail_n=$((fail_n+1))
  fi
}

echo "connected as ${user} to ${host}/${db}"
echo
echo "== identity =="
printf '  currentUser() = %s\n' "$(q 'SELECT currentUser()' | tr -d '\n')"

echo
echo "== the serving layer must be readable =="
for t in serving_concurrency_live serving_concurrency_minute serving_watermark \
         serving_watermark_history serving_live_total serving_live_content \
         serving_minute_current; do
  allow "$t" "SELECT count() FROM ${db}.${t}"
done
allow "serving_drop_signal (parameterised view)" \
  "SELECT count() FROM ${db}.serving_drop_signal(win_from='2026-07-26 11:00:00', win_to='2026-07-26 11:05:00', grouping_key='country', baseline_minutes=15, min_baseline=25, persist_minutes=1)"
allow "dictGet on content_dict (title resolution)" \
  "SELECT dictGetOrDefault(${db}.content_dict, 'title', tuple(toInt64(1)), '') "

echo
echo "== per-user data must NOT be readable =="
for t in events_raw events_clean events_dedup fleet_sessions session_intervals \
         dirty_sessions ingest_batches ingest_rejects content_dim content_current \
         serving_concurrency_minute_staging; do
  deny "$t" "SELECT count() FROM ${db}.${t}"
done

echo
echo "== system tables must NOT be readable =="
for t in query_log parts tables columns users grants; do
  deny "system.$t" "SELECT count() FROM system.${t}"
done

echo
echo "== writes must be refused =="
deny "INSERT into a serving table" "INSERT INTO ${db}.serving_watermark_history (layer) VALUES ('x')"
deny "TRUNCATE"                    "TRUNCATE TABLE ${db}.serving_watermark_history"
deny "ALTER"                       "ALTER TABLE ${db}.serving_concurrency_minute DELETE WHERE 1"
deny "CREATE TABLE"                "CREATE TABLE ${db}.mcp_probe (a UInt8) ENGINE = Memory"
deny "DROP VIEW"                   "DROP VIEW ${db}.serving_minute_current"
deny "CREATE USER"                 "CREATE USER mcp_probe IDENTIFIED WITH sha256_password BY 'x'"
deny "GRANT"                       "GRANT SELECT ON *.* TO ${user}"

echo
echo "== reaching outside the service must be refused =="
deny "remote()"  "SELECT * FROM remote('127.0.0.1', system, one)"
deny "url()"     "SELECT * FROM url('http://169.254.169.254/latest/meta-data/', CSV, 'a String')"
deny "s3()"      "SELECT * FROM s3('https://example.com/x.csv', CSV, 'a String')"
deny "file()"    "SELECT * FROM file('/etc/passwd', CSV, 'a String')"

echo
echo "$pass_n passed, $fail_n failed"
[[ $fail_n -eq 0 ]]
