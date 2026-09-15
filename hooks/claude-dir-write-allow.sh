#!/usr/bin/env bash
# PermissionRequest hook: approves Edit/Write/NotebookEdit on paths inside a project's `.claude/`
# directory, which Claude Code treats as a protected path and never auto-approves outside
# bypassPermissions mode — not by an allow rule, and not by acceptEdits.
#
# That a hook `allow` clears that gate was verified 2026-09-15 against Claude Code 2.1.236: a write
# into `.claude/scratch/` ran with the label "Allowed by PermissionRequest hook". No allow rule
# reaches it, including the "always allow access to this directory" grant the prompt itself offers,
# which is inert. rules/settings.md carries the finding, notes/claude-code-quirks.md the reproduction.
#
# Carve-outs are the point of this hook, not an edge of it: it must not be able to widen its own
# reach. A write to either settings file can add permission rules, and a write under `.claude/hooks/`
# can replace this script, so all three keep their prompt. A `..` segment abstains for the same
# reason — it would satisfy the `.claude/` test while resolving somewhere carved out.
#
# Approves or abstains, never denies. Checks live in hooks/test/run-permission-request.sh.

INPUT=$(cat)

LOG="${CLAUDE_CLAUDEDIR_LOG:-$HOME/.claude/.claude-dir-allow.jsonl}"

log_decision() {
  printf '%s %s %s %s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "${TOOL:--}" "${FILE:--}" >> "$LOG"
}

# Abstain on anything unparseable rather than letting jq's parse error escape on every field read.
# Stderr is discarded for this event, so the noise is invisible in use and shows up only in a test
# run — but a hook that cannot read its payload has nothing to decide either way.
if ! jq -e . >/dev/null 2>&1 <<<"$INPUT"; then
  log_decision unparsed
  exit 0
fi

TOOL=$(jq -r '.tool_name // empty' <<<"$INPUT")

# NotebookEdit carries `notebook_path` where Edit and Write carry `file_path`, and a bare `Edit`
# matcher already catches NotebookEdit — matchers are regexes tested anywhere in the tool name, per
# the hooks docs. So both fields have to be read or notebooks silently fall through as pathless.
FILE=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$INPUT")

# Checked here rather than left to the registered matcher, which this script outlives.
case "$TOOL" in
  Edit | Write | NotebookEdit) ;;
  *)
    log_decision wrong-tool
    exit 0
    ;;
esac

# Nothing to decide without a path. Emitting no decision object leaves the permission flow exactly
# as it was.
if [[ -z "$FILE" ]]; then
  log_decision no-path
  exit 0
fi

# A `..` segment defeats the carve-outs below, which match the path as a string:
# `/p/.claude/scratch/../settings.json` matches `*/.claude/*` but matches none of the carved-out
# patterns, so it would be approved while resolving to a file that must not be. Abstain rather than
# resolve it — the path may not exist yet, and macOS `realpath` has no portable resolve-missing
# flag. Abstaining only costs a prompt.
case "$FILE" in
  */../* | */..)
    log_decision dotdot
    exit 0
    ;;
esac

# Must sit inside a `.claude/` directory. The trailing slash keeps this off a file merely named
# `.claude`.
if [[ "$FILE" != */.claude/* ]]; then
  log_decision outside
  exit 0
fi

case "$FILE" in
  */.claude/settings.json | */.claude/settings.local.json | */.claude/hooks/*)
    log_decision carved-out
    exit 0
    ;;
esac

log_decision allow

jq -nc '{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow"
    }
  }
}'
