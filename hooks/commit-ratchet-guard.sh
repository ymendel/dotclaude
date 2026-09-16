#!/usr/bin/env bash
# PreToolUse gate for ADR 0008's ratchet: a Tier 1 or Tier 2 unit gains test cases in the same
# change that introduces or modifies it. Blocks a `git commit` whose staged set includes a tiered
# source path without that unit's suite staged alongside it.
#
# Registered in this repo's `.claude/settings.json`, NOT the root settings.json. `~/.claude` is a
# symlink to this repo, so the root file is the user-level one and a gate there would fire on
# `git commit` in every project on the machine, blocking unrelated repos against this repo's tier
# table.
#
# EXIT 2 IS THE MECHANISM, not a JSON decision. `Bash(rtk git:*)` is allow-listed, and a matching
# allow rule beats a hook's JSON `deny` — only exit 2 stops the call before permission rules are
# evaluated. See rules/settings.md.
#
# SCOPE, and what it deliberately cannot do. It sees only commits made through the tool, so a commit
# from the user's own terminal is unaffected — which is the escape hatch by construction rather than
# by a bypass flag, since a change that genuinely needs no test is one its author can commit
# directly. `git commit <path>` and `-a` are not covered either; both are outside how this repo
# commits.
#
# STAGING MUST HAPPEN IN AN EARLIER TOOL CALL, and this is the sharp edge. PreToolUse fires BEFORE
# the command runs, so `git add X && git commit` reaches this hook with X not yet staged: the index
# is empty, the guard below returns 0, and the commit sails through. That was the repo's usual
# commit shape when this gate was written, which would have made it blind to almost every real
# commit while looking perfectly healthy. The answer is a workflow rule rather than shell parsing —
# stage in one call, commit in the next — recorded in development-workflow.md and asserted in the
# suite. Do not try to recover the staged set by parsing `git add` out of the command string; that
# is a parser problem feeding a blocking decision.
#
# AN UNTIERED PATH BLOCKS TOO, which is the half the ADR did not originally specify. Every unit
# added after the tier table was written failed to gain a row — three for three, across three
# sessions — so a gate that only checked known units would have stayed silent on exactly the units
# that go untested. A new file under a watched directory therefore has to be classified before it
# can land.
#
# The mapping below duplicates ADR 0008's table, which the ADR names as a known cost: the tiers
# become config in a second place, kept in agreement by attention alone. Change both together.
#
# Checks live in hooks/test/run-commit-ratchet.sh.

INPUT=$(cat)

if ! command -v jq &>/dev/null; then
  # No jq means no reliable read of the payload. Fail open rather than block every commit on a
  # machine missing a dependency this hook is not the point of.
  exit 0
fi

COMMAND=$(jq -r '.tool_input.command // empty' <<<"$INPUT" 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

# The `if` conditions in settings.json should mean only commits arrive, but the hook outlives its
# registration and a missed `if` would otherwise gate every Bash call.
case "$COMMAND" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# --- ADR 0008's tier table, as a mapping ------------------------------------
#
# Tier 1 and Tier 2 units, each paired with the suite it owes. A suite named here need not exist
# yet: the ratchet fires on the unit being *modified*, and demanding a suite that has to be written
# is the intended behaviour rather than a gap. Tier 3 units are exempt and simply absent.

TIERED=(
  "hooks/reflexive-cd-guard.sh|hooks/test/run-checks.sh"
  "hooks/shell-machinery-guard.sh|hooks/test/run-checks.sh"
  "hooks/uv-run-guard.sh|hooks/test/run-checks.sh"
  "hooks/python-rewrite.sh|hooks/test/run-checks.sh"
  "hooks/context-usage-notice.sh|hooks/test/run-stop.sh"
  "hooks/ensure-trailing-newline.sh|hooks/test/run-post-tool-use.sh"
  "hooks/notify-session-attention.sh|hooks/test/run-notification.sh"
  "hooks/claude-dir-write-allow.sh|hooks/test/run-permission-request.sh"
  "hooks/commit-ratchet-guard.sh|hooks/test/run-commit-ratchet.sh"
  "scripts/run-tests.sh|scripts/test/run-test-runner.sh"
  "scripts/measure-claude-dir-writes.sh|scripts/test/run-measure-writes.sh"
  "scripts/check-prerequisites.sh|scripts/test/run-prerequisites.sh"
  "scripts/compare-skills.sh|scripts/test/run-compare-skills.sh"
  "scripts/context-usage.sh|scripts/test/run-context-usage.sh"
  "scripts/rules-floor.sh|scripts/test/run-rules-floor.sh"
  "scripts/rules-sections.py|scripts/tests/"
  "scripts/session-meta-report.py|scripts/tests/"
  "scripts/sync-skill.sh|scripts/test/run-sync-skill.sh"
  "scripts/usage-report.sh|scripts/test/run-usage-report.sh"
  "test/_harness.sh|test/run-harness.sh"
)

# Tier 3 — thin wrappers and vendored code, exempt by the ADR's own reasoning.
EXEMPT=(
  "hooks/notify-config-update.sh"
  "hooks/rtk-rewrite.sh"
  "scripts/enospc-workaround.sh"
  "scripts/rules-floor.baseline"
)

# Directories whose contents must be classified before they can land. Kept narrow on purpose:
# skills/ has its own layout and the ADR tiers it as a group rather than per file.
WATCHED=("hooks/" "scripts/")

# --- Read the staged set ----------------------------------------------------

STAGED=$(git diff --cached --name-only 2>/dev/null)
[ -z "$STAGED" ] && exit 0

staged_has() {
  while IFS= read -r path; do
    [ "$path" = "$1" ] && return 0
  done <<<"$STAGED"
  return 1
}

# A python suite is named as a directory; any staged file beneath it satisfies the obligation.
staged_under() {
  while IFS= read -r path; do
    case "$path" in "$1"*) return 0 ;; esac
  done <<<"$STAGED"
  return 1
}

