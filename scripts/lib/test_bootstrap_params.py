#!/usr/bin/env python3
"""Every {param:Type} a SQL file needs must actually be passed by bootstrap.sh.

    python3 scripts/lib/test_bootstrap_params.py

WHY THIS EXISTS. bootstrap.sh invokes each parameterised SQL file through a
backslash-continued `ch ... --param ... --param ...` command. A `#` comment line
placed BETWEEN those continued lines silently ends the command: every argument
after it is dropped. The file stays syntactically valid, so `bash -n` reports OK,
and the failure only appears on the live service as

    Code: 456. Substitution `allow_boundary_sessions` is not set.

after the 7,000,000-row load has already run. That shipped once. `bash -n` cannot
catch it, a dry run cannot catch it (a dry run executes nothing), and reading the
diff did not catch it either.

This test drives the REAL bootstrap.sh with `ch` replaced by a tracer, so it sees
the arguments as the shell actually assembles them -- not as they appear in the
source. Then it diffs them against the parameters each SQL file really
references.
"""

import os
import pathlib
import re
import subprocess
import sys
import unittest

REPO = pathlib.Path(__file__).resolve().parents[2]
BOOTSTRAP = REPO / "scripts" / "bootstrap.sh"

# Parameters ClickHouse itself supplies, or that a file references only inside a
# comment. Nothing here today, but the hook is where an exception would go.
IGNORED: set[str] = set()


def trace_calls(*args: str) -> dict[str, set[str]]:
    """Run bootstrap.sh with ch()/chq() stubbed, return {sql basename: {params}}.

    The stub script is written NEXT TO the real one: bootstrap.sh derives
    REPO_ROOT from BASH_SOURCE, so running a copy out of /tmp resolves every
    path to the wrong place and finds no SQL at all.
    """
    src = BOOTSTRAP.read_text()
    src = src.replace(
        'ch()     { python3 "$APPLY" "$1" --database "$DATABASE" $INSECURE $DRY "${@:2}"; }',
        'ch()     { echo "CH_CALL $(basename "$1") :: ${*:2}"; }',
    )
    src = src.replace(
        'chq()    { python3 "$APPLY" --query "$1" --database "$DATABASE" $INSECURE --quiet "${@:2}"; }',
        'chq()    { echo 0; }',
    )
    # The Go loader would try to reach the service.
    src = re.sub(r'^\s*"\$GEN".*$', '      echo "GEN stub"', src, flags=re.M)

    stub = BOOTSTRAP.with_name("_test_trace_bootstrap.sh")
    stub.write_text(src)
    stub.chmod(0o755)
    try:
        r = subprocess.run(
            ["bash", str(stub), *args],
            capture_output=True, text=True, cwd=str(REPO),
            env=dict(os.environ, CLICKHOUSE_HOST="stub", CLICKHOUSE_PASSWORD="x"),
        )
    finally:
        stub.unlink(missing_ok=True)

    out: dict[str, set[str]] = {}
    for line in r.stdout.split("\n"):
        if not line.startswith("CH_CALL"):
            continue
        name, _, rest = line[len("CH_CALL"):].partition("::")
        params = {m.split("=", 1)[0] for m in re.findall(r"--param\s+(\S+)", rest)}
        out.setdefault(name.strip(), set()).update(params)
    return out


def required_params(sql_path: pathlib.Path) -> set[str]:
    """The {name:Type} substitutions a file references OUTSIDE comments."""
    body = "\n".join(
        l for l in sql_path.read_text().split("\n") if not l.strip().startswith("--")
    )
    return {m for m in re.findall(r"\{(\w+):[A-Za-z0-9_()\s,']+\}", body)} - IGNORED


class TestBootstrapPassesEveryParam(unittest.TestCase):
    def test_full_run(self):
        self._check(trace_calls("--database", "sonyliv"), "full run")

    def test_no_seed(self):
        self._check(trace_calls("--no-seed", "--database", "sonyliv"), "--no-seed")

    def test_build_only(self):
        self._check(trace_calls("--build-only", "--database", "sonyliv"), "--build-only")

    def _check(self, calls, label):
        self.assertTrue(calls, f"{label}: bootstrap made no ch() calls at all")
        for basename, passed in sorted(calls.items()):
            # Resolve the file; it may live under ingest/sql or pipeline/sql.
            matches = list(REPO.glob(f"*/sql/{basename}"))
            if not matches:
                continue
            need = required_params(matches[0])
            missing = need - passed
            with self.subTest(stage=label, file=basename):
                self.assertFalse(
                    missing,
                    f"{label}: {basename} needs {sorted(need)} but bootstrap passes "
                    f"{sorted(passed)}; MISSING {sorted(missing)}. A comment between "
                    f"backslash-continued --param lines will do this silently.",
                )

    def test_the_regression_itself(self):
        """011 must receive allow_boundary_sessions. This is the one that shipped."""
        calls = trace_calls("--no-seed", "--database", "sonyliv")
        k = "011_build_active_intervals.sql"
        self.assertIn(k, calls, "011 was not invoked at all under --no-seed")
        self.assertIn("allow_boundary_sessions", calls[k])
        self.assertIn("full_scan", calls[k])
        self.assertGreaterEqual(len(calls[k]), 7, f"only {len(calls[k])} params reached 011")


class TestNoCommentInsideLineContinuation(unittest.TestCase):
    """Catch the shape directly, so the diff is reviewable as well as testable."""

    def test_no_comment_between_continued_lines(self):
        bad = []
        lines = BOOTSTRAP.read_text().split("\n")
        for i, line in enumerate(lines[:-1]):
            if line.rstrip().endswith("\\") and lines[i + 1].strip().startswith("#"):
                bad.append(i + 2)
        self.assertFalse(
            bad,
            f"comment line(s) at {bad} sit inside a backslash continuation. The "
            f"shell ends the command there and silently drops every later "
            f"argument. Move the comment above the command.",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
