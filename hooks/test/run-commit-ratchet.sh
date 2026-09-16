#!/usr/bin/env bash
# Checks over commit-ratchet-guard.sh, the PreToolUse gate for ADR 0008's ratchet. Run it after
# touching that hook:
#
#   ./hooks/test/run-commit-ratchet.sh
#
# A fourth harness. The other three synthesise a payload on stdin and read a decision; this hook
# also reads `git diff --cached` from the working directory, so a case needs a real index to assert
# against. Each case therefore builds a throwaway git repo, stages a chosen set, and runs the hook
# with that repo as its working directory. Nothing touches this repo's index.
#
# The subject's contract is narrow and worth stating, because most of these cases assert the
# NEGATIVE half of it: exit 2 blocks, exit 0 permits, and there is no third outcome. A gate that
# blocks too much gets disabled, so the permit cases carry as much weight as the block cases.
#
# No framework, no `set -e` (a failing case must report, not abort), non-zero exit at the end.

if ! command -v jq &>/dev/null; then
    echo "run-commit-ratchet: jq is required. The hook fails open without it, so every block" >&2
    echo "case would report a pass it never earned." >&2
    exit 1
fi

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$(cd "$TEST_DIR/.." && pwd)/commit-ratchet-guard.sh"

if [ ! -x "$HOOK" ]; then
    echo "run-commit-ratchet: $HOOK is missing or not executable." >&2
    exit 1
fi

