#!/usr/bin/env bash
# Checks over claude-dir-write-allow.sh, the PermissionRequest hook. Run it after touching that
# script:
#
#   ./hooks/test/claude-dir-checks.sh
#
# A third harness. run-checks.sh passes command strings to the PreToolUse guards, and
# notify-checks.sh stubs osascript to assert a delivery — this hook takes a tool payload and answers
# with a decision object, so it needs neither shape.
#
# Both halves are asserted. The decision is read from stdout, which is this hook's only channel that
# matters: a PermissionRequest hook grants nothing except through a `decision` object, and a
# malformed answer is worse than none, since a background session that can't prompt denies the call
# outright. The routing is read from the log, pointed at a scratch file by CLAUDE_CLAUDEDIR_LOG so a
# run never appends to the real one.
#
# What this cannot check: that Claude Code honours the decision. That it does — that an `allow` here
# clears the protected-path gate no allow rule reaches — was established by hand against Claude Code
# 2.1.236, and the only detector is the "Allowed by PermissionRequest hook" label a human sees. See
# rules/settings.md.
#
# Fixtures are invented paths, never this machine's: the hook comes from this file's location, and
# the log lives in a temp directory removed by the run.
#
# No framework, no `set -e` (a failing case must report, not abort), non-zero exit at the end.

if ! command -v jq &>/dev/null; then
    echo "claude-dir-checks: jq is required. The hook reads its payload with jq and would" >&2
    echo "abstain on every case without it, so the abstain checks would report passes they" >&2
    echo "never earned. Bailing instead." >&2
    exit 1
fi

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$(cd "$TEST_DIR/.." && pwd)/claude-dir-write-allow.sh"

if [ ! -x "$HOOK" ]; then
    echo "claude-dir-checks: $HOOK is missing or not executable." >&2
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

# run <payload> — feeds the hook, leaving its stdout in $STDOUT and the log in $LOG.
run() {
    LOG="$WORK_DIR/log.txt"
    STDOUT="$WORK_DIR/stdout.json"
    : > "$LOG"
    : > "$STDOUT"
    printf '%s' "$1" | CLAUDE_CLAUDEDIR_LOG="$LOG" bash "$HOOK" > "$STDOUT"
}

# payload <tool> <path-field> <path>
payload() {
    jq -n --arg tool "$1" --arg field "$2" --arg path "$3" \
        '{hook_event_name: "PermissionRequest", tool_name: $tool,
          tool_input: {($field): $path}}'
}

behavior() { jq -r '.hookSpecificOutput.decision.behavior // "none"' "$STDOUT" 2>/dev/null; }
routed() { awk '{print $2}' "$LOG"; }

# allows <label> <tool> <field> <path> — the whole approving contract in one assertion: a valid
# decision object naming this event, carrying allow, and logged as such.
allows() {
    local label="$1"
    run "$(payload "$2" "$3" "$4")"
    if [ "$(jq -r '.hookSpecificOutput.hookEventName' "$STDOUT" 2>/dev/null)" = PermissionRequest ] \
        && [ "$(behavior)" = allow ] && [ "$(routed)" = allow ]; then
        report true "$label"
    else
        report false "$label" "behavior=$(behavior) routed=$(routed) stdout=$(cat "$STDOUT")"
    fi
}

# abstains <label> <expected-log-reason> <tool> <field> <path> — the hook must emit nothing at all,
# leaving the permission flow untouched, and say in the log why.
abstains() {
    local label="$1" reason="$2"
    run "$(payload "$3" "$4" "$5")"
    if [ ! -s "$STDOUT" ] && [ "$(routed)" = "$reason" ]; then
        report true "$label"
    else
        report false "$label" "expected empty stdout and '$reason', got routed=$(routed) stdout=$(cat "$STDOUT")"
    fi
}

# --- The approving set -------------------------------------------------------

allows "Edit inside .claude is allowed" \
    Edit file_path /Users/alice/dev/shipping-tracker/.claude/scratch/derive-rates.py
allows "Write inside .claude is allowed" \
    Write file_path /Users/alice/dev/shipping-tracker/.claude/handoffs/2026-01-02-resume.md

