#!/usr/bin/env bash
# Checks over usage-report.sh, the skill and agent invocation report:
#
#   ./scripts/test/run-usage-report.sh
#
# ADR 0008 puts it in Tier 2 as a script that "reads and summarises, no writes" — which is now only
# mostly true: the snapshot path appends to a history TSV, and that file is the durable artifact the
# trend is read from. A wrong row there is permanent and invisible, because nobody re-derives a
# history file.
#
# WHAT MAKES IT WORTH TESTING is that the counts decide things. This report is what a pruning pass
# reads to decide a skill is unused, and "unused" here means "no match in the scanned window" — a
# scan that silently matched nothing produces the same clean zeroes as a skill nobody invoked. The
# cases below pin the difference: every zero is paired with a non-zero from the same fixture.
#
# ISOLATION IS ENTIRELY BY ENVIRONMENT. REPO, PROJECTS_DIR, HISTORY_FILE and WINDOW_DAYS are all
# overridable, so no case touches the real transcript store or the real history file, and the
# inventory is whatever the fixture repo declares rather than this repo's actual skills.
#
# The window is enforced by file mtime, so the out-of-window cases set mtimes with `touch -t`
# against a fixed old date rather than trusting creation order.
#
# No framework, no `set -e` (a failing case must report, not abort), non-zero exit at the end.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBJECT="$(cd "$TEST_DIR/.." && pwd)/usage-report.sh"

if [ ! -x "$SUBJECT" ]; then
    echo "run-usage-report: $SUBJECT is missing or not executable." >&2
    exit 1
fi

. "$(cd "$TEST_DIR/../.." && pwd)/test/_harness.sh"

