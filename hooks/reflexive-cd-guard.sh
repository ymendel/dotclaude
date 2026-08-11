#!/usr/bin/env bash
# reflexive-cd-guard.sh — PreToolUse (Bash) guard.
#
# Blocks the reflexive `cd` prefix into a working directory. The Bash working
# directory persists across calls, so three shapes are hazards:
#   - `cd <project-root>` / `cd .` — redundant, and `cd …;` with a redirect trips
#     a path-resolution approval.
#   - `cd <project-subdir>` — persists across calls and silently misdirects
#     cwd-relative tools with no error (a handoff script writing under the wrong
#     subtree, a relative path resolving against the wrong place).
#   - `cd <additional-working-dir>` (or a subdir of one) — an --add-dir path or a
#     settings.json additionalDirectories entry. Same persist-and-misdirect
#     hazard, and it lands commands in the WRONG REPO — the drift that ran a
#     dotclaude `git add` inside secret-dotclaude. The dirs come from
#     CLAUDE_ADDED_DIRS + settings.json (see the gathering block below).
# All are caught. Recognizing the violation needs the project root and the added
# dirs, richer than a deny glob, so this is a parsing hook rather than a settings
# deny rule.
#
# What still passes through (deliberately):
#   - A reverting subshell `(cd <dir> && <cmd>)` — the command does not START with
#     `cd`, so the cwd change is scoped and cannot leak. This is the sanctioned
#     way to run something from another directory.
#   - `cd ..` / `cd ../sibling` / any target OUTSIDE the project AND outside every
#     additional working dir, and `cd -`.
#   - A target the shell must expand at runtime (`$VAR`, `$(…)`, backticks) — we
#     cannot resolve it, so we do not guess. Two exceptions are handled lexically
#     below: the literal project-root env var, and the
#     `$(git rev-parse --show-toplevel)` git-root idiom (redundant while the shell
#     sits at that root, and its `$(…)` form otherwise slips every guard onto an
#     unavoidable approval prompt). Both are gated on the shell actually being at
#     the project root — see the recovery carve-out below.
#   - A `cd` into a subdirectory that does not exist — the real cd would fail and
#     leave cwd unchanged, so there is no drift to prevent.
#   - `cd <project-root>` when the shell is NOT already there — a RECOVERY, not a
#     reflex. Several shapes pass by design (a target outside every guarded root,
#     `cd ..`, `cd -`, an unresolvable runtime expansion), and any of them strands
#     cwd for the rest of the session. Blocking the way back would make this guard
#     trap the very drift it exists to warn about.
#
# Separately from the prefix hazards above, a command that SHADOWS `cd` — a
# function definition or an alias — is blocked too. That is not a cd; it is
# self-enforcement of the rule this hook exists to enforce, and it converts a
# read-only command into an approval prompt. See the branch below for the
# mechanism.
#
# Block mechanism is exit code 2 — the only hook signal that beats a matching
# allow rule.

if ! command -v jq &>/dev/null; then
  # Consistent with the other Bash hooks: without jq we cannot parse the input,
  # so pass through.
  exit 0
fi

INPUT=$(cat)
CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
[ -z "$CMD" ] && exit 0

