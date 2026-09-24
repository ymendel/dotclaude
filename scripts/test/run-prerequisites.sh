#!/usr/bin/env bash
# Checks over check-prerequisites.sh, the declared-dependency check:
#
#   ./scripts/test/run-prerequisites.sh
#
# ADR 0008 puts it in Tier 2 because "its exit code is a contract, and its branches need
# synthesised conditions". Both halves shape this suite. The contract is that a *required* absence
# exits 1 and every other absence exits 0 — that cut is the only thing separating the top tier from
# the middle, and it is invisible in the printed output, which reports MISSING identically either
# way. And the branches cannot be reached by running the script here, where everything is installed:
# the all-present path is the only one this machine can produce on its own.
#
# ISOLATION IS THE PATH, and it is total. The subject resolves dependencies with `command -v` and
# otherwise uses only shell builtins, so a PATH containing nothing but a stub directory is enough —
# no real dependency is consulted, and a case for "jq is missing" does not require jq to be absent.
# Each case names exactly which stubs exist, so the expected output is known rather than inherited
# from the machine.
#
# No framework, no `set -e` (a failing case must report, not abort), non-zero exit at the end.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBJECT="$(cd "$TEST_DIR/.." && pwd)/check-prerequisites.sh"

if [ ! -x "$SUBJECT" ]; then
    echo "run-prerequisites: $SUBJECT is missing or not executable." >&2
    exit 1
fi

. "$(cd "$TEST_DIR/../.." && pwd)/test/_harness.sh"

WORK_DIR="$(mktemp -d)"
cleanup() { [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"; }
trap cleanup EXIT

ALL_DEPS="jq python3 rtk gh uv trafilatura"

# The subject needs nothing but shell builtins — except its own `#!/usr/bin/env bash`, which
# resolves `bash` on PATH like anything else. A stub PATH with no bash in it makes every case exit
# 127 before the script runs at all, so the interpreter is linked in alongside the stubs. Resolved
# once, here, while PATH is still the real one.
BASH_BIN="$(command -v bash)"

# with_all_but <dep>... — a stub PATH holding every declared dependency except the named ones.
with_all_but() {
    STUB_DIR="$WORK_DIR/stubs"
    rm -rf "$STUB_DIR"
    mkdir -p "$STUB_DIR"
    ln -s "$BASH_BIN" "$STUB_DIR/bash"
    for dep in $ALL_DEPS; do
        for excluded in "$@"; do
            [ "$dep" = "$excluded" ] && continue 2
        done
        printf '#!/usr/bin/env bash\nexit 0\n' > "$STUB_DIR/$dep"
        chmod +x "$STUB_DIR/$dep"
    done
}

# run — invoke the subject against the stub PATH alone. Output in $OUT, status in $STATUS.
run() {
    OUT=$(PATH="$STUB_DIR" "$SUBJECT" 2>&1)
    STATUS=$?
}

# line_for <dep> — the status word, name and tier the report gave that dependency, with the
# report's alignment padding normalized away. `read` does the trimming and the field splitting,
# which keeps the expected values in each case readable as "what it says" rather than "what it
# says plus however many spaces the column happens to need".
line_for() {
    printf '%s' "$OUT" \
        | grep -E "(ok|MISSING)[[:space:]]+$1[[:space:]]" \
        | while read -r status name tier; do printf '%s %s %s' "$status" "$name" "$tier"; done
}

saw() {
    case "$OUT" in
        *"$1"*) report true "$2" ;;
        *) report false "$2" "output lacked '$1'" ;;
    esac
}

did_not_see() {
    case "$OUT" in
        *"$1"*) report false "$2" "output unexpectedly contained '$1'" ;;
        *) report true "$2" ;;
    esac
}

# --- Everything present -----------------------------------------------------

with_all_but
run
expect_eq "$STATUS" 0 'with every dependency present, exit 0'
did_not_see 'MISSING' 'with every dependency present, nothing is reported missing'
did_not_see 'required* prerequisite is missing' 'no required-missing explanation when nothing is missing'
did_not_see 'do not affect the exit code' 'no friction explanation when nothing is missing'
expect_eq "$(line_for jq)" 'ok jq required' 'a present required dependency is labeled required'
expect_eq "$(line_for rtk)" 'ok rtk load-bearing' 'a present dependency is labeled load-bearing'
expect_eq "$(line_for trafilatura)" 'ok trafilatura optional' 'a present dependency is labeled optional'

# --- The exit-code contract, which the printed output does not reveal -------
#
# Every case below prints a MISSING line. Only the exit code distinguishes them, which is why each
# one asserts the status rather than the text.

with_all_but jq
run
expect_eq "$STATUS" 1 'a missing required dependency exits 1'
expect_eq "$(line_for jq)" 'MISSING jq required' 'the missing required dependency is named with its tier'

with_all_but python3
run
expect_eq "$STATUS" 1 'the other required dependency also exits 1'

with_all_but rtk
run
expect_eq "$STATUS" 0 'a missing load-bearing dependency does not change the exit code'
expect_eq "$(line_for rtk)" 'MISSING rtk load-bearing' 'the missing load-bearing dependency is named with its tier'

with_all_but gh
run
expect_eq "$STATUS" 0 'a second missing load-bearing dependency still exits 0'

with_all_but uv
run
expect_eq "$STATUS" 0 'a third missing load-bearing dependency still exits 0'

with_all_but trafilatura
run
expect_eq "$STATUS" 0 'a missing optional dependency does not change the exit code'
expect_eq "$(line_for trafilatura)" 'MISSING trafilatura optional' 'the missing optional dependency is named with its tier'

# Required dominates: a run missing one of each must still exit 1.
with_all_but jq rtk trafilatura
run
expect_eq "$STATUS" 1 'a required absence outranks load-bearing and optional absences'

with_all_but rtk trafilatura
run
expect_eq "$STATUS" 0 'load-bearing and optional absences together still exit 0'

with_all_but jq python3 rtk gh uv trafilatura
run
expect_eq "$STATUS" 1 'everything missing exits 1'

# --- Which explanation is printed, and which is skipped ---------------------

with_all_but rtk
run
saw 'do not affect the exit code' 'a non-required absence explains why the exit code is unchanged'
did_not_see 'A *required* prerequisite is missing' 'a non-required absence does not claim a required one'

# The required branch exits before reaching the friction paragraph, so a run missing both prints
# only the first. Worth pinning: the two explanations contradict each other if both appear.
with_all_but jq rtk
run
saw 'A *required* prerequisite is missing' 'a required absence explains that it stops you'
did_not_see 'do not affect the exit code' 'the friction explanation is suppressed when a required one is missing'

# --- The report covers the whole declared inventory -------------------------
#
# A dependency silently dropped from one of the three arrays would leave the check passing while no
# longer checking it — the same silence the tier argument rests on.

with_all_but
run
for dep in $ALL_DEPS; do
    if [ -n "$(line_for "$dep")" ]; then
        report true "the report has a line for $dep"
    else
        report false "the report has a line for $dep" 'no line found'
    fi
done

saw 'Checking declared prerequisites:' 'the report is introduced by its heading'

summary || exit 1