WORK_DIR="$(mktemp -d)"
cleanup() { [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"; }
trap cleanup EXIT

. "$(cd "$TEST_DIR/../.." && pwd)/test/_harness.sh"

# fresh — a new empty git repo to stage into.
fresh() {
    FIXTURE="$WORK_DIR/repo-$RANDOM_COUNTER"
    RANDOM_COUNTER=$((RANDOM_COUNTER + 1))
    mkdir -p "$FIXTURE"
    git -C "$FIXTURE" init --quiet
    git -C "$FIXTURE" config user.email check@example.com
    git -C "$FIXTURE" config user.name Check
}
RANDOM_COUNTER=0

# stage <path> [more...] — create each path with filler content and add it to the index.
stage() {
    for path in "$@"; do
        mkdir -p "$FIXTURE/$(dirname "$path")"
        printf '# placeholder\n' > "$FIXTURE/$path"
        git -C "$FIXTURE" add "$path"
    done
}

# run [command] — feed the hook a PreToolUse payload from inside the fixture repo.
run() {
    local cmd="${1:-rtk git commit -F .claude/scratch/message.txt}"
    OUT="$WORK_DIR/stderr.txt"
    jq -nc --arg cmd "$cmd" \
        '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $cmd}}' \
        | (cd "$FIXTURE" && bash "$HOOK") 2> "$OUT" > /dev/null
    STATUS=$?
}

blocks() {
    if [ "$STATUS" -eq 2 ]; then
        report true "$1"
    else
        report false "$1" "expected exit 2, got $STATUS"
    fi
}

permits() {
    if [ "$STATUS" -eq 0 ]; then
        report true "$1"
    else
        report false "$1" "expected exit 0, got $STATUS; stderr: $(cat "$OUT")"
    fi
}

says() {
    if grep -qF "$1" "$OUT"; then
        report true "$2"
    else
        report false "$2" "stderr did not mention '$1'"
    fi
}

# --- The ratchet itself -----------------------------------------------------

fresh
stage hooks/claude-dir-write-allow.sh
run
blocks 'a tiered hook staged without its suite is blocked'
says 'hooks/test/run-permission-request.sh' 'the block names the suite that would clear it'

fresh
stage hooks/claude-dir-write-allow.sh hooks/test/run-permission-request.sh
run
permits 'a tiered hook staged with its suite is permitted'

# Several units share one suite, so staging that suite clears all of them at once.
fresh
stage hooks/reflexive-cd-guard.sh hooks/shell-machinery-guard.sh hooks/test/run-checks.sh
run
permits 'two units sharing a suite are cleared by staging it once'

# A suite named in the mapping need not exist yet. Modifying a unit whose suite has never been
# written is exactly when the ratchet should fire.
fresh
stage hooks/context-usage-notice.sh
run
blocks 'a unit whose suite does not exist yet is still blocked'
says 'hooks/test/run-stop.sh' 'the block names the suite that has to be written'

# A Python unit owes a directory rather than a file, so any file beneath it satisfies the obligation.
fresh
stage scripts/session-meta-report.py scripts/tests/test_session_meta.py
run
permits 'a python unit is cleared by any file under its tests directory'

# --- Tier 3 and everything the gate must leave alone ------------------------

fresh
stage hooks/notify-config-update.sh
run
permits 'an exempt Tier 3 hook needs no suite'

fresh
stage hooks/rtk-rewrite.sh
run
permits 'vendored code is exempt'

fresh
stage rules/honesty.md docs/adr/0009-something.md README.md
run
permits 'paths outside the watched directories are ignored'

fresh
stage hooks/README.md
run
permits 'a non-script file under a watched directory is ignored'

fresh
stage hooks/test/run-checks.sh
run
permits 'a suite staged on its own is never subject to the ratchet'

fresh
run
permits 'an empty index is permitted'

# The timing limitation, asserted rather than only described. PreToolUse fires before the command
# runs, so a compound `git add X && git commit` arrives with X not yet staged and the gate cannot
# see it. This case pins that as known behaviour: it is why development-workflow.md requires staging
# in a separate tool call, and if it ever starts failing the gate has become able to see further
# than it could, which is worth noticing rather than silently benefiting from.
fresh
run 'rtk git add hooks/claude-dir-write-allow.sh && rtk git commit -m combined'
permits 'a compound stage-and-commit is invisible, because nothing is staged yet'

# --- The untiered case, which is the half the three-for-three miss earned ----

fresh
stage hooks/brand-new-guard.sh
run
blocks 'an untiered script under a watched directory is blocked'
says 'not tiered and not exempt' 'the block says the file needs classifying'
says 'TIERED or EXEMPT' 'the block names where to record the decision'

# --- The shared test harness, which sits outside the watched directories ----
#
# test/ is not in WATCHED, so the harness is reached only by its TIERED row. Without that row it
# would be neither tiered nor blockable — the one unit able to turn every suite's tally silent
# while landing unexamined. These two cases are what hold the row in place.

fresh
stage test/_harness.sh
run
blocks 'the shared harness is tiered despite living outside a watched directory'
says 'test/run-harness.sh' 'the block names the suite the harness owes'

fresh
stage test/_harness.sh
stage test/run-harness.sh
run
permits 'staging the harness with its own suite satisfies the ratchet'

fresh
stage scripts/brand-new-report.py
run
blocks 'an untiered python script under scripts/ is blocked'

# --- Command matching ------------------------------------------------------

fresh
stage hooks/claude-dir-write-allow.sh
run 'rtk git status --short'
permits 'a command that is not a commit is ignored'

fresh
stage hooks/claude-dir-write-allow.sh
run 'git commit -m "bare git, not rtk-prefixed"'
blocks 'a bare git commit is gated as well as an rtk-prefixed one'

# --- Payloads the hook must survive ----------------------------------------

fresh
stage hooks/claude-dir-write-allow.sh
OUT="$WORK_DIR/stderr.txt"
printf 'this is not json' | (cd "$FIXTURE" && bash "$HOOK") 2> "$OUT" > /dev/null
STATUS=$?
permits 'malformed input fails open rather than blocking every commit'

OUT="$WORK_DIR/stderr.txt"
printf '' | (cd "$FIXTURE" && bash "$HOOK") 2> "$OUT" > /dev/null
STATUS=$?
permits 'empty input fails open'

# --- The standing invariant -------------------------------------------------
#
# Exit 2 is the only blocking mechanism that beats an allow rule, and `Bash(rtk git:*)` is
# allow-listed. An exit 1 here would read as a hook error and let the commit through.

fresh
stage hooks/brand-new-guard.sh
run
if [ "$STATUS" -eq 0 ] || [ "$STATUS" -eq 2 ]; then
    report true 'the hook exits only 0 or 2, never a status an allow rule would beat'
else
    report false 'the hook exits only 0 or 2, never a status an allow rule would beat' \
        "got $STATUS"
fi

summary || exit 1
