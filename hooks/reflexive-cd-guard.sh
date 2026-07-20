#!/usr/bin/env bash
# reflexive-cd-guard.sh — PreToolUse (Bash) guard.
#
# Blocks the reflexive `cd` prefix that `feedback.md` ("Don't reflexively cd into
# the working directory") warns against. The Bash working directory is already the
# project root and persists across calls, so two shapes are hazards:
#   - `cd <project-root>` / `cd .` — redundant, and `cd …;` with a redirect trips
#     a path-resolution approval.
#   - `cd <project-subdir>` — persists across calls and silently misdirects
#     cwd-relative tools with no error (a handoff script writing under the wrong
#     subtree, a relative path resolving against the wrong place).
# Both are caught. This is the mechanical-gate half of that prose rule, per
# ADR 0004's rule-vs-hook split (the parsing-hook branch: recognizing the
# violation needs the project root, richer than a deny glob).
#
# What still passes through (deliberately):
#   - A reverting subshell `(cd <dir> && <cmd>)` — the command does not START with
#     `cd`, so the cwd change is scoped and cannot leak. This is the sanctioned
#     way to run something from another directory.
#   - `cd ..` / `cd ../sibling` / any target OUTSIDE the project, and `cd -`.
#   - A target the shell must expand at runtime (`$VAR`, `$(…)`, backticks) — we
#     cannot resolve it, so we do not guess (except the literal project-root env
#     var, handled lexically below).
#   - A `cd` into a subdirectory that does not exist — the real cd would fail and
#     leave cwd unchanged, so there is no drift to prevent.
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
# leading whitespace). `rest` captures everything after the `cd `. A subshell
# `(cd … && …)` starts with `(`, not `cd`, so it never matches — that is how the
# sanctioned reverting form stays allowed.
if [[ "$CMD" =~ ^[[:space:]]*cd[[:space:]]+(.*)$ ]]; then
  rest="${BASH_REMATCH[1]}"
else
  exit 0
fi

# The cd target is the first token, up to a command separator (newline ; & |) or
# the end of the string. The newline cut must come first: bash's `=~` lets `.`
# match newlines, so `rest` spans a multi-line command (a bare `cd <root>` on its
# own line, then the real command underneath) — without cutting at the newline,
# `target` would swallow the following lines and never match the project root.
# Trim trailing whitespace and one surrounding quote pair.
target=${rest%%$'\n'*}
target=${target%%[;&|]*}
target=${target%"${target##*[![:space:]]}"}
target=${target#[\"\']}
target=${target%[\"\']}
[ -z "$target" ] && exit 0

# `cd -` returns to the previous directory, not a subdir reflex — let it pass.
[ "$target" = "-" ] && exit 0

CWD=$(jq -r '.cwd // empty' <<<"$INPUT")
PROJECT="${CLAUDE_PROJECT_DIR:-$CWD}"

# Normalize for the lexical checks: expand a leading ~, drop a trailing slash.
expanded=${target/#\~/$HOME}
expanded=${expanded%/}
proj=${PROJECT%/}
cwd=${CWD%/}

block=false
reason="root"

# Lexical reflex checks (do not require the target to exist): cd to `.`, the
# project-root env var, or the literal project-root / cwd path.
if [ "$target" = "." ] \
  || [ "$target" = '$CLAUDE_PROJECT_DIR' ] \
  || [ "$target" = '${CLAUDE_PROJECT_DIR}' ] \
  || { [ -n "$proj" ] && [ "$expanded" = "$proj" ]; } \
  || { [ -n "$cwd" ] && [ "$expanded" = "$cwd" ]; }; then
  block=true
fi

# Physical-path check (resolves symlinks AND relative targets): catch a cd whose
# real destination is the project root (redundant) or a subdirectory of it
# (persists, misdirects cwd-relative tools). This is what catches a cd through the
# `~/.claude → dotclaude` symlink alias, whose lexical path never prefix-matches
# the canonical project root. Skipped for unresolvable runtime expansions.
if [ "$block" = false ]; then
  case "$target" in
    *'$'* | *'`'*) : ;; # runtime expansion — cannot resolve, do not guess
    *)
      proj_real=$(cd "$proj" 2>/dev/null && pwd -P)
      # Resolve the target relative to the tool's cwd, following symlinks.
      resolved=$(cd "$cwd" 2>/dev/null && cd "$expanded" 2>/dev/null && pwd -P)
      if [ -n "$resolved" ] && [ -n "$proj_real" ]; then
        if [ "$resolved" = "$proj_real" ]; then
          block=true
        elif [[ "$resolved" == "$proj_real"/* ]]; then
          block=true
          reason="subdir"
        fi
      fi
      ;;
  esac
fi

[ "$block" = false ] && exit 0

if [ "$reason" = "subdir" ]; then
  echo "reflexive-cd-guard: blocked. This command \`cd\`s into a project subdirectory, but the Bash working directory persists across calls, so it silently misdirects later cwd-relative tools with no error — the exact failure feedback.md warns about. To run something from another directory, use \`git -C <path>\` / an absolute path, or a reverting subshell \`(cd <dir> && <cmd>)\` — never a bare persistent cd. See feedback.md 'Don't reflexively cd into the working directory.'" >&2
else
  echo "reflexive-cd-guard: blocked. This command prefixes \`cd\` to the project root (or \`.\`), but the Bash working directory is already the project root and persists across calls, so the cd is redundant — and a \`cd …;\` with output redirection trips a path-resolution approval. Run the command directly. If it genuinely needs another directory, pass it explicitly (\`git -C <path>\`, an absolute path) instead of cd-ing. See feedback.md 'Don't reflexively cd into the working directory.'" >&2
fi
exit 2
