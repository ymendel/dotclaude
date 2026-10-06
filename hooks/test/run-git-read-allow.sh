#!/usr/bin/env bash
# Checks over git-read-allow.py, the PermissionRequest hook that approves read-only git run against
# another directory with `git -C <dir>`. Run it after touching that script:
#
#   ./hooks/test/run-git-read-allow.sh
#
# The decision is read from stdout and the routing from the log, pointed at a scratch file by
# CLAUDE_GIT_READ_LOG so a run never appends to the real one. Same shape as
# run-permission-request.sh, whose helpers this mirrors rather than shares.
#
# Fixtures are invented paths, never this machine's.
#
# No framework, no `set -e` (a failing case must report, not abort), non-zero exit at the end.

if ! command -v jq &>/dev/null; then
    echo "run-git-read-allow: jq is required to build payloads and read decisions. Bailing." >&2
    exit 1
fi

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$(cd "$TEST_DIR/.." && pwd)/git-read-allow.py"

if [ ! -x "$HOOK" ]; then
    echo "run-git-read-allow: $HOOK is missing or not executable." >&2
    exit 1
fi

WORK_DIR="$(mktemp -d)"
cleanup() { [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"; }
trap cleanup EXIT

. "$(cd "$TEST_DIR/../.." && pwd)/test/_harness.sh"

# run <payload> — feeds the hook, leaving its stdout in $STDOUT and the log in $LOG.
run() {
    LOG="$WORK_DIR/log.txt"
    STDOUT="$WORK_DIR/stdout.json"
    : > "$LOG"
    : > "$STDOUT"
    printf '%s' "$1" | CLAUDE_GIT_READ_LOG="$LOG" "$HOOK" > "$STDOUT"
}

# payload <tool> <command>
payload() {
    jq -nc --arg tool "$1" --arg command "$2" \
        '{hook_event_name: "PermissionRequest", tool_name: $tool, tool_input: {command: $command}}'
}

behavior() { jq -r '.hookSpecificOutput.decision.behavior // "none"' "$STDOUT" 2>/dev/null; }
routed() { awk '{print $2}' "$LOG"; }

# allows <label> <command>
allows() {
    local label="$1"
    run "$(payload Bash "$2")"
    if [ "$(jq -r '.hookSpecificOutput.hookEventName' "$STDOUT" 2>/dev/null)" = PermissionRequest ] \
        && [ "$(behavior)" = allow ] && [ "$(routed)" = allow ]; then
        report true "$label"
    else
        report false "$label" "behavior=$(behavior) routed=$(routed) stdout=$(cat "$STDOUT")"
    fi
}

# abstains <label> <expected-log-reason> <command> [tool]
abstains() {
    local label="$1" reason="$2"
    run "$(payload "${4:-Bash}" "$3")"
    if [ ! -s "$STDOUT" ] && [ "$(routed)" = "$reason" ]; then
        report true "$label"
    else
        report false "$label" "expected empty stdout and '$reason', got routed=$(routed) stdout=$(cat "$STDOUT")"
    fi
}

# --- The approving set -------------------------------------------------------

allows "grep in another repo" \
    'git -C ../shipping-tracker grep -n -i "rate\|fee" -- app lib'
allows "show of a file at a ref" \
    'git -C /work/shipping-tracker show origin/main:config/routes.rb'
allows "log" \
    'git -C ../shipping-tracker log --oneline -3'
allows "ls-tree" \
    'git -C ../shipping-tracker ls-tree --name-only -r origin/main app/'
allows "ls-files" \
    'git -C ../shipping-tracker ls-files'

# RTK rewrites `git -C` to `rtk git -C` and leaves it to prompt, so either form may arrive.
allows "the rtk-prefixed form" \
    'rtk git -C ../shipping-tracker show HEAD:README.md'

# Ordinary options that merely look like the refused ones.
allows "grep's --or is not the pager option" \
    'git -C ../shipping-tracker grep -e carrier --or -e freight'
allows "context flags are fine" \
    'git -C ../shipping-tracker grep -n -A14 -B2 "def quote" -- lib'

# A regex alternation inside quotes is not a pipe.
allows "a quoted pipe is part of the pattern" \
    "git -C ../shipping-tracker grep -n -E 'quote|invoice' -- app"

# --- Anything that is more than one command ----------------------------------

abstains "a chained command" compound \
    'git -C ../shipping-tracker grep rate; touch marker.txt'
abstains "a pipe" compound \
    'git -C ../shipping-tracker grep rate | head -5'
abstains "a redirect" compound \
    'git -C ../shipping-tracker log > history.txt'
abstains "a command substitution" unsafe-char \
    'git -C ../shipping-tracker grep "$(whoami)"'
abstains "a backtick substitution" unsafe-char \
    'git -C ../shipping-tracker grep `whoami`'
abstains "a newline" unsafe-char \
    "git -C ../shipping-tracker grep rate
touch marker.txt"
abstains "an unbalanced quote" unparsed-command \
    'git -C ../shipping-tracker grep "rate'

# --- The wrong shape ---------------------------------------------------------

# `-c` sets config, and config can name a program to run.
abstains "a -c after -C" global-option \
    'git -C ../shipping-tracker -c core.pager=less grep rate'
abstains "a -c before -C" shape \
    'git -c core.fsmonitor=probe.sh -C ../shipping-tracker grep rate'
abstains "an environment prefix" shape \
    'GIT_PAGER=probe.sh git -C ../shipping-tracker log'
abstains "bare git grep is left to its allow rule" shape \
    'git grep rate'
abstains "a subcommand that writes" subcommand \
    'git -C ../shipping-tracker commit -m "Update rates"'

# --- Options that run a program or write a file ------------------------------

abstains "grep -O names a pager to run" pager \
    'git -C ../shipping-tracker grep -Oprobe.sh rate'
abstains "-O bundled with other short flags" pager \
    'git -C ../shipping-tracker grep -nO rate'
abstains "--open-files-in-pager" pager \
    'git -C ../shipping-tracker grep --open-files-in-pager=probe.sh rate'
abstains "an abbreviation of --open-files-in-pager" pager \
    'git -C ../shipping-tracker grep --open=probe.sh rate'
abstains "log --output writes a file" output \
    'git -C ../shipping-tracker log --output=history.txt'
abstains "an abbreviation of --output" output \
    'git -C ../shipping-tracker show --out=history.txt HEAD'

# --- Everything else ---------------------------------------------------------

abstains "a tool other than Bash" wrong-tool \
    'git -C ../shipping-tracker grep rate' Edit

run 'this is not json'
if [ ! -s "$STDOUT" ] && [ "$(routed)" = unparsed ]; then
    report true "malformed input is logged unparsed and decides nothing"
else
    report false "malformed input is logged unparsed and decides nothing" \
        "routed=$(routed) stdout=$(cat "$STDOUT")"
fi

# --- The standing invariant --------------------------------------------------
#
# Approves or abstains, never denies: a denial would block a command no rule objected to.
denied=0
for command in 'git -C ../shipping-tracker grep -Oprobe.sh rate' 'git -C x push' 'rm -rf /'; do
    run "$(payload Bash "$command")"
    [ "$(behavior)" = deny ] && denied=$((denied + 1))
done
[ "$denied" -eq 0 ] \
    && report true "the hook never denies, only allows or abstains" \
    || report false "the hook never denies, only allows or abstains" "$denied of 3 denied"

summary || exit 1
