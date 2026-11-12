#!/usr/bin/env bash
# Checks over reminders-notice.sh, the SessionStart hook that surfaces due reminders:
#
#   ./hooks/test/run-session-start.sh
#
# Tier 1 under ADR 0008: it fires automatically and is silent when nothing is due. So, as in
# run-stop.sh, each quiet case sits beside one proving the same fixture speaks when it should.
#
# SessionStart-shaped payload — a `cwd` and no `tool_input` — so it gets its own suite.
#
# Isolation: REMINDERS_FILE points at a fixture, the payload's cwd is a temp directory (a git repo
# where the case needs one), and REMINDERS_TODAY pins the date so due/not-due is known in advance.
#
# No framework, no `set -e` (a failing case must report, not abort), non-zero exit at the end.

if ! command -v jq &>/dev/null; then
    echo "run-session-start: jq is required — the subject exits 0 without it, so every case" >&2
    echo "would report a pass it never earned." >&2
    exit 1
fi

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBJECT="$(cd "$TEST_DIR/.." && pwd)/reminders-notice.sh"

if [ ! -x "$SUBJECT" ]; then
    echo "run-session-start: $SUBJECT is missing or not executable." >&2
    exit 1
fi

. "$(cd "$TEST_DIR/../.." && pwd)/test/_harness.sh"

WORK_DIR="$(mktemp -d)"
cleanup() { [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"; }
trap cleanup EXIT

TODAY="2026-11-12"

# fresh — a new central file location and a project directory that is a git repo named shipping-tracker.
fresh() {
    rm -rf "$WORK_DIR/case"
    mkdir -p "$WORK_DIR/case/shipping-tracker/.claude"
    git -C "$WORK_DIR/case/shipping-tracker" init --quiet
    CENTRAL="$WORK_DIR/case/reminders.json"
    PROJECT="$WORK_DIR/case/shipping-tracker"
}

# central <json> / local_file <json> — write a reminders file verbatim.
central() { printf '%s' "$1" > "$CENTRAL"; }
local_file() { printf '%s' "$1" > "$PROJECT/.claude/reminders.json"; }

# run [cwd] — feed a SessionStart payload. Output in $OUT, the notice text in $TEXT.
run() {
    OUT=$(jq -n --arg c "${1-$PROJECT}" '{cwd: $c, hook_event_name: "SessionStart"}' \
        | REMINDERS_FILE="$CENTRAL" REMINDERS_TODAY="$TODAY" "$SUBJECT" 2>&1)
    TEXT=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
}

spoke() {
    if [ -n "$OUT" ]; then report true "$1"; else report false "$1" 'expected a notice, got no output'; fi
}

silent() {
    if [ -z "$OUT" ]; then report true "$1"; else report false "$1" "expected silence, got: $OUT"; fi
}

# mentions <needle> <label> / omits <needle> <label> — check the notice text.
mentions() {
    case "$TEXT" in
        *"$1"*) report true "$2" ;;
        *) report false "$2" "notice was: ${TEXT:-<empty>}" ;;
    esac
}

omits() {
    case "$TEXT" in
        *"$1"*) report false "$2" "notice was: $TEXT" ;;
        *) report true "$2" ;;
    esac
}

# --- Due versus not due -----------------------------------------------------

fresh
central '{"reminders": [{"due": "2026-11-13", "scope": "global", "what": "Renew the domain"}]}'
run
silent 'a reminder due tomorrow is silent'

fresh
central '{"reminders": [{"due": "2026-11-12", "scope": "global", "what": "Renew the domain"}]}'
run
spoke 'a reminder due today speaks'
mentions 'Renew the domain' 'the notice names the reminder'
mentions 'due 2026-11-12' 'the notice gives the due date'

fresh
central '{"reminders": [{"due": "2026-10-01", "scope": "global", "what": "Renew the domain"}]}'
run
spoke 'an overdue reminder keeps speaking'

