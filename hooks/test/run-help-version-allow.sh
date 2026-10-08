#!/usr/bin/env bash
# Checks over help-version-allow.py, the PermissionRequest hook that approves asking a CLI for its
# help or version. Run it after touching that script:
#
#   ./hooks/test/run-help-version-allow.sh
#
# The decision is read from stdout and the routing from the log, pointed at a scratch file by
# CLAUDE_HELP_VERSION_LOG so a run never appends to the real one. Same shape as
# run-git-read-allow.sh, whose helpers this mirrors rather than shares.
#
# No framework, no `set -e` (a failing case must report, not abort), non-zero exit at the end.

if ! command -v jq &>/dev/null; then
    echo "run-help-version-allow: jq is required to build payloads and read decisions. Bailing." >&2
    exit 1
fi

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$(cd "$TEST_DIR/.." && pwd)/help-version-allow.py"

if [ ! -x "$HOOK" ]; then
    echo "run-help-version-allow: $HOOK is missing or not executable." >&2
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
    printf '%s' "$1" | CLAUDE_HELP_VERSION_LOG="$LOG" "$HOOK" > "$STDOUT"
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

# --- Any bare name, flag alone -----------------------------------------------

allows "an unlisted tool's --help" 'overmind --help'
allows "an unlisted tool's --version" 'trafilatura --version'
allows "a tool with no subcommands" 'rm --help'

# --- Listed tools, subcommand forms ------------------------------------------

allows "a subcommand's --help" 'heroku pg:psql --help'
allows "nested subcommands" 'gh pr create --help'
allows "a subcommand's --version" 'gem list --version'
allows "help with a topic" 'bundle help config'
allows "help with no topic" 'git help'
allows "the macOS log tool" 'log help show'

# --- Pipes, stderr merge, and the rtk prefix ---------------------------------

allows "piped into grep" "heroku pg:psql --help 2>&1 | grep -i -- '--file'"
allows "piped into rtk grep" "bundle help config | rtk grep -n -e 'list' -e 'get'"
allows "piped into head" 'gh pr create --help | head -40'
allows "two filters" "brew install --help | grep -i cask | tail -5"
allows "a hand-written rtk prefix" 'rtk bundle --version'
allows "rtk's own help" 'rtk --help'

# --- The BSD trap: words before the flag on an unlisted tool -----------------

abstains "a file before --help" unlisted-tool 'rm notes.txt --help'
abstains "help with operands on an unlisted tool" unlisted-tool 'rm help topic'
abstains "a positional before --version" unlisted-tool 'ssh build-host --version'

# --- Wrappers that run something else ----------------------------------------

abstains "bundle exec" wrapper 'bundle exec rake --help'
abstains "npx downloads a package" wrapper 'npx cowsay --help'
abstains "make help runs a target" wrapper 'make help'
abstains "env prefix" wrapper 'env heroku --help'
abstains "rtk test wraps a command" wrapper 'rtk test make --help'

# --- Paths, options, and the wrong shape -------------------------------------

abstains "a repo script" path './scripts/deploy.sh --help'
abstains "a binstub" path 'bin/rails --help'
abstains "an absolute path" path '/usr/local/bin/heroku --help'
abstains "-h is not help everywhere" unlisted-tool 'du -h'
abstains "-h on a listed tool" shape 'git log -h'
abstains "an option before --help" shape 'git log --oneline --help'
abstains "help after a subcommand" shape 'git commit help'
abstains "an ordinary command" unlisted-tool 'heroku-repl start'

# --- Anything that is more than one command ----------------------------------

abstains "a chained command" compound 'heroku --help; touch marker.txt'
abstains "an and-chain" compound 'heroku --help && touch marker.txt'
abstains "a redirect to a file" compound 'bundle --help > help.txt'
abstains "pipe and stderr together" compound 'heroku --help |& grep pg'
abstains "a pipe into something other than a filter" filter 'heroku --help | sh'
abstains "a pipe into a writer" filter 'heroku --help | tee help.txt'
abstains "a trailing pipe" compound 'heroku --help |'
abstains "a command substitution" unsafe-char 'heroku "$(whoami)" --help'
abstains "a backtick substitution" unsafe-char 'heroku `whoami` --help'
abstains "a newline" unsafe-char "heroku --help
touch marker.txt"
abstains "an unbalanced quote" unparsed-command 'heroku --help | grep "pg'

# --- Everything else ---------------------------------------------------------

abstains "a tool other than Bash" wrong-tool 'heroku --help' Edit

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
for command in 'rm notes.txt --help' 'npx cowsay --help' 'rm -rf /'; do
    run "$(payload Bash "$command")"
    [ "$(behavior)" = deny ] && denied=$((denied + 1))
done
[ "$denied" -eq 0 ] \
    && report true "the hook never denies, only allows or abstains" \
    || report false "the hook never denies, only allows or abstains" "$denied of 3 denied"

summary || exit 1
