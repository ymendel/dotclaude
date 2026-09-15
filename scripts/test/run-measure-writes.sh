#!/usr/bin/env bash
# Checks over measure-claude-dir-writes.sh. Run it after touching that script:
#
#   ./scripts/test/run-measure-writes.sh
#
# ADR 0008 places that script in Tier 2 — it derives figures that land in durable artifacts, and
# its verb matching and session exclusion both decide the result. Those are the two things asserted
# hardest here, because a miscount is silent: the script always prints a plausible number.
#
# Fixtures are synthesised transcript trees under a temp HOME. The script reads
# `$HOME/.claude/projects`, so pointing HOME at a fixture is the whole isolation mechanism — no real
# transcript is read and the counts are known in advance rather than compared against the machine.
#
# Every command in a fixture is invented. Using a real one from a transcript would tie an assertion
# to a client path, and this repo is public.
#
# No framework, no `set -e` (a failing case must report, not abort), non-zero exit at the end.

if ! command -v jq &>/dev/null; then
    echo "run-measure-writes: jq is required — the subject reads its input with jq and bails" >&2
    echo "without it, so every case would report a pass it never earned." >&2
    exit 1
fi

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBJECT="$(cd "$TEST_DIR/.." && pwd)/measure-claude-dir-writes.sh"

if [ ! -x "$SUBJECT" ]; then
    echo "run-measure-writes: $SUBJECT is missing or not executable." >&2
    exit 1
fi

