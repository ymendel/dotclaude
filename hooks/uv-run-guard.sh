#!/usr/bin/env bash
# uv-run-guard.sh — PreToolUse (Bash) security guard.
#
# NOTE: that allowlist entry is currently DEAD and the validator prompts every
# run. RTK rewrites `uv run …` to `rtk uv run …` (exit 3 = rewrite-and-prompt,
# not passthrough — see rules/RTK.md), so the gate never sees a bare `uv` and a
# bare `Bash(uv run …)` pattern cannot match. Making it live means respelling the
# entry with the `rtk ` prefix, which is a deliberate security decision, not a
# typo fix: it converts a grant that never fires into one that does, opening
# exactly the surface this guard exists for. Decide it when the validator's
# prompting is actually in the way. Everything below still works either way —
# the regex matches `uv run -` in the rewritten string too.
#
# The allowlist entry is intended to auto-approve
# `uv run *skills/skill-architecture/scripts/*.py*`
# so the skill validator runs without a prompt. But `uv run` accepts options
# BEFORE the script path — --with / --with-requirements / --index-url / --python,
# etc. — that fetch and execute arbitrary code (install a hostile package, or
# redirect the script's own declared deps to a malicious index). A leading-`*`
# allowlist glob cannot exclude those options.
#
# This hook enforces the safe shape: when a `uv run` command targets one of the
# auto-allowed scripts, the first token after `uv run` must be the script path,
# not an option. Any option before the path is a hard block via exit code 2,
# which takes precedence over the allow rule (a JSON permissionDecision of
# "deny" would NOT — it loses to a matching allow rule; only exit 2 blocks).
# uv's own options must precede the script, so anything after the path is the
# script's own args and stays safe.
#
# Scope: kept in sync with the `uv run *skills/skill-architecture/scripts/*.py*`
# allowlist entry in settings.json — including its spelling, per the note above.
# If that pattern broadens, or gains the `rtk ` prefix that would make it fire,
# broaden the path match below to match, or the guard will stop covering the
# surface the entry grants.

if ! command -v jq &>/dev/null; then
  # Consistent with the other Bash hooks: without jq we cannot parse the input,
  # so pass through. rtk-rewrite.sh already warns about a missing jq.
  exit 0
fi

INPUT=$(cat)
CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")

[ -z "$CMD" ] && exit 0

# Only concerned with `uv run` invocations that target the guarded skills scripts.
# The regex matches a `uv run` (at start or after whitespace, so it also catches
# occurrences inside a chain like `... && uv run ...`) immediately followed by a
# token that starts with `-` — i.e. a uv option sitting before the script path.
if [[ "$CMD" == *"skills/skill-architecture/scripts/"*".py"* ]] \
  && [[ "$CMD" =~ (^|[[:space:]])uv[[:space:]]+run[[:space:]]+- ]]; then
  echo "uv-run-guard: blocked. A \`uv run\` command targeting a skill-architecture script has an option before the script path. Options like --with / --with-requirements / --index-url / --python can fetch and execute arbitrary code, and the allowlist only covers a bare \`uv run <skills-script> [script-args]\`. Re-run without any option before the script path, or approve a specific command explicitly." >&2
  exit 2
fi

exit 0
