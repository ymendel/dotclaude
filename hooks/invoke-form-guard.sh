#!/usr/bin/env bash
# invoke-form-guard.sh — PreToolUse (Bash) guard.
#
# Enforces tool-and-shell-safety.md's "Invoke a project script by the relative
# path its allow rule names". A Bash allow rule matches the literal command
# string, so a project script has exactly one granted spelling, and every other
# spelling of the same call prompts for something the repo already sanctioned:
#
#   hooks/test/run-checks.sh          granted as ./hooks/test/run-*.sh
#   bash scripts/rules-floor.sh       granted as ./scripts/rules-floor.sh:*
#   /abs/path/to/repo/scripts/x.sh    likewise
#
# The prose was in context and missed four times in one session, then again in a
# later one, so this is the next rung per ADR 0004.
#
# The check is a string comparison, not a judgment. Take the first segment of
# the command. If it invokes a file in the cwd's tree by a bare relative path,
# an absolute path, or through an interpreter (`bash`, `sh`, `zsh`, `python3`,
# `ruby`, `node`), rebuild it in the two path-only forms — `./<rel> <args>` and
# `<rel> <args>`. Block only when one of those is granted by an allow rule and
# the command as written is not. Where nothing is granted the prompt is
# legitimate and this hook has no opinion.
#
# An interpreter form is only redirected to a path form when the file is
# executable, since `./script` fails otherwise.
#
# Blocks rather than rewrites. A PreToolUse hook can return an updated input,
# but a silent rewrite would hide the slip it exists to surface, and
# rule-maintenance.md asks for a mechanism to be visible before it is automated.
#
# Allow lists read: the user's settings.json (overridable through
# INVOKE_FORM_USER_SETTINGS, for the tests), then the project's
# .claude/settings.json and .claude/settings.local.json. Pattern semantics follow
# settings.md: `X:*` and `X *` match X alone or X followed by a space and
# anything. A leading-`*` allow rule never fires, so one is skipped here too.
#
# Not quote-aware, like its siblings. The first segment ends at the first `;`,
# `&`, `|` or redirect character, wherever it sits.

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
[ -z "$CMD" ] && exit 0

CWD=$(jq -r '.cwd // empty' <<<"$INPUT")
[ -z "$CWD" ] && CWD="${CLAUDE_PROJECT_DIR:-$PWD}"
PROJECT="${CLAUDE_PROJECT_DIR:-$CWD}"
USER_SETTINGS="${INVOKE_FORM_USER_SETTINGS:-$HOME/.claude/settings.json}"

# The first segment, with any redirect and everything after it dropped.
segment="${CMD%%[;&|<>]*}"
# A trailing file-descriptor number belongs to the redirect, as in `2>`.
segment="${segment%%[[:space:]][0-9]}"
# Trim surrounding whitespace.
segment="${segment#"${segment%%[![:space:]]*}"}"
segment="${segment%"${segment##*[![:space:]]}"}"
[ -z "$segment" ] && exit 0

read -r first rest <<<"$segment"

interpreter=""
case "$first" in
  bash|sh|zsh|python3|ruby|node)
    interpreter="$first"
    read -r first rest <<<"$rest"
    ;;
esac

# Only a path can be an alternative spelling of a granted path.
case "$first" in
  */*) ;;
  *) exit 0 ;;
esac

# Reduce to a path relative to the cwd.
if [[ "$first" == /* ]]; then
  case "$first" in
    "$CWD"/*) rel="${first#"$CWD"/}" ;;
    *) exit 0 ;;
  esac
else
  rel="${first#./}"
fi

[ -f "$CWD/$rel" ] || exit 0
if [ -n "$interpreter" ] && [ ! -x "$CWD/$rel" ]; then
  exit 0
fi

patterns=$(
  for file in "$USER_SETTINGS" "$PROJECT/.claude/settings.json" "$PROJECT/.claude/settings.local.json"; do
    [ -f "$file" ] || continue
    jq -r '.permissions.allow[]? | select(startswith("Bash(") and endswith(")")) | .[5:-1]' "$file" 2>/dev/null
  done
)
[ -z "$patterns" ] && exit 0

# granted <string> — does any allow pattern match it?
granted() {
  local subject="$1" pattern base
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    [[ "$pattern" == \** ]] && continue
    if [[ "$pattern" == *":*" ]]; then
      base="${pattern%:\*}"
    elif [[ "$pattern" == *" *" ]]; then
      base="${pattern% \*}"
    else
      # The pattern is deliberately unquoted: it is a glob.
      [[ "$subject" == $pattern ]] && return 0
      continue
    fi
    [[ "$subject" == $base ]] && return 0
    [[ "$subject" == $base\ * ]] && return 0
  done <<<"$patterns"
  return 1
}

if [ -n "$rest" ]; then
  args=" $rest"
else
  args=""
fi

granted "$segment" && exit 0

for candidate in "./$rel$args" "$rel$args"; do
  [ "$candidate" = "$segment" ] && continue
  if granted "$candidate"; then
    echo "invoke-form-guard: blocked \`$segment\`. That script is allowlisted as \`$candidate\`, and allow rules match the literal command string, so this spelling would prompt for a command the repo already grants. Run \`$candidate\` instead, with any redirect or pipe kept as it was. See tool-and-shell-safety.md, \"Invoke a project script by the relative path its allow rule names\"." >&2
    exit 2
  fi
done

exit 0