WORK_DIR="$(mktemp -d)"
cleanup() { [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"; }
trap cleanup EXIT

# fresh — an empty fixture repo (skills/ and agents/) plus an empty transcript store.
fresh() {
    FIX="$WORK_DIR/repo"
    PROJECTS="$WORK_DIR/projects"
    HISTORY="$WORK_DIR/history.tsv"
    rm -rf "$FIX" "$PROJECTS" "$HISTORY"
    mkdir -p "$FIX/skills" "$FIX/agents" "$PROJECTS"
}

# skill <name> / agent <name> — declare inventory.
skill() { mkdir -p "$FIX/skills/$1"; }
agent() { printf 'agent stub\n' > "$FIX/agents/$1.md"; }

# transcript <name> <line>... — a .jsonl in the store, in window by default.
transcript() {
    local name="$1"; shift
    printf '%s\n' "$@" > "$PROJECTS/$name.jsonl"
    TRANSCRIPT="$PROJECTS/$name.jsonl"
}

# age_out — push the last-written transcript outside any plausible window.
age_out() { touch -t 202001010000 "$TRANSCRIPT"; }

# run [args...] — invoke the subject against the fixtures.
run() {
    OUT=$(REPO="$FIX" PROJECTS_DIR="$PROJECTS" HISTORY_FILE="$HISTORY" \
          WINDOW_DAYS="${WINDOW:-30}" "$SUBJECT" "$@" 2>&1)
    STATUS=$?
}

# count_for <name> — the number printed beside an inventory row.
count_for() {
    printf '%s' "$OUT" | grep -E "^  $1 " | while read -r _ cnt; do printf '%s' "$cnt"; done
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

# --- Counting, paired so a zero is never the only evidence ------------------

fresh
skill adr
skill orientation-doc
agent debugger
transcript session-a '{"skill":"adr"}' '{"skill":"adr"}' '{"subagent_type":"debugger"}'
run --no-snapshot
expect_eq "$(count_for adr)" 2 'a skill invoked twice counts twice'
expect_eq "$(count_for orientation-doc)" 0 'a skill never invoked counts zero'
expect_eq "$(count_for debugger)" 1 'an agent invocation is counted from subagent_type'
expect_eq "$STATUS" 0 'a report run exits 0'

# The unused list is what a pruning pass acts on, so it has to name the right side.
saw 'unused: orientation-doc' 'the uninvoked skill is named as unused'
saw '1 used, 1 unused' 'the used and unused tallies are reported'

# Counts come from the transcript text, not from the inventory — a skill declared but absent from
# every transcript and a skill invoked once must not look alike.
fresh
skill adr
transcript session-a '{"skill":"adr"}'
run --no-snapshot
expect_eq "$(count_for adr)" 1 'one invocation counts once'

fresh
skill adr
transcript session-a '{"nothing":"here"}'
run --no-snapshot
expect_eq "$(count_for adr)" 0 'a transcript with no invocations leaves the count at zero'

# Counts aggregate across transcripts rather than reporting the last one.
fresh
skill adr
transcript session-a '{"skill":"adr"}'
transcript session-b '{"skill":"adr"}' '{"skill":"adr"}'
run --no-snapshot
expect_eq "$(count_for adr)" 3 'counts are summed across transcripts'

# --- The window, which is what makes two runs comparable --------------------

fresh
skill adr
transcript old-session '{"skill":"adr"}'
age_out
transcript recent-session '{"skill":"adr"}'
run --no-snapshot
expect_eq "$(count_for adr)" 1 'an out-of-window transcript is not counted'
saw 'Transcripts in window: 1 (of 2 present)' 'the report distinguishes in-window from present'

# A skill whose only invocations aged out reads as unused — correct, and the reason the header warns
# against comparing raw counts across runs.
fresh
skill adr
transcript old-session '{"skill":"adr"}'
age_out
run --no-snapshot
expect_eq "$(count_for adr)" 0 'a skill whose invocations all aged out reads as unused'
saw 'unused: adr' 'the aged-out skill is listed as unused'

# --- Inventory and what falls outside it ------------------------------------

# A skill invoked but not in the inventory is a built-in or a removed one. Folding it into the
# report would inflate the used count with things this repo does not own.
fresh
skill adr
transcript session-a '{"skill":"adr"}' '{"skill":"some-builtin"}'
run --no-snapshot
saw 'invoked but not in inventory' 'an invoked non-inventory skill is reported separately'
saw 'some-builtin (1)' 'the external skill is named with its count'
saw '1 used, 0 unused' 'the external skill does not inflate the inventory tally'

fresh
skill adr
transcript session-a '{"skill":"adr"}'
run --no-snapshot
did_not_see 'invoked but not in inventory' 'the external section is omitted when there is nothing in it'

# agents/README.md is documentation, not an agent, and counting it would put a permanent
# never-invoked row in the report and the history.
fresh
agent debugger
printf 'not an agent\n' > "$FIX/agents/README.md"
transcript session-a '{"subagent_type":"debugger"}'
run --no-snapshot
did_not_see 'README' 'agents/README.md is not treated as an agent'
saw 'AGENTS (1)' 'the agent inventory counts only real agents'

# --- The snapshot, which is the durable artifact ----------------------------

fresh
skill adr
skill orientation-doc
agent debugger
transcript session-a '{"skill":"adr"}'
run
if [ -f "$HISTORY" ]; then
    report true 'a snapshot run creates the history file'
else
    report false 'a snapshot run creates the history file' 'no history file'
fi
expect_eq "$(head -1 "$HISTORY")" \
    "$(printf 'date\tkind\tname\tinvocations\twindow_start\twindow_end')" \
    'the history file opens with a header row'
expect_eq "$(grep -c 'skill' "$HISTORY")" 2 'every inventory skill gets a row, used or not'
expect_eq "$(grep -c '	agent	' "$HISTORY")" 1 'every inventory agent gets a row'
saw 'Snapshot appended' 'the snapshot run says it appended'

# Appending must not rewrite the header — a second header mid-file would break any reader.
run
expect_eq "$(grep -c '^date	kind' "$HISTORY")" 1 'a second run does not write a second header'
expect_eq "$(grep -c '	skill	adr	' "$HISTORY")" 2 'a second run appends rather than replacing'

fresh
skill adr
transcript session-a '{"skill":"adr"}'
run --no-snapshot
if [ -f "$HISTORY" ]; then
    report false '--no-snapshot writes nothing' 'the history file was created'
else
    report true '--no-snapshot writes nothing'
fi
did_not_see 'Snapshot appended' '--no-snapshot does not claim to have appended'

# --- Arguments and missing paths --------------------------------------------

fresh
run --help
expect_eq "$STATUS" 0 '--help exits 0'
saw 'Usage: usage-report.sh' '--help prints usage'

fresh
run --not-a-flag
expect_eq "$STATUS" 2 'an unknown option exits 2'

fresh
run stray-argument
expect_eq "$STATUS" 2 'an unexpected positional argument exits 2'

fresh
rm -rf "$FIX/skills"
run --no-snapshot
expect_eq "$STATUS" 2 'a missing skills directory exits 2'

fresh
rm -rf "$PROJECTS"
run --no-snapshot
expect_eq "$STATUS" 2 'a missing transcripts directory exits 2'

# WINDOW_DAYS feeds arithmetic and a label, so a non-numeric value has to be refused rather than
# silently producing a cutoff of zero and a window covering everything.
fresh
skill adr
WINDOW=notanumber run --no-snapshot
expect_eq "$STATUS" 2 'a non-numeric WINDOW_DAYS exits 2'

fresh
skill adr
WINDOW=0 run --no-snapshot
expect_eq "$STATUS" 2 'a zero WINDOW_DAYS exits 2'

fresh
skill adr
transcript session-a '{"skill":"adr"}'
WINDOW=7 run --no-snapshot
saw 'last 7d' 'the window label reflects WINDOW_DAYS'

summary || exit 1
