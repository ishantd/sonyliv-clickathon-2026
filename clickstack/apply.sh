#!/usr/bin/env bash
# apply.sh — create or update the ClickStack sources and dashboards.
#
#   ./clickstack/apply.sh            create or update everything
#   ./clickstack/apply.sh --dry-run  print the resolved payloads, send nothing
#
# Idempotent by name: an existing source or dashboard is updated in place rather
# than duplicated, so this is safe to re-run after editing any JSON here.
#
# Three placeholders are resolved at apply time rather than being committed:
#
#   __CONNECTION_ID__            CLICKSTACK_CONNECTION_ID
#   __DATABASE__                 CLICKHOUSE_DATABASE
#   __SOURCE_<source name>__     id of the source of that name, once created
#
# The last one is why this is a script rather than four curl calls: dashboard
# tiles reference sources by id, and those ids do not exist until the sources do.
#
# CLICKSTACK_CONNECTION_ID must be supplied by hand. Managed ClickStack
# provisions its ClickHouse connection automatically and does not expose the
# connections routes over the Cloud API — GET and POST on
# .../clickstack/connections both return 404 on this service — so there is no way
# to discover or create it programmatically. Read it once from the ClickStack UI
# (Team Settings -> Connections, or the Connection dropdown in any tile editor);
# it is a 24-character hex id. Then add it to .env:
#
#   CLICKSTACK_CONNECTION_ID=<24 hex chars>
#
# Written for bash 3.2, the version macOS ships — hence a temp file rather than an
# associative array for the source-id map.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/.." && pwd)"
csapi="$here/csapi.sh"

dry_run=false
[[ "${1:-}" == "--dry-run" ]] && dry_run=true

# Captured before .env is sourced so an explicitly exported value wins — the same
# precedence internal/config.Load applies to the CLICKHOUSE_* vars.
pre_conn="${CLICKSTACK_CONNECTION_ID:-}"
pre_db="${CLICKHOUSE_DATABASE:-}"

dir="$repo_root"
for _ in 1 2 3 4 5 6; do
  if [[ -f "$dir/.env" ]]; then
    set -a
    # shellcheck disable=SC1090
    . "$dir/.env"
    set +a
    break
  fi
  dir="$(dirname "$dir")"
done

db="${pre_db:-${CLICKHOUSE_DATABASE:-}}"
[[ -n "$db" ]] || { echo "apply.sh: CLICKHOUSE_DATABASE is not set" >&2; exit 2; }

conn="${pre_conn:-${CLICKSTACK_CONNECTION_ID:-}}"
if [[ -z "$conn" ]]; then
  echo "apply.sh: CLICKSTACK_CONNECTION_ID is not set." >&2
  echo "          Read it from the ClickStack UI and add it to .env — see this script's header." >&2
  exit 2
fi
if [[ ! "$conn" =~ ^[0-9a-fA-F]{24}$ ]]; then
  # The API rejects a malformed id with "connection must be a valid connection
  # id", which reads like a permissions problem. Catch it here instead.
  echo "apply.sh: CLICKSTACK_CONNECTION_ID is not 24 hex characters." >&2
  exit 2
fi

pretty() { python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),indent=2))'; }

# name<TAB>id, one per line.
source_map="$(mktemp)"
trap 'rm -f "$source_map"' EXIT

# ---------------------------------------------------------------- sources ----
# Applied first: the dashboards reference their ids.

existing_sources="$("$csapi" GET /sources)"
source_count="$(python3 -c 'import json,sys;print(len(json.load(open(sys.argv[1]))))' "$here/sources.json")"

for i in $(seq 0 $((source_count - 1))); do
  payload="$(python3 -c '
import json, sys
spec = json.load(open(sys.argv[1]))[int(sys.argv[2])]
body = json.dumps(spec)
body = body.replace("__CONNECTION_ID__", sys.argv[3]).replace("__DATABASE__", sys.argv[4])
print(body)
' "$here/sources.json" "$i" "$conn" "$db")"

  name="$(printf '%s' "$payload" | python3 -c 'import json,sys;print(json.load(sys.stdin)["name"])')"

  existing="$(printf '%s' "$existing_sources" | python3 -c '
import json, sys
for s in json.load(sys.stdin).get("result", []):
    if s.get("name") == sys.argv[1]:
        print(s["id"]); break
' "$name")"

  if $dry_run; then
    echo "--- source $name ${existing:+(would update $existing)}"
    printf '%s' "$payload" | pretty
    printf '%s\t000000000000000000000000\n' "$name" >> "$source_map"
    continue
  fi

  if [[ -n "$existing" ]]; then
    "$csapi" PUT "/sources/$existing" "$payload" >/dev/null
    id="$existing"
    echo "source  updated  $name  ($id)"
  else
    id="$("$csapi" POST /sources "$payload" |
      python3 -c 'import json,sys;print(json.load(sys.stdin)["result"]["id"])')"
    echo "source  created  $name  ($id)"
  fi
  printf '%s\t%s\n' "$name" "$id" >> "$source_map"
done

# ------------------------------------------------------------- dashboards ----

if $dry_run; then
  existing_dashboards='{"result":[]}'
else
  existing_dashboards="$("$csapi" GET /dashboards)"
fi

map_json="$(python3 -c '
import json, sys
out = {}
for line in open(sys.argv[1]):
    if line.strip():
        name, sid = line.rstrip("\n").split("\t", 1)
        out[name] = sid
print(json.dumps(out))
' "$source_map")"

for f in "$here"/dashboards/*.json; do
  payload="$(python3 -c '
import json, re, sys
raw = open(sys.argv[1]).read()
raw = raw.replace("__CONNECTION_ID__", sys.argv[2]).replace("__DATABASE__", sys.argv[3])
for name, sid in json.loads(sys.argv[4]).items():
    raw = raw.replace("__SOURCE_%s__" % name, sid)
left = sorted(set(re.findall(r"__[A-Za-z0-9_-]+__", raw)))
if left:
    sys.exit("unresolved placeholders in %s: %s" % (sys.argv[1], left))
json.loads(raw)  # fail here, not at the API, on a malformed edit
print(raw)
' "$f" "$conn" "$db" "$map_json")"

  name="$(printf '%s' "$payload" | python3 -c 'import json,sys;print(json.load(sys.stdin)["name"])')"

  if $dry_run; then
    echo "--- dashboard $name"
    printf '%s' "$payload" | pretty
    continue
  fi

  # Validate before writing: a rejected tile config is far easier to read from the
  # validate endpoint than from a half-applied dashboard.
  if ! validation="$("$csapi" POST /dashboards/validate "$payload" 2>&1)"; then
    echo "dashboard '$name' failed validation:" >&2
    echo "$validation" >&2
    exit 1
  fi

  existing="$(printf '%s' "$existing_dashboards" | python3 -c '
import json, sys
for d in json.load(sys.stdin).get("result", []):
    if d.get("name") == sys.argv[1]:
        print(d["id"]); break
' "$name")"

  if [[ -n "$existing" ]]; then
    "$csapi" PUT "/dashboards/$existing" "$payload" >/dev/null
    echo "dash    updated  $name  ($existing)"
  else
    id="$("$csapi" POST /dashboards "$payload" |
      python3 -c 'import json,sys;print(json.load(sys.stdin)["result"]["id"])')"
    echo "dash    created  $name  ($id)"
  fi
done

$dry_run || echo "done — open ClickStack from the ClickHouse Cloud console to view them"
