#!/usr/bin/env bash
# Shared tally and reporting for this repo's bash test suites. Sourced, never run:
#
#   . "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/test/_harness.sh"
#
# ADR 0008 chose plain bash over bats, and listed the shared-helper question as an open cost that
# "comes due with the second suite". This is that helper, arriving at the sixth. What it replaces
# was a ~30-line block copied into each suite — which had already drifted into two shapes, a
# `report` in four suites and a differently-built `check` in the fifth.
#
# WHAT IS SHARED IS THE TALLY, NOT THE ASSERTION. Each suite still builds its own fixtures and
# invokes its own subject, because that part is domain-specific: a PreToolUse payload on stdin, a
# transcript tree under a fake HOME, and a staged git index have nothing in common to factor out.
# Only the counting and the PASS/FAIL line were ever duplicated, so only those live here.
#
# NAMED WITH A LEADING UNDERSCORE ON PURPOSE. `scripts/run-tests.sh` globs `**/test/*.sh` and
# refuses any file there not named `run-*.sh`, because a suite whose name drifted would otherwise be
# skipped silently. An underscore prefix is the documented "not a suite" marker that guard exempts —
# see its header. The exemption is narrow by design: the two real drift cases were `<topic>-checks.sh`
# names, which are still refused.
#
# NO `set -e`. A failing case must report and let the rest of the suite run, which is the same
# reason the suites themselves do not set it.

# Guard against double-sourcing, which would reset a suite's counts mid-run.
[ -n "${_HARNESS_LOADED:-}" ] && return 0
_HARNESS_LOADED=1

pass=0
fail=0
skip=0

# report <true|false> <label> [detail] — record one case.
# The signature the four `report`-shaped suites already called, so they migrate by deletion.
report() {
    if [ "$1" = true ]; then
        pass=$((pass + 1))
        printf 'PASS  %s\n' "$2"
    else
        fail=$((fail + 1))
        printf 'FAIL  %s\n' "$2"
        [ -n "${3:-}" ] && printf '      %s\n' "$3"
    fi
    return 0
}

# report_skip <label> [why] — a case that could not run here, counted apart from a pass.
# A skip must never read as a pass: `run-checks.sh` skips its symlink case when the documented
# `~/.claude` install is absent, and reporting that as green would assert something never checked.
report_skip() {
    skip=$((skip + 1))
    printf 'SKIP  %s\n' "$1"
    [ -n "${2:-}" ] && printf '      %s\n' "$2"
    return 0
}

# expect_eq <got> <want> <label> — compare two strings and report. The common case by volume.
# Not named `expect`: run-measure-writes.sh already has a local `expect` taking a label and looking
# its value up in captured output, and a sourced definition it silently overrode would be worse
# than a collision that never happens.
expect_eq() {
    if [ "$1" = "$2" ]; then
        report true "$3"
    else
        report false "$3" "expected '$2', got '${1:-<empty>}'"
    fi
}

# summary — print the tally and return the status the suite should exit with.
# Call as the last line: `summary` — or `summary || exit 1` where the suite wants to be explicit.
# Returns 1 when anything failed, so a suite's exit status is its own result rather than the
# status of whatever printf ran last.
summary() {
    printf '\n%d passed, %d failed' "$pass" "$fail"
    [ "$skip" -gt 0 ] && printf ', %d skipped' "$skip"
    printf '\n'
    [ "$fail" -eq 0 ]
}
