#!/usr/bin/env bash
# Find and run every test suite in the repo, and exit non-zero if any of them fails.
#
#   ./scripts/run-tests.sh [--list]
#
# The single entry point ADR 0008 decides on. The ratchet it defines — a Tier 1 or Tier 2 unit gains
# cases in the same change that touches it — needs one command that proves the rest still passes,
# and this is it.
#
# DISCOVERY, and why it does not trust the names. Bash suites are `<topic>/test/run-<shape>.sh`, one
# per payload shape. Globbing that pattern directly would silently skip a suite whose name drifted,
# and a skipped suite is indistinguishable from a passing one in the output — which is the failure
# the convention exists to prevent, one level up. Both suites written after the ADR was drafted
# arrived misnamed, by two different authors. So this globs every `*/test/*.sh` and REFUSES to run
# when one of them does not match `run-*.sh`, rather than quietly passing over it.
#
# ONE EXEMPTION: a basename starting with `_` is skipped, not refused. That is the marker for a
# file meant to be sourced rather than run — `test/_harness.sh` is the only one today. It is narrow
# deliberately, since both observed drift cases were `<topic>-checks.sh` names and those are still
# refused; an accidental suite does not arrive underscore-prefixed.
#
# A SECOND EXEMPTION: a gitignored path is passed over, so a vendored tree's own tests are neither
# run nor reported. The block below says why the predicate is `ignored` rather than `untracked`.
#
# EXIT STATUS is a suite's own, never a filter's. No suite is piped: output goes straight through,
# and `$?` is read immediately. `tool-and-shell-safety.md`'s pipe rule is the whole reason — a
# filtered suite whose status comes from the filter is exactly the trap this repo warns about, and a
# test runner is the worst possible place to fall into it.
#
# PYTHON SUITES RUN UNDER STDLIB `unittest`, not pytest, and need no `uv`. The tests carry both an
# `__init__.py` for unittest and a `conftest.py` for pytest, doing the same sys.path setup — but
# pytest is not installed on this machine, so `uv run pytest` fails to spawn and that path has never
# been runnable. Stdlib unittest also matches ADR 0008's own rationale for the harness it chose
# better than pytest does: "neither side gains a dependency it does not already have."
#
# The `-t` argument is load-bearing. Pointing it at the tests directory makes the modules top-level,
# so `__init__.py` never runs, the sys.path setup never happens, and all five modules fail to import
# with `No module named '_common'`. Pointing it at the PARENT makes `tests` a package and the init
# fires. A wrong `-t` here fails loudly, which is the good case — it is the discovery misses that
# stay quiet.
#
# A missing interpreter is REFUSED rather than skipped. A skipped suite still leaves a green
# summary, which is a false pass. Bash suites need only bash and jq.
#
# RUNTIME is roughly 105 seconds as of 2026-09-23, close enough to a 120-second default timeout to
# matter. A caller that backgrounds the command when its timeout expires gets no output and no exit
# status, which is indistinguishable from a wedged run — so pass an explicit timeout rather than
# relying on a default. The cost is concentrated rather than spread: run-test-runner.sh at ~29s and
# run-checks.sh at ~23s are nearly half the total between them, every other bash suite is under 8
# seconds, and the two Python packages together finish in under a second.

set -o pipefail

# `**` only recurses with globstar on, and without it this silently found the two top-level bash
# suites while missing skills/session-handoff/tests/ three levels down — the same kind of quiet
# discovery miss the name guard below exists to stop. Homebrew bash 5.x is what `env bash` finds
# here, so globstar is simply available.
shopt -s globstar nullglob

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO" || exit 1

LIST_ONLY=false
[ "${1:-}" = "--list" ] && LIST_ONLY=true

# --- Ignored paths are not this repo's suites --------------------------------
#
# Discovery globs the filesystem, so a vendored tree that ships its own tests gets picked up and its
# failures reported as ours. A plugin marketplace cloned under plugins/ is the live case: it carries
# a tests/ directory that is not even importable, and the runner reported a failing suite this repo
# does not own and cannot fix.
#
# THE PREDICATE IS `ignored`, NOT `untracked`, and the difference is the whole point. This repo's
# .gitignore re-includes whole subtrees — `!/scripts/**/*`, `!/hooks/**/*`, `!/test/**/*` — so a
# suite written moments ago and not yet staged is untracked, not ignored, and still runs. Keying on
# tracked would stop running every new suite the moment before it is added, which is the quiet
# discovery miss the name guard below exists to stop, reintroduced by the fix for a different one.
#
# WHAT IS PASSED OVER IS REPORTED, because in an allowlist .gitignore a path is ignored by the
# ABSENCE of a decision rather than by one. The catch-all `*` at the top means a new top-level
# directory — `lib/test/run-thing.sh` — is ignored because nobody has allowlisted it yet, not
# because anybody judged it foreign. Dropping that in silence is the failure this unit is Tier 1 to
# prevent. So the paths are named in the summary and under `--list`: vendored tests still do not
# run, and nothing vanishes without saying so.
#
# Outside a git repo nothing is ignored and every candidate stands. That is the case this script's
# own suite runs in: its fixtures are bare directory trees, so they exercise the fallback throughout.
# A path git refuses to answer for — one beyond a symlink, say — also stands, which is the safe
# direction: running something twice is visible, skipping it is not.
IN_GIT_REPO=false
git rev-parse --is-inside-work-tree &>/dev/null && IN_GIT_REPO=true

