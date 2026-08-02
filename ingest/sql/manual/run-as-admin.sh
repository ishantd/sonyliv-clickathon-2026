#!/usr/bin/env bash
# run-as-admin.sh — run one of the files in this directory as the admin account.
#
#   ./ingest/sql/manual/run-as-admin.sh ingest/sql/manual/012_demo_database.sql
#   ./ingest/sql/manual/run-as-admin.sh --query "SHOW GRANTS FOR sonyliv_svc"
#
# Everything in sql/manual/ needs privileges sonyliv_svc does not have — CREATE
# DATABASE, CREATE USER, GRANT — and is therefore deliberately excluded from
# `make schema` (chx.Schema reads only the top level of sql/, and ReadDir does
# not recurse). This wrapper exists so that running one of them is a reviewable
# command rather than a shell-history one-liner with a password in it.
#
# It swaps CLICKHOUSE_USER/PASSWORD for CLICKHOUSE_ADMIN_USER/PASSWORD out of the
# same .env and hands off to ch.sh, so there is exactly one HTTP client in this
# repo and one place where the password could leak. The admin password is read
# into a variable and never printed, never passed on a command line (which would
# put it in `ps`), and never written to a file.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

# Same upward walk as ch.sh and config.findEnvFile, so this works from a worktree
# whose .env lives in the parent checkout.
env_file=""
dir="$repo_root"
for _ in 1 2 3 4 5 6; do
  if [[ -f "$dir/.env" ]]; then env_file="$dir/.env"; break; fi
  dir="$(dirname "$dir")"
done
if [[ -z "$env_file" ]]; then
  echo "run-as-admin: no .env found walking up from $repo_root" >&2
  exit 1
fi

admin_user=""
admin_pass=""
while IFS= read -r line; do
  case "$line" in
    CLICKHOUSE_ADMIN_USER=*)     admin_user="${line#*=}" ;;
    CLICKHOUSE_ADMIN_PASSWORD=*) admin_pass="${line#*=}" ;;
  esac
done < "$env_file"

# Strip one layer of surrounding quotes if present, matching ch.sh's handling.
#
# Prefix/suffix removal rather than ${v:1:-1}: macOS ships bash 3.2, where a
# NEGATIVE substring length is a hard error — `-1: substring expression < 0` —
# and this script died on its first run for exactly that reason. ch.sh gets away
# with the same idiom only because its values happen to be unquoted, so the
# branch never executes there. The length guard stays so a lone `"` is left
# alone instead of becoming an empty password.
unquote() {
  local v="$1"
  if [[ ${#v} -ge 2 ]]; then
    case "$v" in
      \"*\") v="${v#\"}"; v="${v%\"}" ;;
      \'*\') v="${v#\'}"; v="${v%\'}" ;;
    esac
  fi
  printf '%s' "$v"
}
admin_user="$(unquote "$admin_user")"
admin_pass="$(unquote "$admin_pass")"

if [[ -z "$admin_user" || -z "$admin_pass" ]]; then
  echo "run-as-admin: CLICKHOUSE_ADMIN_USER / CLICKHOUSE_ADMIN_PASSWORD not set in $env_file" >&2
  exit 1
fi

echo "run-as-admin: connecting as ${admin_user}" >&2

# A single query passes straight through.
if [[ "${1:-}" == "--query" ]]; then
  shift
  CLICKHOUSE_USER="$admin_user" CLICKHOUSE_PASSWORD="$admin_pass" \
    exec "$repo_root/ingest/concurrency/ch.sh" "$@"
fi

if [[ $# -ne 1 || ! -f "$1" ]]; then
  CLICKHOUSE_USER="$admin_user" CLICKHOUSE_PASSWORD="$admin_pass" \
    exec "$repo_root/ingest/concurrency/ch.sh" "$@"
fi

# A FILE is split into statements and sent one at a time.
#
# ClickHouse's HTTP interface takes exactly one statement per request — verified:
#
#     Code: 62. DB::Exception: Syntax error (Multi-statements are not allowed)
#
# The files here are written for `clickhouse client --queries-file`, which does
# accept several. Rather than require that binary just for the handful of admin
# files, split here. The splitter strips `--` line comments and breaks on `;`,
# which is sound for these files because none of them contains a semicolon
# inside a string literal — and it refuses rather than guesses if one ever does.
sql_file="$1"

statements_tmp="$(mktemp)"
trap 'rm -f "$statements_tmp"' EXIT

expected="$(python3 - "$sql_file" "$statements_tmp" <<'PY'
import sys

src, out = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read()

# Strip whole-line and trailing `--` comments. Deliberately naive, and guarded
# below: a `--` inside a string literal would be mangled, so refuse that case
# rather than send something subtly different from what the file says.
stripped = []
for line in text.split("\n"):
    if "'" in line and "--" in line and line.index("'") < line.index("--"):
        sys.exit(f"run-as-admin: {src} has a `--` after a quote; split by hand")
    stripped.append(line.split("--", 1)[0])
body = "\n".join(stripped)

if body.count("'") % 2:
    sys.exit(f"run-as-admin: {src} has an unbalanced quote after comment stripping")

parts = [p.strip() for p in body.split(";")]
parts = [p for p in parts if p]
if not parts:
    sys.exit(f"run-as-admin: {src} contains no statements")

# NUL-TERMINATED, not NUL-separated, and the difference is not cosmetic:
# `read -d ''` only yields a field when it finds the delimiter, so with
# "\0".join(...) the final statement has no trailing NUL and is silently
# DROPPED. That shipped once — 012 reported "10 statement(s) applied" for an
# 11-statement file and the missing one was a GRANT, so the failure was a
# missing privilege discovered later rather than an error at the time.
#
# The count printed at the end is the guard against a repeat: it is the number
# of statements actually SENT, so it can be compared against the file.
with open(out, "w", encoding="utf-8") as fh:
    for p in parts:
        fh.write(p)
        fh.write("\0")
print(len(parts))
PY
)"

n=0
while IFS= read -r -d '' stmt; do
  n=$(( n + 1 ))
  # One line of echo per statement, truncated: enough to see which one failed,
  # short enough not to bury the output of the ones that returned rows.
  summary="$(printf '%s' "$stmt" | tr '\n' ' ' | tr -s ' ' | cut -c1-72)"
  printf '  [%d] %s\n' "$n" "$summary" >&2
  CLICKHOUSE_USER="$admin_user" CLICKHOUSE_PASSWORD="$admin_pass" \
    "$repo_root/ingest/concurrency/ch.sh" "$stmt"
done < "$statements_tmp"

if [[ "$n" != "$expected" ]]; then
  echo "run-as-admin: sent $n of $expected statements from $sql_file -- ABORTING" >&2
  exit 1
fi
echo "run-as-admin: $n statement(s) applied from $sql_file" >&2