# Shadowing `cd` — a function definition or an alias — is not a cd at all. It is
# an attempt to enforce the rule this hook guards on oneself, and it backfires
# twice: the permission gate reports `function_definition`, a parser node no
# allow rule can grant, so a read-only command stops for approval; and shadowing
# a builtin is how one gets broken for real. See tool-and-shell-safety.md's
# "Don't add shell machinery the task didn't ask for".
#
# Checked BEFORE the leading-`cd` match below, which requires whitespace after
# `cd` and so never sees `cd()`. Matched anywhere in the command, not just at the
# start, since a shadow can follow a separator.
#
# Requiring the brace keeps a mere mention from tripping it — `rtk grep "cd()"`
# passes. A command carrying the full definition text does not, which is the
# deny-substring trade-off settings.md describes: over-block, then pass the text
# via a file. That is how this branch's own tests are run.
if [[ "$CMD" =~ (^|[[:space:]\;\&\|\(])cd[[:space:]]*\(\)[[:space:]]*\{ ]] \
  || [[ "$CMD" =~ (^|[[:space:]\;\&\|\(])function[[:space:]]+cd([[:space:]]*\(\))?[[:space:]]*\{ ]] \
  || [[ "$CMD" =~ (^|[[:space:]\;\&\|\(])alias[[:space:]]+cd= ]]; then
  echo "reflexive-cd-guard: blocked. This shadows \`cd\` with a function or alias, which is not a directory change but an attempt to enforce the no-reflexive-cd rule on yourself. It backfires: the permission gate reports \`function_definition\`, which no allow rule can grant, so the command stops for approval even when its actual work is read-only — and shadowing a builtin is how one gets broken for real. Comply by writing the command without the forbidden form. Enforcement is this hook's job, not the command's." >&2
  exit 2
fi

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

# Additional working directories carry the SAME persist-and-misdirect hazard as a
# project subdir: a bare persistent cd into one silently steers later cwd-relative
# calls into the wrong tree. Gather them from two sources, because the PreToolUse
# payload carries neither:
#   - CLAUDE_ADDED_DIRS — colon-separated, exported by whatever launcher passes
#     --add-dir (the payload has no field for it, so the launcher must surface it).
#   - settings.json's permissions.additionalDirectories — the declared list.
# Both are tilde-expanded and resolved to real paths below; unresolvable or
# non-existent entries are dropped.
added_raw=()
if [ -n "$CLAUDE_ADDED_DIRS" ]; then
  IFS=':' read -r -a _split <<<"$CLAUDE_ADDED_DIRS"
  added_raw+=("${_split[@]}")
fi
# The three settings scopes a shell hook can read, not just the global one: a
# project may declare additionalDirectories in either project-level file, and a
# declared-but-unread dir is a cd this guard lets through — the drift it exists to
# stop. Insurance against that, not an observed pattern — the dir actually guarded
# in this repo arrives via CLAUDE_ADDED_DIRS above.
#
# A fourth scope, managed/enterprise policy, is skipped: it can arrive as an MDM
# plist or a server-delivered policy with no file to read, so no shell hook covers
# it in general. There is no user-level settings.local.json — .local is
# project-only.
#
# Unioned, not resolved by precedence: Claude Code lets a higher-precedence scope
# override a lower one, so this can guard a dir that resolution would have dropped.
# It over-guards, never under-guards — the right direction for a guard to err.
for SETTINGS in \
  "$HOME/.claude/settings.json" \
  "${PROJECT%/}/.claude/settings.json" \
  "${PROJECT%/}/.claude/settings.local.json"; do
  [ -f "$SETTINGS" ] || continue
  while IFS= read -r _dir; do
    [ -n "$_dir" ] && added_raw+=("$_dir")
  done < <(jq -r '.permissions.additionalDirectories[]?' "$SETTINGS" 2>/dev/null)
done
added_real=()
for _a in "${added_raw[@]}"; do
  _ae=${_a/#\~/$HOME}
  _ar=$(cd "$_ae" 2>/dev/null && pwd -P)
  [ -n "$_ar" ] && added_real+=("$_ar")
done

# Normalize for the lexical checks: expand a leading ~, drop a trailing slash.
expanded=${target/#\~/$HOME}
expanded=${expanded%/}
proj=${PROJECT%/}
cwd=${CWD%/}

block=false
reason="root"

# Resolve both roots up front, because whether a cd to the project root is a
# redundant reflex or a legitimate RECOVERY depends on where the shell actually
# is. The guard's own premise — "you are already at the project root" — is not
# always true: a cd that escaped this guard (one targeting a path outside every
# guarded root, which passes by design) leaves cwd stranded elsewhere for the rest
# of the session. `cd <project-root>` is then the only way back, so blocking it
# unconditionally makes the guard trap the very drift it warns about.
proj_real=$(cd "$proj" 2>/dev/null && pwd -P)
cwd_real=$(cd "$cwd" 2>/dev/null && pwd -P)
at_project_root=false
[ -n "$proj_real" ] && [ "$cwd_real" = "$proj_real" ] && at_project_root=true

# Always-redundant targets: a no-op no matter where the shell sits. Still worth
# blocking from a stranded cwd, but the reason differs there — the shell is not at
# the project root, so the default message's "already the project root" would be
# false. Switch to `noop`, whose message says what is actually true and points at
# the recovery.
if [ "$target" = "." ] || { [ -n "$cwd" ] && [ "$expanded" = "$cwd" ]; }; then
  block=true
  [ "$at_project_root" = true ] || reason="noop"
# Project-root targets — reflexive only when already there (see above).
elif [ "$at_project_root" = true ] \
  && { [ "$target" = '$CLAUDE_PROJECT_DIR' ] \
    || [ "$target" = '${CLAUDE_PROJECT_DIR}' ] \
    || { [ -n "$proj" ] && [ "$expanded" = "$proj" ]; }; }; then
  block=true
fi

# The `cd $(git rev-parse --show-toplevel)` idiom (any quoting) targets the git
# root, which while the shell sits at the project root is its own cwd — a no-op.
# Its `$(…)`/backtick form makes the physical-path check below skip it, so without
# this clause it would slip the guard entirely and force an unavoidable "cannot be
# statically analyzed" approval prompt every time. Matched lexically (the target
# still carries the substitution text at this point). Gated on `at_project_root`
# for the same reason as the checks above: from a stranded cwd this idiom is one of
# the ways back, and it is also what keeps the message below true whenever it fires.
if [ "$block" = false ] && [ "$at_project_root" = true ] \
  && [[ "$target" == *'git rev-parse --show-toplevel'* ]]; then
  block=true
  reason="gitroot"
fi

# Physical-path check (resolves symlinks AND relative targets): resolve the
# target's real destination once, then test it against every guarded working root
# — the project root (redundant if equal, misdirecting if a subdir of it) and each
# additional working dir (always misdirecting — a separate tree the cwd would
# silently move into). This is what catches a cd through the `~/.claude →
# dotclaude` symlink alias, whose lexical path never prefix-matches the canonical
# project root. Skipped for unresolvable runtime expansions.
if [ "$block" = false ]; then
  case "$target" in
    *'$'* | *'`'*) : ;; # runtime expansion — cannot resolve, do not guess
    *)
      # Resolve the target relative to the tool's cwd, following symlinks.
      resolved=$(cd "$cwd" 2>/dev/null && cd "$expanded" 2>/dev/null && pwd -P)
      if [ -n "$resolved" ]; then
        if [ -n "$proj_real" ] && [ "$resolved" = "$proj_real" ]; then
          # Same recovery carve-out as the lexical check above. Spelled as a full
          # `if` rather than a `&&` one-liner so the branch cannot leave a
          # non-zero status as the enclosing block's result.
          if [ "$at_project_root" = true ]; then
            block=true
          fi
        elif [ -n "$proj_real" ] && [[ "$resolved" == "$proj_real"/* ]]; then
          block=true
          reason="subdir"
        else
          for _root in "${added_real[@]}"; do
            if [ "$resolved" = "$_root" ] || [[ "$resolved" == "$_root"/* ]]; then
              block=true
              reason="addeddir"
              break
            fi
          done
        fi
      fi
      ;;
  esac
fi

[ "$block" = false ] && exit 0

if [ "$reason" = "gitroot" ]; then
  echo "reflexive-cd-guard: blocked. This \`cd\`s to \$(git rev-parse --show-toplevel) — the git root, which is already the Bash working directory and persists across calls, so the cd is redundant. Worse, the \$(…) substitution can't be statically analyzed, so it forces a manual approval prompt every time. Run the command directly; if it genuinely needs another directory, pass it explicitly (\`git -C <path>\`, an absolute path)." >&2
elif [ "$reason" = "subdir" ]; then
  echo "reflexive-cd-guard: blocked. This command \`cd\`s into a project subdirectory, but the Bash working directory persists across calls, so it silently misdirects later cwd-relative tools with no error. To run something from another directory, use \`git -C <path>\` / an absolute path, or a reverting subshell \`(cd <dir> && <cmd>)\` — never a bare persistent cd." >&2
elif [ "$reason" = "noop" ]; then
  echo "reflexive-cd-guard: blocked. This \`cd\`s to the directory the shell is already in, so it is a no-op — and a \`cd …;\` with output redirection trips a path-resolution approval. Run the command directly. Note the working directory is NOT the project root right now, so a relative path resolves against \`$cwd\`; if you meant to return to the root, \`cd $proj\` is allowed." >&2
elif [ "$reason" = "addeddir" ]; then
  echo "reflexive-cd-guard: blocked. This command \`cd\`s into an additional working directory (an --add-dir path or a settings.json additionalDirectories entry), but the Bash working directory persists across calls, so it silently misdirects later cwd-relative tools with no error — the exact drift that lands a command in the wrong repo. To run something there, use \`git -C <path>\` / an absolute path, or a reverting subshell \`(cd <dir> && <cmd>)\` — never a bare persistent cd." >&2
else
  echo "reflexive-cd-guard: blocked. This command prefixes \`cd\` to the project root (or \`.\`), but the Bash working directory is already the project root and persists across calls, so the cd is redundant — and a \`cd …;\` with output redirection trips a path-resolution approval. Run the command directly. If it genuinely needs another directory, pass it explicitly (\`git -C <path>\`, an absolute path) instead of cd-ing." >&2
fi
exit 2
