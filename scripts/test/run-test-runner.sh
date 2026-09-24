#!/usr/bin/env bash
# Checks over run-tests.sh, the entry point that discovers and runs every other suite:
#
#   ./scripts/test/run-test-runner.sh
#
# ADR 0008 puts it in Tier 1 for a reason worth restating, because it is the reason this file is
# adversarial rather than happy-path: "its failure mode is a false green — a suite it silently fails
# to discover reads exactly like a suite that passed." Every case below is built to tell those two
# apart. A case asserting only that a passing suite passes would hold just as well on a runner that
# had stopped discovering anything.
#
# FIXTURES ARE WHOLE REPO TREES, not flags. The subject resolves its own root from `BASH_SOURCE/..`
# and cd's there, so it can only ever be pointed somewhere else by putting a copy of it in a
# synthesised tree — `$FIX/scripts/run-tests.sh` with fixture suites around it. That is the whole
# isolation mechanism: no case reads this repo's real suites, and the expected counts are known in
# advance rather than compared against whatever happens to be on disk.
#
# Fixture suites are trivial on purpose (`exit 0`, `exit 1`) and do NOT source test/_harness.sh —
# the fixture root has no harness, and a suite that needed one would be testing the harness instead
# of the discovery.
#
# No framework, no `set -e` (a failing case must report, not abort), non-zero exit at the end.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
SUBJECT="$REPO_ROOT/scripts/run-tests.sh"

if [ ! -x "$SUBJECT" ]; then
    echo "run-test-runner: $SUBJECT is missing or not executable." >&2
    exit 1
fi

. "$REPO_ROOT/test/_harness.sh"