WORK_DIR="$(mktemp -d)"
cleanup() { [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"; }
trap cleanup EXIT

pass=0
fail=0

report() {
    if [ "$1" = true ]; then
        pass=$((pass + 1))
        printf 'PASS  %s\n' "$2"
    else
        fail=$((fail + 1))
        printf 'FAIL  %s\n' "$2"
        [ -n "$3" ] && printf '      %s\n' "$3"
    fi
}

# fresh — discard any previous fixture and start an empty transcript tree.
fresh() {
    FAKE_HOME="$WORK_DIR/home"
    rm -rf "$FAKE_HOME"
    mkdir -p "$FAKE_HOME/.claude/projects"
}

# record <project> <session> <command> — append one Bash tool_use line to that session.
record() {
    local dir="$FAKE_HOME/.claude/projects/$1"
    mkdir -p "$dir"
    jq -nc --arg cmd "$3" \
        '{message: {content: [{type: "tool_use", name: "Bash", input: {command: $cmd}}]}}' \
        >> "$dir/$2.jsonl"
}

# record_raw <project> <session> <line> — append a line verbatim, for malformed input.
record_raw() {
    local dir="$FAKE_HOME/.claude/projects/$1"
    mkdir -p "$dir"
    printf '%s\n' "$3" >> "$dir/$2.jsonl"
}

# record_other_tool <project> <session> <command> — a tool_use that is not Bash.
record_other_tool() {
    local dir="$FAKE_HOME/.claude/projects/$1"
    mkdir -p "$dir"
    jq -nc --arg cmd "$3" \
        '{message: {content: [{type: "tool_use", name: "Read", input: {command: $cmd}}]}}' \
        >> "$dir/$2.jsonl"
}

# run [args...] — invoke the subject against the fixture HOME, output in $OUT, status in $STATUS.
run() {
    OUT="$WORK_DIR/out.txt"
    HOME="$FAKE_HOME" bash "$SUBJECT" "$@" > "$OUT" 2>&1
    STATUS=$?
}

# value_of <label> — the trailing number on the line carrying that label.
value_of() {
    grep -F "$1" "$OUT" | awk '{print $NF}'
}

# expect <label> <wanted> <case name>
expect() {
    local got
    got=$(value_of "$1")
    if [ "$got" = "$2" ]; then
        report true "$3"
    else
        report false "$3" "expected $2 for '$1', got '${got:-<no such line>}'"
    fi
}

# --- Verb matching, the first thing the tier row names ----------------------

fresh
record shipping-tracker sess-a 'rm .claude/scratch/derive-rates.py'
record shipping-tracker sess-a 'rtk read .claude/handoffs/2026-01-02-resume.md'
record shipping-tracker sess-a 'rtk git status --short'
run
expect 'Bash calls in them' 3 'every Bash call is counted'
expect 'mentioning a .claude/ path' 2 'a read of .claude counts as mentioning'
expect 'of those, writing to one' 1 'only the write verb counts as a write'

# A redirect is a write even with no verb in front of it — the case a verb list alone would miss.
fresh
record shipping-tracker sess-a 'echo checkpoint > .claude/scratch/state.txt'
run
expect 'of those, writing to one' 1 'a redirect into .claude counts without a verb'

# A verb appearing INSIDE a word is not a verb. "confirm" contains "rm", and the matcher requires a
# separator before it and whitespace after, so this must not count.
fresh
record shipping-tracker sess-a 'rtk confirm .claude/scratch/pending.md'
run
expect 'mentioning a .claude/ path' 1 'a substring verb still counts as mentioning'
expect 'of those, writing to one' 0 'a verb inside another word is not a write'

# --- Session exclusion, the second thing the tier row names -----------------

fresh
record shipping-tracker keep-me 'rm .claude/scratch/one.txt'
record shipping-tracker drop-me 'rm .claude/scratch/two.txt'
run
expect 'of those, writing to one' 2 'both sessions counted with no exclusion'
run --exclude-session drop-me
expect 'of those, writing to one' 1 'the excluded session is not counted'
expect 'Sessions scanned' 1 'the excluded session is not scanned'

# --- The per-project table counts writes, not sessions ----------------------
#
# Regression guard. The table appended one line per SESSION while reading as a write count, so its
# column summed to the session total instead. Three writes in one session is the shape that catches
# it: a per-session table would report 1.

fresh
record shipping-tracker sess-a 'rm .claude/scratch/a.txt'
record shipping-tracker sess-a 'rm .claude/scratch/b.txt'
record shipping-tracker sess-a 'rm .claude/scratch/c.txt'
run
project_count=$(grep -A2 'Writes per project' "$OUT" | grep 'shipping-tracker' | awk '{print $1}')
if [ "$project_count" = 3 ]; then
    report true 'the per-project table counts writes, not sessions'
else
    report false 'the per-project table counts writes, not sessions' \
        "expected 3 for the project, got '${project_count:-<absent>}'"
fi
expect 'sessions with any such write' 1 'three writes in one session is one session'

# --- The distinct-strings line, which is what the script exists to decide ---

fresh
record shipping-tracker sess-a 'rm .claude/scratch/dup.txt'
record shipping-tracker sess-a 'rm .claude/scratch/dup.txt'
record shipping-tracker sess-a 'rm .claude/scratch/unique.txt'
run
distinct=$(grep -F 'Distinct command strings' "$OUT" | awk '{print $4}')
if [ "$distinct" = 2 ]; then
    report true 'repeated commands collapse in the distinct count'
else
    report false 'repeated commands collapse in the distinct count' \
        "expected 2 distinct, got '${distinct:-<absent>}'"
fi
expect 'Strings appearing more than once' 1 'the repeated string is reported as repeated'

fresh
record shipping-tracker sess-a 'rm .claude/scratch/a.txt && rtk git status'
record shipping-tracker sess-a 'rm .claude/scratch/b.txt; rtk ls .claude/scratch/'
record shipping-tracker sess-a 'rm "$HOME/.claude/scratch/c.txt"'
run
expect 'Compound (pipe, && , ; or redirect)' 2 'compound counts a && chain and a ; chain'
expect 'Carrying a $ expansion' 1 'a single-command expansion is counted but is not compound'

# --- Input the script must survive rather than crash on --------------------

fresh
record_raw shipping-tracker sess-a 'this is not json'
record shipping-tracker sess-a 'rm .claude/scratch/after-garbage.txt'
run
expect 'of those, writing to one' 1 'a malformed line is skipped, later lines still counted'
[ "$STATUS" -eq 0 ] \
    && report true 'malformed input does not fail the run' \
    || report false 'malformed input does not fail the run' "exit $STATUS"

fresh
record_other_tool shipping-tracker sess-a 'rm .claude/scratch/not-bash.txt'
run
expect 'Bash calls in them' 0 'a non-Bash tool_use is ignored'

fresh
run
[ "$STATUS" -eq 0 ] \
    && report true 'an empty transcript tree exits zero' \
    || report false 'an empty transcript tree exits zero' "exit $STATUS"

# --- Contract on the arguments and the environment -------------------------

fresh
run --not-a-real-flag
[ "$STATUS" -eq 2 ] \
    && report true 'an unknown argument exits 2' \
    || report false 'an unknown argument exits 2' "expected 2, got $STATUS"

FAKE_HOME="$WORK_DIR/no-such-home"
rm -rf "$FAKE_HOME"
mkdir -p "$FAKE_HOME"
run
[ "$STATUS" -eq 1 ] \
    && report true 'a missing transcript directory exits 1' \
    || report false 'a missing transcript directory exits 1' "expected 1, got $STATUS"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
