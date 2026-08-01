#!/usr/bin/env bash
# check-tiles.sh — run every dashboard tile's SQL against ClickHouse.
#
#   ./clickstack/check-tiles.sh                      last 24h window
#   ./clickstack/check-tiles.sh '2026-07-26 10:00:00' '2026-07-26 11:00:00'
#   ./clickstack/check-tiles.sh --rows ...           print the first row too
#
# ClickStack renders a broken tile as an empty box with the error buried in a
# panel, so a dashboard can look plausible while half of it is failing. This
# expands the HyperDX SQL macros to concrete values and executes each tile's query
# directly, which turns that into a pass/fail list before anything is published.
#
# It cannot check that a tile LOOKS right — only that its query is valid against
# this schema and returns rows. That is the part that breaks when a column is
# renamed.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/.." && pwd)"
ch="$repo_root/ingest/concurrency/ch.sh"

# The tile SQL fully qualifies its tables as __DATABASE__.<table>, because a
# ClickStack connection's default database is not guaranteed to be this one.
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
db="${CLICKHOUSE_DATABASE:?CLICKHOUSE_DATABASE is not set}"

show_rows=false
if [[ "${1:-}" == "--rows" ]]; then show_rows=true; shift; fi

from="${1:-$(date -u -v-24H '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -u -d '24 hours ago' '+%Y-%m-%d %H:%M:%S')}"
to="${2:-$(date -u '+%Y-%m-%d %H:%M:%S')}"
# 60s granularity is what the dashboards land on for a multi-hour window, and it
# is the value most likely to expose a GROUP BY that forgot the bucket column.
interval_s="${INTERVAL_S:-60}"

echo "window ${from}Z .. ${to}Z   granularity ${interval_s}s"
echo

pass=0; fail=0

# Emit one <tile name>\t<expanded sql> line per tile. Newlines inside the SQL are
# flattened because these queries are single-line in the JSON anyway.
tiles="$(python3 -c '
import glob, json, os, sys

dash_dir, frm, to, isec, db = sys.argv[1:6]

def expand(sql):
    # Longest token first: $__fromTime_ms must not be eaten by $__fromTime, and
    # $__timeFilter_ms must not be eaten by $__timeFilter.
    sql = sql.replace("$__fromTime_ms", "fromUnixTimestamp64Milli(toUnixTimestamp64Milli(toDateTime64(%r, 3)))" % frm)
    sql = sql.replace("$__toTime_ms",   "fromUnixTimestamp64Milli(toUnixTimestamp64Milli(toDateTime64(%r, 3)))" % to)
    sql = sql.replace("$__fromTime", "toDateTime(%r)" % frm)
    sql = sql.replace("$__toTime",   "toDateTime(%r)" % to)
    sql = sql.replace("$__interval_s", isec)
    sql = sql.replace("$__filters", "(1=1)")
    out, i = [], 0
    while True:
        for macro, tmpl in (
            ("$__timeInterval_ms(", "toStartOfInterval(toDateTime({c}), INTERVAL {i} second)"),
            ("$__timeInterval(",    "toStartOfInterval(toDateTime({c}), INTERVAL {i} second)"),
            ("$__timeFilter_ms(",   "({c} >= toDateTime64({f!r}, 3) AND {c} < toDateTime64({t!r}, 3))"),
            ("$__timeFilter(",      "({c} >= toDateTime({f!r}) AND {c} < toDateTime({t!r}))"),
            ("$__dateFilter(",      "({c} >= toDate({f!r}) AND {c} <= toDate({t!r}))"),
        ):
            j = sql.find(macro)
            if j < 0:
                continue
            k = sql.index(")", j)
            col = sql[j + len(macro):k]
            sql = sql[:j] + tmpl.format(c=col, i=isec, f=frm, t=to) + sql[k + 1:]
            break
        else:
            return sql

for path in sorted(glob.glob(os.path.join(dash_dir, "*.json"))):
    for tile in json.load(open(path))["tiles"]:
        cfg = tile.get("config", {})
        if cfg.get("configType") != "sql":
            continue
        label = "%s / %s" % (os.path.basename(path)[:2], tile["name"])
        sql = expand(cfg["sqlTemplate"]).replace("__DATABASE__", db)
        print("%s\t%s" % (label, " ".join(sql.split())))
' "$here/dashboards" "$from" "$to" "$interval_s" "$db")"

if [[ -z "$tiles" ]]; then
  echo "check-tiles.sh: no SQL tiles found under $here/dashboards" >&2
  exit 1
fi

while IFS=$'\t' read -r label sql; do
  [[ -z "$label" ]] && continue
  if out="$("$ch" "$sql" 2>&1)"; then
    rows="$(printf '%s' "$out" | tail -n +2 | grep -c . || true)"
    printf 'PASS  %-72s %s row(s)\n' "$label" "$rows"
    if $show_rows && [[ "$rows" != "0" ]]; then
      printf '%s' "$out" | head -3 | sed 's/^/        /'
    fi
    pass=$((pass + 1))
  else
    printf 'FAIL  %s\n' "$label"
    printf '%s\n' "$out" | grep -oE 'DB::Exception:[^(]*' | head -1 | sed 's/^/        /'
    fail=$((fail + 1))
  fi
done <<< "$tiles"

echo
echo "$pass passed, $fail failed"
[[ "$fail" == "0" ]]