WORK_DIR="$(mktemp -d)"
cleanup() { [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"; }
trap cleanup EXIT

# fresh — discard the previous fixture tree and install a copy of the subject in a new one.
fresh() {
    FIX="$WORK_DIR/repo"
    rm -rf "$FIX"
    mkdir -p "$FIX/scripts"
    cp "$SUBJECT" "$FIX/scripts/run-tests.sh"
    chmod +x "$FIX/scripts/run-tests.sh"
}

# suite <relative-path> <exit-code> [line] — plant a fixture suite that prints and exits as told.
# The optional line is what it prints, which is how the "exit status is the suite's own" case plants
# a suite whose output says PASS while its status says otherwise.
suite() {
    local path="$FIX/$1" code="$2" line="${3:-fixture suite ran}"
    mkdir -p "$(dirname "$path")"
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s"\nexit %s\n' "$line" "$code" > "$path"
    chmod +x "$path"
}

# plain_file <relative-path> — a non-executable file, for the name guard and the executable check.
plain_file() {
    local path="$FIX/$1"
    mkdir -p "$(dirname "$path")"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$path"
}

# run [args...] — invoke the fixture's copy of the subject. Output in $OUT, status in $STATUS.
run() {
    OUT="$WORK_DIR/out.txt"
    "$FIX/scripts/run-tests.sh" "$@" > "$OUT" 2>&1
    STATUS=$?
}

# saw <substring> <label> — assert the captured output contains it.
saw() {
    if grep -qF "$1" "$OUT"; then
        report true "$2"
    else
        report false "$2" "output did not contain '$1'"
    fi
}

# did_not_see <substring> <label>
did_not_see() {
    if grep -qF "$1" "$OUT"; then
        report false "$2" "output unexpectedly contained '$1'"
    else
        report true "$2"
    fi
}

# exited <want> <label>
exited() {
    if [ "$STATUS" = "$1" ]; then
        report true "$2"
    else
        report false "$2" "expected exit $1, got $STATUS"
    fi
}

# --- Discovery, which is the tier row's stated failure mode -----------------

fresh
suite hooks/test/run-alpha.sh 0
run
exited 0 'a single passing suite exits 0'
saw 'hooks/test/run-alpha.sh' 'the suite is named in the output'
saw '1 suites, all passed' 'one suite is discovered and counted once'

# The dedup case. Both globs — `*/test/*.sh` and `**/test/*.sh` — match a suite one level down, and
# without the seen-check it would run twice while the summary still read plausibly.
fresh
suite hooks/test/run-alpha.sh 0
run
alpha_headers=$(grep -c '=== hooks/test/run-alpha.sh ===' "$OUT")
expect_eq "$alpha_headers" 1 'a suite matched by both globs runs exactly once'

# globstar. Without `shopt -s globstar`, `**` behaves as a single `*` and stops one directory down —
# which is how skills/session-handoff/tests was missed on the runner's first real run.
fresh
suite hooks/test/run-alpha.sh 0
suite skills/session-handoff/test/run-deep.sh 0
run
saw 'skills/session-handoff/test/run-deep.sh' 'a suite three levels down is discovered'
saw '2 suites, all passed' 'the deep suite is counted, not just listed'

# --- The name guard, and the underscore exemption --------------------------

fresh
suite hooks/test/run-alpha.sh 0
plain_file hooks/test/alpha-checks.sh
run
exited 2 'a misnamed file in test/ refuses the whole run'
saw 'not named run-*.sh' 'the refusal explains the naming rule'
saw 'alpha-checks.sh' 'the refusal names the offending file'
did_not_see 'all passed' 'a refused run never reports green'

# The exemption added for test/_harness.sh. It must skip, not refuse — and not be run as a suite.
fresh
suite hooks/test/run-alpha.sh 0
plain_file hooks/test/_helper.sh
run
exited 0 'an underscore-prefixed file does not refuse the run'
saw '1 suites, all passed' 'the underscore file is not counted as a suite'
did_not_see '_helper.sh' 'the underscore file is not run'

# The exemption must stay narrow: the drift shape that motivated the guard is still refused even
# when an underscore file sits beside it.
fresh
suite hooks/test/run-alpha.sh 0
plain_file hooks/test/_helper.sh
plain_file hooks/test/alpha-checks.sh
run
exited 2 'a misnamed file is still refused alongside an exempt one'

# --- A false green is the thing this unit exists not to produce -------------

# Status comes from the suite, never from its output. A fixture that prints a pass line and exits
# non-zero is exactly the shape a grep-based runner would report as green.
fresh
suite hooks/test/run-liar.sh 1 'PASS  everything is fine'
run
exited 1 'a suite that prints PASS but exits 1 fails the run'
saw 'hooks/test/run-liar.sh' 'the failing suite is named in the failure list'
saw '1 of 1 suites failed' 'the failure count is reported'

fresh
suite hooks/test/run-alpha.sh 0
suite hooks/test/run-beta.sh 1
run
exited 1 'one failing suite among two fails the run'
saw '1 of 2 suites failed' 'the passing suite still runs and is counted'

# Discovering nothing is a discovery failure, not a pass — the emptiest false green there is.
fresh
run
exited 1 'a tree with no suites exits 1'
saw 'discovery failure, not a pass' 'the empty run says why it is not a pass'

# A suite present but not executable must fail rather than be passed over.
fresh
suite hooks/test/run-alpha.sh 0
plain_file hooks/test/run-broken.sh
run
exited 1 'a non-executable suite fails the run'
saw 'not executable' 'the reason names executability'
did_not_see 'all passed' 'a non-executable suite does not leave a green summary'

# --- --list reports without running -----------------------------------------

fresh
suite hooks/test/run-alpha.sh 0 'THIS SHOULD NOT RUN'
run --list
exited 0 '--list exits 0'
saw 'hooks/test/run-alpha.sh' '--list names the discovered suite'
did_not_see 'THIS SHOULD NOT RUN' '--list does not execute the suites it lists'

# --list reports the unittest packages separately from the bash suites.
fresh
suite hooks/test/run-alpha.sh 0
mkdir -p "$FIX/scripts/tests"
run --list
saw 'unittest packages:' '--list has a section for unittest packages'
saw 'scripts/tests' '--list names a discovered unittest package'

fresh
suite hooks/test/run-alpha.sh 0
run --list
saw '(none)' '--list says so explicitly when no unittest package exists'

# --- Gitignored trees are not ours ------------------------------------------
#
# A vendored tree ships its own tests, and discovering them means running third-party code and
# reporting its failures as this repo's. Every case above runs in a fixture that is not a git repo
# at all, which is what pins the fallback: outside a repo nothing is ignored and everything stands.
# These four need a repo, so they make one.
#
# The second case is the load-bearing one. `untracked` is the predicate a fix for this reaches for
# first, and it would silently stop running every suite written and not yet staged — trading the
# vendored-tests problem for the discovery miss that is this unit's whole reason to be Tier 1.

fresh
git -C "$FIX" init --quiet
suite hooks/test/run-alpha.sh 0
suite vendor/marketplace/test/run-theirs.sh 1 'THEIRS RAN'
printf 'vendor/\n' > "$FIX/.gitignore"
run
exited 0 'a failing suite under a gitignored path does not fail the run'
did_not_see 'THEIRS RAN' 'a gitignored suite is not executed'
saw 'passed over as gitignored' 'the run says something was passed over'
saw 'vendor/marketplace/test/run-theirs.sh' 'the passed-over suite is named, not dropped silently'

fresh
git -C "$FIX" init --quiet
printf 'vendor/\n' > "$FIX/.gitignore"
suite hooks/test/run-alpha.sh 0
run
saw 'hooks/test/run-alpha.sh' 'an untracked suite still runs — ignored is the test, not tracked'
did_not_see 'passed over as gitignored' 'nothing is reported when nothing was passed over'

fresh
git -C "$FIX" init --quiet
suite hooks/test/run-alpha.sh 0
mkdir -p "$FIX/vendor/marketplace/tests"
printf 'vendor/\n' > "$FIX/.gitignore"
run
saw '1 suites, all passed' 'a gitignored unittest package is not run'
saw 'vendor/marketplace/tests' 'the passed-over package is named too'

fresh
git -C "$FIX" init --quiet
suite hooks/test/run-alpha.sh 0
plain_file vendor/marketplace/test/helpers.sh
printf 'vendor/\n' > "$FIX/.gitignore"
run
exited 0 'a misnamed file under a gitignored path does not refuse the run'

fresh
git -C "$FIX" init --quiet
suite hooks/test/run-alpha.sh 0
suite vendor/marketplace/test/run-theirs.sh 0
printf 'vendor/\n' > "$FIX/.gitignore"
run --list
saw 'passed over as gitignored:' '--list has a section for passed-over paths'
saw 'vendor/marketplace/test/run-theirs.sh' '--list names a passed-over path'

summary || exit 1
