#!/usr/bin/env bash
# Checks over broad-grant-notice.sh, the PostToolUse hook that flags a newly written broad allow entry:
#
#   ./hooks/test/run-broad-grant-notice.sh
#
# ADR 0008 puts it in Tier 1: it fires on every Bash call and says nothing when it works, so a hook
# that has stopped noticing looks exactly like one with nothing to notice. Both directions matter —
# a missed broad grant is the failure it exists to prevent, and a notice for an entry that was
# already there, or for a narrow one, teaches the reader to skim past it.
#
# HOME and CLAUDE_PROJECT_DIR point at a temp tree, so the real settings and snapshots are never
# read or written. Each case writes the settings files it needs, runs the hook, and asserts on
# stdout, which is empty unless a notice is due.
#
# No framework, no `set -e` (a failing case must report, not abort), non-zero exit at the end.

if ! command -v jq &>/dev/null; then
    echo "run-broad-grant-notice: jq is required — the subject exits 0 without it, so every case" >&2
    echo "would report a pass it never earned." >&2
    exit 1
fi

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBJECT="$(cd "$TEST_DIR/.." && pwd)/broad-grant-notice.sh"

if [ ! -x "$SUBJECT" ]; then
    echo "run-broad-grant-notice: $SUBJECT is missing or not executable." >&2
    exit 1
fi

. "$(cd "$TEST_DIR/../.." && pwd)/test/_harness.sh"

WORK_DIR="$(mktemp -d)"
cleanup() { [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"; }
trap cleanup EXIT

FAKE_HOME="$WORK_DIR/home"
PROJECT="$WORK_DIR/project"
USER_FILE="$FAKE_HOME/.claude/settings.json"
LOCAL_FILE="$PROJECT/.claude/settings.local.json"

# fresh — start a case with no settings files and no snapshots.
fresh() {
    rm -rf "$FAKE_HOME" "$PROJECT"
    mkdir -p "$FAKE_HOME/.claude" "$PROJECT/.claude"
}

# allow <file> <entry>... — write a settings file whose allow list is exactly the entries given.
allow() {
    local file=$1
    shift
    jq -n '{permissions: {allow: $ARGS.positional}}' --args "$@" > "$file"
}

# run_hook — one PostToolUse call. Output in OUT, status in STATUS.
run_hook() {
    OUT=$(jq -n --arg cwd "$PROJECT" '{tool_name: "Bash", tool_input: {command: "ls"}, cwd: $cwd}' \
        | HOME="$FAKE_HOME" CLAUDE_PROJECT_DIR="$PROJECT" "$SUBJECT" 2>"$WORK_DIR/err.txt")
    STATUS=$?
    CONTEXT=$(jq -r '.hookSpecificOutput.additionalContext // empty' <<<"$OUT" 2>/dev/null)
}

# flags <entry> <label> — the last run's notice names the entry.
flags() {
    case "$CONTEXT" in
        *"\`$1\`"*) report true "$2" ;;
        *) report false "$2" "notice did not name $1: '${CONTEXT:-<empty>}'" ;;
    esac
}

# silent <label> — the last run printed nothing.
silent() { expect_eq "$OUT" "" "$1"; }

# seed_then_add <entry> — seed the local file with one harmless entry, then add the entry under test.
seed_then_add() {
    fresh
    allow "$LOCAL_FILE" "Bash(git grep:*)"
    run_hook
    allow "$LOCAL_FILE" "Bash(git grep:*)" "$1"
    run_hook
}

# --- Seeding --------------------------------------------------------------------

# The first sight of a file must not report what was already in it, or installing the hook would
# flag every broad entry in every project at once.
fresh
allow "$LOCAL_FILE" "Bash(git *)" "Bash(python3:*)"
run_hook
silent 'a file seen for the first time is seeded without a notice'
if [ -n "$(ls "$FAKE_HOME/.claude/.grant-snapshots" 2>/dev/null)" ]; then
    report true 'seeding writes a snapshot'
else
    report false 'seeding writes a snapshot' 'no snapshot file was created'
fi

run_hook
silent 'an unchanged file produces no notice on the next call'

# --- What counts as broad --------------------------------------------------------

seed_then_add "Bash(git *)"
flags "Bash(git *)" 'a single command with a trailing " *" is flagged'
expect_eq "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$OUT")" "PostToolUse" 'the notice is a PostToolUse additionalContext'

seed_then_add "Bash(python3:*)"
flags "Bash(python3:*)" 'the ":*" spelling is flagged the same as " *"'

seed_then_add "Bash(bin/rails*)"
flags "Bash(bin/rails*)" 'a trailing wildcard with no space is flagged'

