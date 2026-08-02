#!/usr/bin/env python3
"""Apply a ClickHouse .sql file over HTTPS, one statement at a time.

Exists because the two obvious alternatives both fail here:

  * ClickHouse's HTTP interface executes ONE statement per request, so a
    multi-statement file cannot simply be POSTed.
  * Splitting on ';' with sed/awk breaks on semicolons inside string literals
    and inside comments, and this repo's DDL has both.

Standard library only, so the bootstrap has no pip dependency.

Reads the password from the CLICKHOUSE_PASSWORD environment variable and never
prints it, not even in an error.
"""

from __future__ import annotations

import argparse
import os
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


def split_statements(sql: str) -> list[str]:
    """Split on top-level semicolons.

    Tracks single-quoted strings (with '' and backslash escapes), backquoted
    identifiers, double-quoted identifiers, -- line comments and /* */ block
    comments, so a ';' inside any of them does not end a statement.
    """
    out: list[str] = []
    buf: list[str] = []
    i, n = 0, len(sql)
    in_squote = in_dquote = in_backtick = False
    in_line_comment = in_block_comment = False

    while i < n:
        c = sql[i]
        nxt = sql[i + 1] if i + 1 < n else ""

        if in_line_comment:
            buf.append(c)
            if c == "\n":
                in_line_comment = False
            i += 1
            continue
        if in_block_comment:
            buf.append(c)
            if c == "*" and nxt == "/":
                buf.append(nxt)
                i += 2
                in_block_comment = False
                continue
            i += 1
            continue
        if in_squote:
            buf.append(c)
            if c == "\\" and nxt:
                buf.append(nxt)
                i += 2
                continue
            if c == "'":
                if nxt == "'":          # '' is an escaped quote, not a close
                    buf.append(nxt)
                    i += 2
                    continue
                in_squote = False
            i += 1
            continue
        if in_dquote or in_backtick:
            buf.append(c)
            if (in_dquote and c == '"') or (in_backtick and c == "`"):
                in_dquote = in_backtick = False
            i += 1
            continue

        # Not inside anything.
        if c == "-" and nxt == "-":
            in_line_comment = True
            buf.append(c)
            i += 1
            continue
        if c == "/" and nxt == "*":
            in_block_comment = True
            buf.append(c)
            buf.append(nxt)
            i += 2
            continue
        if c == "'":
            in_squote = True
            buf.append(c)
            i += 1
            continue
        if c == '"':
            in_dquote = True
            buf.append(c)
            i += 1
            continue
        if c == "`":
            in_backtick = True
            buf.append(c)
            i += 1
            continue
        if c == ";":
            out.append("".join(buf))
            buf = []
            i += 1
            continue

        buf.append(c)
        i += 1

    out.append("".join(buf))
    return [s for s in (strip_to_sql(x) for x in out) if s]


def strip_to_sql(stmt: str) -> str:
    """Drop a statement that is only whitespace and comments."""
    body_chars = []
    i, n = 0, len(stmt)
    in_line = in_block = False
    while i < n:
        c = stmt[i]
        nxt = stmt[i + 1] if i + 1 < n else ""
        if in_line:
            if c == "\n":
                in_line = False
            i += 1
            continue
        if in_block:
            if c == "*" and nxt == "/":
                in_block = False
                i += 2
                continue
            i += 1
            continue
        if c == "-" and nxt == "-":
            in_line = True
            i += 2
            continue
        if c == "/" and nxt == "*":
            in_block = True
            i += 2
            continue
        body_chars.append(c)
        i += 1
    return stmt.strip() if "".join(body_chars).strip() else ""


def summarise(stmt: str, width: int = 110) -> str:
    """First non-comment line, for progress output."""
    for line in stmt.splitlines():
        s = line.strip()
        if s and not s.startswith("--"):
            return s[:width] + ("…" if len(s) > width else "")
    return stmt.strip()[:width]