fresh
central '{"reminders": [{"due": "2026-11-01", "scope": "global", "what": "Renew the domain", "see": "docs/domains.md"}]}'
run
mentions '(see docs/domains.md)' 'a see pointer is carried into the notice'

event=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.hookEventName // empty' 2>/dev/null)
expect_eq "$event" 'SessionStart' 'the output is JSON naming the SessionStart event'

# --- Scope ------------------------------------------------------------------

fresh
central '{"reminders": [{"due": "2026-11-01", "scope": "invoice-service", "what": "Rotate the key"}]}'
run
silent 'a reminder scoped to another repo is silent'

fresh
central '{"reminders": [{"due": "2026-11-01", "scope": "shipping-tracker", "what": "Rotate the key"}]}'
run
spoke 'a reminder scoped to this repo speaks'

# The scope is the git toplevel's name, so a session started in a subdirectory still matches.
mkdir -p "$PROJECT/app/models"
run "$PROJECT/app/models"
spoke 'a session in a subdirectory matches its repo scope'

# Outside a git repo, the directory's own name is the scope.
fresh
mkdir -p "$WORK_DIR/case/loose/scratch-area"
central '{"reminders": [{"due": "2026-11-01", "scope": "scratch-area", "what": "Clear the scratch area"}]}'
run "$WORK_DIR/case/loose/scratch-area"
spoke 'outside a repo, the directory name is the scope'

fresh
central '{"reminders": [
  {"due": "2026-11-01", "scope": "invoice-service", "what": "Rotate the key"},
  {"due": "2026-11-01", "scope": "global", "what": "Renew the domain"}]}'
run
mentions 'Renew the domain' 'a global reminder surfaces beside an out-of-scope one'
omits 'Rotate the key' 'the out-of-scope reminder stays out of the notice'

# --- The repo's own file ----------------------------------------------------

fresh
local_file '{"reminders": [{"due": "2026-11-01", "what": "Drop the legacy importer"}]}'
run
spoke 'a due reminder in the repo file speaks with no central file present'
mentions 'Drop the legacy importer' 'the repo file needs no scope'

fresh
central '{"reminders": [{"due": "2026-11-01", "scope": "global", "what": "Renew the domain"}]}'
local_file '{"reminders": [{"due": "2026-11-01", "what": "Drop the legacy importer"}]}'
run
mentions 'Renew the domain' 'both files are read: central'
mentions 'Drop the legacy importer' 'both files are read: repo'

# --- Nothing to read --------------------------------------------------------

fresh
run
silent 'no reminders files at all is silent'

fresh
central '{"reminders": []}'
run
silent 'an empty reminders array is silent'

# --- What cannot be read is reported, not skipped ---------------------------

fresh
central '{"reminders": [ not json'
run
spoke 'a malformed central file is reported'
mentions 'could not read' 'the notice says the file could not be read'

fresh
central '{"something_else": []}'
run
spoke 'a file without a reminders array is reported'

fresh
central '{"reminders": [{"due": "next week", "scope": "global", "what": "Renew the domain"}]}'
run
mentions 'unreadable entry' 'an entry with a non-date due is reported'

fresh
central '{"reminders": [{"due": "2026-11-01", "what": "Renew the domain"}]}'
run
mentions 'unreadable entry' 'a central entry with no scope is reported'

fresh
central '{"reminders": [
  {"due": "soon", "scope": "global", "what": "Broken one"},
  {"due": "2026-11-01", "scope": "global", "what": "Renew the domain"}]}'
run
mentions 'Renew the domain' 'one unreadable entry does not hide a good one beside it'

# --- Payload shapes ---------------------------------------------------------

fresh
central '{"reminders": [{"due": "2026-11-01", "scope": "global", "what": "Renew the domain"}]}'
OUT=$(printf '' | REMINDERS_FILE="$CENTRAL" REMINDERS_TODAY="$TODAY" "$SUBJECT" 2>&1)
TEXT=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
mentions 'Renew the domain' 'an empty payload still surfaces global reminders'

summary || exit 1