seed_then_add "Bash(python3 -c ' *)"
flags "Bash(python3 -c ' *)" 'an interpreter with an inline-code wildcard is flagged'

seed_then_add "Bash(rtk bundle *)"
flags "Bash(rtk bundle *)" 'a leading rtk is looked through'

seed_then_add "Bash(rtk proxy:*)"
flags "Bash(rtk proxy:*)" 'rtk proxy, which runs anything, is flagged'

seed_then_add "Bash(bundle exec *)"
flags "Bash(bundle exec *)" 'a command runner followed by a wildcard is flagged'

seed_then_add "Bash"
flags "Bash" 'the tool-wide Bash entry is flagged'

# --- What does not ---------------------------------------------------------------

seed_then_add "Bash(heroku releases:*)"
silent 'a subcommand grant is not flagged'

seed_then_add "Bash(bundle exec rake test)"
silent 'a runner with a fixed command is not flagged'

seed_then_add "Bash(ruby --version)"
silent 'an interpreter with fixed arguments is not flagged'

seed_then_add "WebFetch(domain:example.com)"
silent 'a non-Bash entry is not flagged'

# --- Change shapes ---------------------------------------------------------------

fresh
allow "$LOCAL_FILE" "Bash(git grep:*)" "Bash(curl:*)"
run_hook
allow "$LOCAL_FILE" "Bash(git grep:*)"
run_hook
silent 'removing an entry produces no notice'

fresh
allow "$LOCAL_FILE" "Bash(git grep:*)"
run_hook
allow "$LOCAL_FILE" "Bash(git grep:*)" "Bash(git *)" "Bash(heroku releases:*)"
run_hook
flags "Bash(git *)" 'in a mixed addition the broad entry is flagged'
case "$CONTEXT" in
    *"heroku releases"*) report false 'in a mixed addition the narrow entry is left out' "notice: $CONTEXT" ;;
    *) report true 'in a mixed addition the narrow entry is left out' ;;
esac

# A notice fires once per addition, not on every later call while the entry stays.
run_hook
silent 'a flagged entry is not reported again on the next call'

# User settings are watched as well as the project's local file.
fresh
allow "$USER_FILE" "Bash(gh:*)"
run_hook
allow "$USER_FILE" "Bash(gh:*)" "Bash(node *)"
run_hook
flags "Bash(node *)" 'a broad entry added to user settings is flagged'
case "$CONTEXT" in
    *"$USER_FILE"*) report true 'the notice names the file the entry landed in' ;;
    *) report false 'the notice names the file the entry landed in' "notice: $CONTEXT" ;;
esac

# --- Malformed and missing input --------------------------------------------------

# A file that fails to parse keeps its old snapshot, so its entries are not reported as new once it
# parses again.
fresh
allow "$LOCAL_FILE" "Bash(git *)"
run_hook
printf '{ not json' > "$LOCAL_FILE"
run_hook
silent 'a malformed settings file produces no notice'
allow "$LOCAL_FILE" "Bash(git *)"
run_hook
silent 'after a malformed spell, entries that were already there are not reported as new'

fresh
run_hook
silent 'no settings files at all produces no notice'
expect_eq "$STATUS" 0 'the hook exits 0 with nothing to check'

seed_then_add "Bash(git *)"
expect_eq "$STATUS" 0 'the hook exits 0 when it emits a notice'

# The broad rule lives in hooks/lib/permission-rules.jq. A copy of the hook with no lib/ beside it
# must stay silent and exit 0, not emit a notice built from a failed jq call.
mkdir -p "$WORK_DIR/bare-hook"
cp "$SUBJECT" "$WORK_DIR/bare-hook/broad-grant-notice.sh"
fresh
allow "$LOCAL_FILE" "Bash(git grep:*)"
jq -n '{tool_name: "Bash"}' | HOME="$FAKE_HOME" CLAUDE_PROJECT_DIR="$PROJECT" "$WORK_DIR/bare-hook/broad-grant-notice.sh" >/dev/null 2>&1
allow "$LOCAL_FILE" "Bash(git grep:*)" "Bash(git *)"
OUT=$(jq -n '{tool_name: "Bash"}' | HOME="$FAKE_HOME" CLAUDE_PROJECT_DIR="$PROJECT" "$WORK_DIR/bare-hook/broad-grant-notice.sh" 2>/dev/null)
STATUS=$?
expect_eq "$OUT" "" 'with the shared rules file missing, the hook stays silent'
expect_eq "$STATUS" 0 'with the shared rules file missing, the hook exits 0'

summary || exit 1