def execute(cfg, sql: str, params: dict[str, str] | None = None) -> str:
    query = {"database": cfg.database}
    for k, v in (params or {}).items():
        query[f"param_{k}"] = v
    url = f"{cfg.base_url}/?{urllib.parse.urlencode(query)}"

    req = urllib.request.Request(url, data=sql.encode("utf-8"), method="POST")
    req.add_header("X-ClickHouse-User", cfg.user)
    if cfg.password:
        req.add_header("X-ClickHouse-Key", cfg.password)

    ctx = ssl.create_default_context()
    last_err = None
    for attempt in range(1, cfg.retries + 1):
        try:
            with urllib.request.urlopen(req, timeout=cfg.timeout, context=ctx) as resp:
                return resp.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            # A server-side rejection is deterministic; retrying is pointless.
            raise RuntimeError(e.read().decode("utf-8", "replace").strip()) from None
        except (urllib.error.URLError, TimeoutError, ssl.SSLError) as e:
            # Transport-level. Cloud replaces replicas under load (a graceful
            # rolling restart was observed on this service on 2026-08-01), and
            # the documented expectation is that the client retries.
            last_err = e
            if attempt < cfg.retries:
                time.sleep(min(2 ** attempt, 15))
    raise RuntimeError(f"transport failure after {cfg.retries} attempts: {last_err}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("file", nargs="?", help="path to a .sql file ('-' for stdin)")
    ap.add_argument("--query", help="run a single statement instead of a file")
    ap.add_argument("--database", default=os.environ.get("CLICKHOUSE_DATABASE", "default"))
    ap.add_argument("--host", default=os.environ.get("CLICKHOUSE_HOST", "localhost"))
    ap.add_argument("--port", type=int, default=int(os.environ.get("CLICKHOUSE_HTTP_PORT", "8443")))
    ap.add_argument("--user", default=os.environ.get("CLICKHOUSE_USER", "default"))
    ap.add_argument("--insecure", action="store_true", help="plain HTTP (local dev)")
    ap.add_argument("--param", action="append", default=[], metavar="K=V",
                    help="bound query parameter, repeatable")
    ap.add_argument("--rewrite-db", metavar="FROM", default=None,
                    help="rewrite a hardcoded 'FROM.' database prefix to --database. "
                         "pipeline/sql/* hardcode 'sonyliv.' rather than using {{db}}, so "
                         "without this they would create their objects in 'sonyliv' while "
                         "ingest/sql/* went to --database — a silent split across two databases. "
                         "'sonyliv_prod.' is NOT matched by 'sonyliv.' (the underscore differs).")
    ap.add_argument("--dry-run", action="store_true", help="print statements, execute nothing")
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("--timeout", type=int, default=600)
    ap.add_argument("--retries", type=int, default=4)
    args = ap.parse_args()

    args.password = os.environ.get("CLICKHOUSE_PASSWORD", "")
    scheme = "http" if args.insecure else "https"
    args.base_url = f"{scheme}://{args.host}:{args.port}"

    params = {}
    for p in args.param:
        if "=" not in p:
            print(f"error: --param must be K=V, got {p!r}", file=sys.stderr)
            return 2
        k, v = p.split("=", 1)
        params[k] = v

    if args.query:
        statements = [args.query]
        label = "<--query>"
    else:
        if not args.file:
            print("error: give a .sql file or --query", file=sys.stderr)
            return 2
        raw = sys.stdin.read() if args.file == "-" else open(args.file, encoding="utf-8").read()
        # {{db}} keeps the DDL portable across sonyliv / sonyliv_prod / a scratch db.
        raw = raw.replace("{{db}}", args.database)
        if args.rewrite_db and args.rewrite_db != args.database:
            src = f"{args.rewrite_db}."
            n = raw.count(src)
            raw = raw.replace(src, f"{args.database}.")
            if not args.quiet and n:
                print(f"  rewrote {n} occurrence(s) of '{src}' -> '{args.database}.'")
        statements = split_statements(raw)
        label = args.file

    if not args.quiet:
        print(f"  {label}: {len(statements)} statement(s) -> {args.database}")

    for idx, stmt in enumerate(statements, 1):
        if args.dry_run:
            print(f"\n-- [{idx}/{len(statements)}] {label}\n{stmt};")
            continue
        try:
            out = execute(args, stmt, params)
        except RuntimeError as e:
            # Fail loud, and say exactly which statement, so the operator can
            # resume from here rather than re-running the whole stage blind.
            print(f"\nFAILED {label} statement {idx}/{len(statements)}:", file=sys.stderr)
            print(f"  {summarise(stmt)}", file=sys.stderr)
            print(f"\n{e}\n", file=sys.stderr)
            return 1
        if not args.quiet:
            print(f"    [{idx}/{len(statements)}] ok  {summarise(stmt, 88)}")
        if out.strip():
            print(out.rstrip())
    return 0


if __name__ == "__main__":
    sys.exit(main())
