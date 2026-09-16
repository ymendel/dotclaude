#!/usr/bin/env bash
# Checks over _harness.sh, the shared tally every other bash suite sources:
#
#   ./test/run-harness.sh
#
# Tier 1, and the tier row is the whole justification for this file existing. If `report false`
# stopped incrementing `fail`, every suite in the repo would print its FAIL lines and still exit 0 —
# a green run with failing cases in it, which is the exact false green ADR 0008 is built around. The
# harness is the one unit whose breakage is silent in every other unit at once.
#
# THIS SUITE DOES NOT SOURCE THE HARNESS, which is the one deviation from the convention in the repo
# and is deliberate. A suite using the harness to report on the harness cannot distinguish "the
# assertion passed" from "the reporting is broken in a way that says so" — the instrument and the
# subject would be the same object. So the tally below is local and minimal, and the subject is
# invoked in a separate `bash -c` per case so each starts from unsourced state.
#
# The separate process also sidesteps the double-source guard: `_HARNESS_LOADED` is a plain shell
# variable, so a subshell would inherit it from a parent that had already sourced the file and every
# case would hit the early return instead of the code under test.
#
# No framework, no `set -e`, non-zero exit at the end.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBJECT="$TEST_DIR/_harness.sh"

if [ ! -f "$SUBJECT" ]; then
    echo "run-harness: $SUBJECT is missing." >&2
    exit 1
fi

pass=0
fail=0

ok() { pass=$((pass + 1)); printf 'PASS  %s\n' "$1"; }
no() { fail=$((fail + 1)); printf 'FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '      %s\n' "$2"; }

# harness <body> — run the body in a fresh bash with the subject sourced.
# Output lands in $OUT and the body's status in $STATUS.
harness() {
    OUT=$(bash -c ". '$SUBJECT'; $1" 2>&1)
    STATUS=$?
}

# emits <body> <wanted-substring> <label>
emits() {
    harness "$1"
    if [[ "$OUT" == *"$2"* ]]; then
        ok "$3"
    else
        no "$3" "output was: ${OUT:-<empty>}"
    fi
}

# lacks <body> <unwanted-substring> <label>
lacks() {
    harness "$1"
    if [[ "$OUT" == *"$2"* ]]; then
        no "$3" "output unexpectedly contained '$2': $OUT"
    else
        ok "$3"
    fi
}

# status_is <body> <wanted> <label>
status_is() {
    harness "$1"
    if [ "$STATUS" = "$2" ]; then
        ok "$3"
    else
        no "$3" "expected exit $2, got $STATUS"
    fi
}

# --- Counting, which is what silently breaks --------------------------------

emits 'report true "a case"; echo "count=$pass"' 'count=1' 'report true increments pass'
emits 'report true "a case"; echo "count=$fail"' 'count=0' 'report true leaves fail alone'
emits 'report false "a case"; echo "count=$fail"' 'count=1' 'report false increments fail'
emits 'report false "a case"; echo "count=$pass"' 'count=0' 'report false leaves pass alone'
emits 'report_skip "a case"; echo "count=$skip"' 'count=1' 'report_skip increments skip'
emits 'report_skip "a case"; echo "p=$pass f=$fail"' 'p=0 f=0' 'a skip is neither a pass nor a fail'

# Counters start at zero rather than inheriting whatever the environment held.
emits 'echo "p=$pass f=$fail s=$skip"' 'p=0 f=0 s=0' 'the tally starts at zero'

# --- What each line says ----------------------------------------------------

emits 'report true "the label"' 'PASS  the label' 'a pass prints PASS and the label'
emits 'report false "the label"' 'FAIL  the label' 'a failure prints FAIL and the label'
emits 'report false "l" "the detail"' 'the detail' 'a failure prints its detail'
lacks 'report true "l" "the detail"' 'the detail' 'a pass does not print a detail'
emits 'report_skip "l" "the reason"' 'SKIP  l' 'a skip prints SKIP and the label'
emits 'report_skip "l" "the reason"' 'the reason' 'a skip prints its reason'

# `report` must not fail the caller. It is often the last command in an `if` arm, and a non-zero
# return would propagate into a suite's own exit status.
status_is 'report false "a case"' 0 'report false returns 0 to its caller'
status_is 'report_skip "a case"' 0 'report_skip returns 0 to its caller'

# --- expect_eq --------------------------------------------------------------

emits 'expect_eq abc abc "the label"' 'PASS  the label' 'expect_eq reports a match as a pass'
emits 'expect_eq abc xyz "the label"' 'FAIL  the label' 'expect_eq reports a mismatch as a failure'
emits 'expect_eq abc xyz "l"' "expected 'xyz', got 'abc'" 'expect_eq shows both values on mismatch'
emits 'expect_eq "" xyz "l"' '<empty>' 'expect_eq names an empty actual value rather than showing nothing'

# --- summary, whose return value is a suite exit status ---------------------

status_is 'summary' 0 'summary returns 0 when nothing failed'
status_is 'report true x; summary' 0 'summary returns 0 after a pass'
status_is 'report false x; summary' 1 'summary returns 1 after a failure'
status_is 'report true x; report false y; summary' 1 'one failure among passes still returns 1'
status_is 'report_skip x; summary' 0 'a skip alone does not fail the suite'

emits 'report true x; summary' '1 passed, 0 failed' 'summary prints the tally'
lacks 'report true x; summary' 'skipped' 'summary omits the skip count when nothing skipped'
emits 'report_skip x; summary' '1 skipped' 'summary reports skips when there are any'

# --- The double-source guard ------------------------------------------------
#
# Two suites sourcing the harness, or a suite sourcing it twice, must not reset a run's counts
# halfway through — which would discard failures already recorded and leave a green summary.

emits "report false x; . '$SUBJECT'; echo \"f=\$fail\"" 'f=1' 're-sourcing does not reset the tally'
status_is "report false x; . '$SUBJECT'; summary" 1 're-sourcing does not turn a failed run green'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