satisfied() {
  case "$1" in
    */) staged_under "$1" ;;
    *) staged_has "$1" ;;
  esac
}

missing=()
untiered=()

while IFS= read -r path; do
  [ -z "$path" ] && continue

  # A test file is never itself subject to the ratchet.
  case "$path" in
    */test/* | */tests/*) continue ;;
  esac

  is_exempt=false
  for exempt in "${EXEMPT[@]}"; do
    [ "$path" = "$exempt" ] && is_exempt=true && break
  done
  [ "$is_exempt" = true ] && continue

  matched=false
  for entry in "${TIERED[@]}"; do
    source_path="${entry%%|*}"
    test_path="${entry##*|}"
    if [ "$path" = "$source_path" ]; then
      matched=true
      satisfied "$test_path" || missing+=("$path -> $test_path")
      break
    fi
  done
  [ "$matched" = true ] && continue

  # Not tiered, not exempt. Block if it sits under a watched directory.
  for dir in "${WATCHED[@]}"; do
    case "$path" in
      "$dir"*)
        # Only executable-looking units, not READMEs or data files beside them.
        case "$path" in
          *.sh | *.py) untiered+=("$path") ;;
        esac
        break
        ;;
    esac
  done
done <<<"$STAGED"

[ "${#missing[@]}" -eq 0 ] && [ "${#untiered[@]}" -eq 0 ] && exit 0

# --- Block, and say what would clear it -------------------------------------

{
  echo "commit-ratchet-guard: blocked by ADR 0008's ratchet."
  echo ""

  if [ "${#missing[@]}" -gt 0 ]; then
    echo "These staged units are Tier 1 or Tier 2 and their suite is not staged with them:"
    for item in "${missing[@]}"; do echo "  $item"; done
    echo ""
    echo "A tiered unit gains cases in the same change that modifies it. Add or extend the"
    echo "suite named above and stage it, then run ./scripts/run-tests.sh before committing."
    echo ""
  fi

  if [ "${#untiered[@]}" -gt 0 ]; then
    echo "These staged files are not tiered and not exempt:"
    for item in "${untiered[@]}"; do echo "  $item"; done
    echo ""
    echo "Every unit added since ADR 0008's table was written failed to gain a row, so a new"
    echo "file has to be classified before it lands. Tier it by the ADR's axis — fires"
    echo "automatically or dense deterministic logic is Tier 1, deliberately run with real"
    echo "consequences is Tier 2, a thin wrapper or vendored code is Tier 3 — then add a row to"
    echo "the ADR table and a matching entry to this hook's TIERED or EXEMPT array."
    echo ""
  fi

  echo "If this change genuinely needs no test, commit it from your own terminal: this gate"
  echo "sees only commits made through the tool, which is the escape hatch by design."
} >&2

exit 2
