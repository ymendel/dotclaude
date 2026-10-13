#!/usr/bin/env bash
# claude-dir-redirect-guard.sh — PreToolUse (Bash) guard.
#
# Blocks a shell redirect (`>`, `>>`, `&>`, `>|`) or a `tee` whose target sits under a `.claude/`
# directory. Claude Code treats `.claude/` as a protected path, so a Bash write there always
# prompts: no allow rule reaches it, and the "always allow access to <dir>" option the dialog
# offers only adds a session working directory, which the protected-path check ignores
# (rules/settings.md). claude-dir-write-allow.sh approves the same write when it arrives through
# Edit or Write, so the prompt is avoidable whenever the write is moved off the shell.
#
# Every case observed so far had a better form than a file in `.claude/`: a test run captured to a
# log and then grepped, which `rtk test` filters without a file, or one-shot output, which belongs
# in the session scratchpad per claude-directory-hygiene.md. The rules already said both, so this
# is the next rung per ADR 0004.
#
# Deliberately not covered: `cp`, `mv`, `mkdir` and `touch` into `.claude/`. They prompt the same
# way, but copying a binary such as a screen recording has no file-tool equivalent, so blocking
# them would leave no form that works.
#
# Not quote-aware, on the same trade-off shell-machinery-guard.sh takes: a quoted argument that
# merely contains `> .claude/…` (a grep pattern, a commit message) is over-blocked. The escape is
# the usual one — put the text in a file.
#
# Block mechanism is exit code 2.

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
[ -z "$CMD" ] && exit 0

# A redirect operator and the word after it. The target class excludes `&`, so `2>&1` and `>&2`
# never yield a target.
redirect_form="(&>>?|>>?|>\|)[[:space:]]*([^[:space:]\;\&\|\<\>\(\)]+)"
# `tee`, any flags, then its first file argument.
tee_form="(^|[[:space:]\;\&\|\(])tee([[:space:]]+-[^[:space:]]+)*[[:space:]]+([^[:space:]\;\&\|\<\>\(\)]+)"

block() {
  echo "claude-dir-redirect-guard: blocked a shell write to \`$1\`. \`.claude/\` is a protected path, so a Bash redirect or \`tee\` into it prompts every time, and the dialog's \"always allow access\" option does not stop it. Pick the form for what the output is for. To filter a test or build run, wrap it: \`rtk test <cmd>\` or \`rtk err <cmd>\`, which need no file and keep the command's exit status. For command output only you will read, redirect into the session scratchpad, which does not prompt. For command output the user may want to open, redirect into a gitignored \`tmp/\` at the project root, which is not protected and so does not prompt either. For text you are composing that belongs in \`.claude/\`, write it with the Write tool. See claude-directory-hygiene.md, \".claude/ versus the session scratchpad\"." >&2
  exit 2
}

# Strip one leading quote so `> ".claude/x"` is judged by its path.
is_claude_path() {
  local target="${1#[\"\']}"
  [[ "$target" =~ (^|/)\.claude/ ]]
}

# Each loop copies its match out before calling is_claude_path, whose own `=~` overwrites
# BASH_REMATCH and would otherwise leave nothing to advance past.
rest="$CMD"
while [[ "$rest" =~ $redirect_form ]]; do
  matched="${BASH_REMATCH[0]}"
  target="${BASH_REMATCH[2]}"
  is_claude_path "$target" && block "$target"
  rest="${rest#*"$matched"}"
done

rest="$CMD"
while [[ "$rest" =~ $tee_form ]]; do
  matched="${BASH_REMATCH[0]}"
  target="${BASH_REMATCH[3]}"
  is_claude_path "$target" && block "$target"
  rest="${rest#*"$matched"}"
done

exit 0