# NotebookEdit carries `notebook_path`, and a bare `Edit` matcher already catches it because hook
# matchers are regexes tested anywhere in the tool name. Reading only `file_path` made every
# notebook look pathless and abstain silently.
allows "NotebookEdit's notebook_path is read, not just file_path" \
    NotebookEdit notebook_path /Users/alice/dev/shipping-tracker/.claude/scratch/analysis.ipynb

# --- The carve-outs ---------------------------------------------------------
#
# These are the point of the hook, not an edge of it. Approving a write to the settings files would
# let the hook add permission rules, and approving one under .claude/hooks/ would let it replace
# itself — so a decision hook must never be able to edit its own inputs.

abstains "settings.json keeps its prompt" carved-out \
    Edit file_path /Users/alice/dev/shipping-tracker/.claude/settings.json
abstains "settings.local.json keeps its prompt" carved-out \
    Edit file_path /Users/alice/dev/shipping-tracker/.claude/settings.local.json
abstains ".claude/hooks/ keeps its prompt" carved-out \
    Write file_path /Users/alice/dev/shipping-tracker/.claude/hooks/some-guard.sh
abstains "a notebook under .claude/hooks/ is carved out too" carved-out \
    NotebookEdit notebook_path /Users/alice/dev/shipping-tracker/.claude/hooks/scratch.ipynb

# A `..` segment defeats a string-matched carve-out: this resolves to settings.json while matching
# none of the patterns above. The hook abstains rather than resolving it, so the carve-out cannot be
# walked around.
abstains "a .. segment abstains rather than routing around a carve-out" dotdot \
    Edit file_path /Users/alice/dev/shipping-tracker/.claude/scratch/../settings.json

# --- Everything else --------------------------------------------------------

abstains "a path outside .claude is left alone" outside \
    Edit file_path /Users/alice/dev/shipping-tracker/lib/rates.rb

# The trailing slash in the match matters: a file merely named `.claude` is not a directory of that
# name, and nothing about it is protected.
abstains "a file named .claude is not a .claude directory" outside \
    Edit file_path /Users/alice/dev/shipping-tracker/config/.claude

# The registered matcher is Write|Edit, so this should never arrive. The hook is registered at user
# level and outlives any one matcher, so it checks the tool itself rather than trusting settings.json
# — and Bash is the case that would matter, since a Bash write to .claude/ is gated the same way and
# is deliberately not covered here.
abstains "a tool outside the write family is declined" wrong-tool \
    Bash command "rm /Users/alice/dev/shipping-tracker/.claude/scratch/stale.txt"

abstains "a payload with no path abstains" no-path \
    Edit file_path ""

# Malformed input must not produce a decision. A hook that prints an invalid answer hangs a
# background session rather than failing loudly. It must also stay quiet on stderr, or a test run
# fills with jq parse errors from every field read.
run 'this is not json'
if [ ! -s "$STDOUT" ] && [ "$(routed)" = unparsed ]; then
    report true "malformed input is logged unparsed and decides nothing"
else
    report false "malformed input is logged unparsed and decides nothing" \
        "routed=$(routed) stdout=$(cat "$STDOUT")"
fi

run ''
if [ ! -s "$STDOUT" ] && [ "$(routed)" = unparsed ]; then
    report true "empty input is logged unparsed and decides nothing"
else
    report false "empty input is logged unparsed and decides nothing" \
        "routed=$(routed) stdout=$(cat "$STDOUT")"
fi

# --- The standing invariant -------------------------------------------------
#
# This hook approves or abstains. It must never deny: a denial here would block a write that no rule
# objected to, and `deny` is the one behavior whose blast radius is not a prompt.
denied=0
for tool in Edit Write NotebookEdit Bash; do
    run "$(payload "$tool" file_path /Users/alice/dev/shipping-tracker/.claude/settings.json)"
    [ "$(behavior)" = deny ] && denied=$((denied + 1))
done
[ "$denied" -eq 0 ] \
    && report true "the hook never denies, only allows or abstains" \
    || report false "the hook never denies, only allows or abstains" "$denied of 4 denied"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
