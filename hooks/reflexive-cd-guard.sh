#!/usr/bin/env bash
# reflexive-cd-guard.sh — PreToolUse (Bash) guard.
#
# Blocks the reflexive `cd <project-root>` prefix that `feedback.md` ("Don't
# reflexively cd into the working directory") warns against. The Bash working
# directory is already the project root and persists across calls, so a leading
# `cd <project-root>` / `cd .` is redundant — and `cd …; <cmd>` with a redirect
# trips a path-resolution approval, while a `cd <subdir>` that persists silently
# misdirects cwd-relative tools. This is the mechanical-gate half of that prose
# rule, per ADR 0004's rule-vs-hook split (the parsing-hook branch: recognizing
# the violation needs the project root, richer than a deny glob).
#
# Scope is deliberately tight (ADR 0004: a too-broad gate is worse than none).
# It fires ONLY when a command STARTS with a `cd` whose target resolves to the
# project root, the current working directory, or `.` — the pure reflex. A `cd`
# to any other directory (a subdir, `..`, `-`) passes through untouched.
#
# Block mechanism is exit code 2 (per settings.md, the only hook signal that
# beats a matching allow rule), matching hooks/uv-run-guard.sh.

if ! command -v jq &>/dev/null; then
  # Consistent with the other Bash hooks: without jq we cannot parse the input,
  # so pass through. rtk-rewrite.sh already warns about a missing jq.
  exit 0
fi

INPUT=$(cat)
CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
[ -z "$CMD" ] && exit 0

# Only act on a command that STARTS with `cd <something>` (after optional
# leading whitespace). `rest` captures everything after the `cd `.
if [[ "$CMD" =~ ^[[:space:]]*cd[[:space:]]+(.*)$ ]]; then
  rest="${BASH_REMATCH[1]}"
else
  exit 0
fi

# The cd target is the first token, up to a command separator (; & |) or the
# end of the string. Trim trailing whitespace and one surrounding quote pair.
target=${rest%%[;&|]*}
target=${target%"${target##*[![:space:]]}"}
target=${target#[\"\']}
target=${target%[\"\']}
[ -z "$target" ] && exit 0

CWD=$(jq -r '.cwd // empty' <<<"$INPUT")
PROJECT="${CLAUDE_PROJECT_DIR:-$CWD}"

# Normalize for comparison: expand a leading ~, drop a trailing slash.
expanded=${target/#\~/$HOME}
expanded=${expanded%/}
proj=${PROJECT%/}
cwd=${CWD%/}

if [ "$target" = "." ] \
  || [ "$target" = '$CLAUDE_PROJECT_DIR' ] \
  || [ "$target" = '${CLAUDE_PROJECT_DIR}' ] \
  || { [ -n "$proj" ] && [ "$expanded" = "$proj" ]; } \
  || { [ -n "$cwd" ] && [ "$expanded" = "$cwd" ]; }; then
  echo "reflexive-cd-guard: blocked. This command prefixes \`cd\` to the project root (or \`.\`), but the Bash working directory is already the project root and persists across calls, so the cd is redundant — and a \`cd …;\` with output redirection trips a path-resolution approval. Run the command directly. If it genuinely needs another directory, pass it explicitly (\`git -C <path>\`, an absolute path) instead of cd-ing. See feedback.md 'Don't reflexively cd into the working directory.'" >&2
  exit 2
fi

exit 0