ignored_paths=()

# not_ours <path> — true when .gitignore excludes it, so discovery should pass over it.
not_ours() {
    [ "$IN_GIT_REPO" = true ] && git check-ignore --quiet "$1"
}

# --- Discover, and refuse a name that would have been skipped ----------------

suites=()
misnamed=()

for candidate in */test/*.sh **/test/*.sh; do
    [ -e "$candidate" ] || continue
    case " ${suites[*]} ${misnamed[*]} " in
        *" $candidate "*) continue ;;
    esac
    # Before the name check, so an ignored tree carrying an oddly-named file cannot refuse the run.
    if not_ours "$candidate"; then
        ignored_paths+=("$candidate")
        continue
    fi
    # A leading underscore is the "not a suite" marker — shared helpers meant to be sourced, not
    # run. Exempted rather than refused, and kept narrow on purpose: both real drift cases were
    # `<topic>-checks.sh` names, which still land in `misnamed` below. Nobody names a suite
    # `_harness.sh` by accident, so this reopens none of the skipping the guard exists to stop.
    if [[ "$(basename "$candidate")" == _* ]]; then
        continue
    elif [[ "$(basename "$candidate")" == run-*.sh ]]; then
        suites+=("$candidate")
    else
        misnamed+=("$candidate")
    fi
done

if [ "${#misnamed[@]}" -gt 0 ]; then
    echo "run-tests: these files sit in a test directory but are not named run-*.sh:" >&2
    for bad in "${misnamed[@]}"; do echo "  $bad" >&2; done
    echo "" >&2
    echo "A glob-based runner would skip them and still report green. Rename them to" >&2
    echo "run-<shape>.sh per ADR 0008, or move them out of test/ if they are not suites." >&2
    exit 2
fi

# Python suites live under a topic's own tests/ and run through stdlib unittest.
unittest_dirs=()
for candidate in */tests **/tests; do
    [ -d "$candidate" ] || continue
    case " ${unittest_dirs[*]} " in
        *" $candidate "*) continue ;;
    esac
    if not_ours "$candidate"; then
        ignored_paths+=("$candidate")
        continue
    fi
    unittest_dirs+=("$candidate")
done

if [ "$LIST_ONLY" = true ]; then
    printf 'bash suites:\n'
    for suite in "${suites[@]}"; do printf '  %s\n' "$suite"; done
    printf 'unittest packages:\n'
    if [ "${#unittest_dirs[@]}" -eq 0 ]; then printf '  (none)\n'; fi
    for dir in "${unittest_dirs[@]}"; do printf '  %s\n' "$dir"; done
    printf 'passed over as gitignored:\n'
    if [ "${#ignored_paths[@]}" -eq 0 ]; then printf '  (none)\n'; fi
    for path in "${ignored_paths[@]}"; do printf '  %s\n' "$path"; done
    exit 0
fi

if [ "${#unittest_dirs[@]}" -gt 0 ] && ! command -v python3 &>/dev/null; then
    echo "run-tests: python3 is required to run the Python suites and is not installed." >&2
    echo "Refusing rather than skipping them — a skipped suite still leaves a green" >&2
    echo "summary, which reads as a pass it never earned." >&2
    exit 1
fi

# --- Run ---------------------------------------------------------------------

failed=()
ran=0

for suite in "${suites[@]}"; do
    printf '\n=== %s ===\n' "$suite"
    if [ ! -x "$suite" ]; then
        echo "run-tests: $suite is not executable." >&2
        failed+=("$suite")
        continue
    fi
    # Not piped, so $? is the suite's own status rather than a filter's.
    "./$suite"
    status=$?
    ran=$((ran + 1))
    [ "$status" -ne 0 ] && failed+=("$suite")
done

for dir in "${unittest_dirs[@]}"; do
    printf '\n=== %s (unittest) ===\n' "$dir"
    # -t must be the package's PARENT so tests/__init__.py runs. See the header.
    python3 -m unittest discover --start-directory "$dir" --top-level-directory "$(dirname "$dir")"
    status=$?
    ran=$((ran + 1))
    [ "$status" -ne 0 ] && failed+=("$dir")
done

# --- Report ------------------------------------------------------------------

printf '\n'
if [ "${#ignored_paths[@]}" -gt 0 ]; then
    echo "run-tests: passed over as gitignored, not run:"
    for path in "${ignored_paths[@]}"; do printf '  %s\n' "$path"; done
    printf '\n'
fi

if [ "$ran" -eq 0 ]; then
    echo "run-tests: no suites found. That is a discovery failure, not a pass." >&2
    exit 1
fi

if [ "${#failed[@]}" -eq 0 ]; then
    printf 'run-tests: %d suites, all passed\n' "$ran"
    exit 0
fi

printf 'run-tests: %d of %d suites failed\n' "${#failed[@]}" "$ran"
for bad in "${failed[@]}"; do printf '  %s\n' "$bad"; done
exit 1
