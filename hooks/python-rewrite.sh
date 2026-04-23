#!/usr/bin/env bash
# Rewrites `python` -> `python3` when python is not in PATH but python3 is.
# Portable: no-ops on machines where python is available.

INPUT=$(cat)
CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")

# Only act on commands that start with `python ` or are exactly `python`
if [[ "$CMD" != python\ * ]] && [[ "$CMD" != "python" ]]; then
  exit 0
fi

# No-op if python is available
if command -v python &>/dev/null; then
  exit 0
fi

# No-op if python3 is also missing (nothing we can do)
if ! command -v python3 &>/dev/null; then
  exit 0
fi

NEW_CMD="python3${CMD#python}"

jq -c --arg cmd "$NEW_CMD" \
  '.tool_input.command = $cmd | {
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "allow",
      "permissionDecisionReason": "python not found, rewriting to python3",
      "updatedInput": .tool_input
    }
  }' <<<"$INPUT"
