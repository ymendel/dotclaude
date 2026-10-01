#!/usr/bin/env bash
# broad-grant-notice.sh — PostToolUse (Bash) hook. Points out a broad allow entry right after one is
# written, so it gets looked at while the command that prompted it is still in view.
#
# The case it exists for is "Yes, and don't ask again" accepted in a hurry. The dialog builds its
# rule from the command's shape, so it routinely offers `<command> *` — a whole tool or interpreter —
# where the situation wanted `git grep:*` or `heroku releases:*`. Those broad grants are what the
# 2026-10-01 audit of every project's settings.local.json found piled up.
#
# WHY POSTTOOLUSE. ConfigChange looks like the natural event and does not fire for the dialog's own
# write — a logging hook saw Edit-tool changes to both settings files and nothing when the dialog
# wrote a grant (2.1.285). The grant is on disk before the approved command runs, so by the time
# PostToolUse fires for that same command, the new entry is there to find.
#
# WHAT IT DOES. Compares permissions.allow in the project's .claude/settings.local.json and in user
# settings against a snapshot from the previous call, then refreshes the snapshot. A file seen for
# the first time is seeded silently, so entries that were already there are never reported as new.
# For each new entry that is broad, it emits additionalContext naming the entry and the file. It
# never edits a settings file and never blocks — the notice is an offer, and whether to narrow the
# grant is the user's call (rule-maintenance.md, "Permissions Allow List").
#
# "Broad" is defined in hooks/lib/permission-rules.jq, shared with scripts/local-allow.sh. It is a
# heuristic, deliberately loose because a false notice costs one sentence of chat. If that file is
# missing the hook stays silent rather than guessing.
#
# Watches Bash calls only: the dialog writes broad rules for Bash, and checking on every call keeps
# the snapshot current enough that an Edit to a settings file is also caught on the next command.
#
# Checks live in hooks/test/run-broad-grant-notice.sh.

if ! command -v jq &>/dev/null; then
  # Consistent with the other hooks: without jq we cannot parse the input, so pass through.
  exit 0
fi

# comm needs both lists sorted the same way, and the snapshot may have been written under another
# locale.
export LC_ALL=C

INPUT=$(cat)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // empty' <<<"$INPUT")}"
SNAPSHOTS="$HOME/.claude/.grant-snapshots"

FILES=("$HOME/.claude/settings.json")
[ -n "$PROJECT_DIR" ] && FILES+=("$PROJECT_DIR/.claude/settings.local.json")

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
[ -f "$LIB_DIR/permission-rules.jq" ] || exit 0

mkdir -p "$SNAPSHOTS" 2>/dev/null || exit 0

NOTICES=()
for file in "${FILES[@]}"; do
  [ -f "$file" ] || continue

  # An unreadable or malformed file leaves its snapshot alone, so the entries it holds are not
  # mistaken for new ones once it parses again.
  current=$(jq -r '.permissions.allow // [] | .[]' "$file" 2>/dev/null) || continue
  current=$(printf '%s\n' "$current" | sort -u)

  key=$(printf '%s' "$file" | shasum | cut -c1-16)
  snapshot="$SNAPSHOTS/$key"

  if [ -f "$snapshot" ]; then
    added=$(comm -13 "$snapshot" <(printf '%s\n' "$current"))
  else
    added=""
  fi
  printf '%s\n' "$current" > "$snapshot"

  [ -n "$added" ] || continue
  broad=$(printf '%s\n' "$added" | jq -R . | jq -s -r -L "$LIB_DIR" 'include "permission-rules"; .[] | select(broad)')
  [ -n "$broad" ] || continue

  while IFS= read -r entry; do
    NOTICES+=("\`$entry\` in $file")
  done <<<"$broad"
done

[ "${#NOTICES[@]}" -gt 0 ] || exit 0

list=$(printf -- '- %s\n' "${NOTICES[@]}")
text="A broad permission grant was just written:
$list
Each grants a whole command or interpreter rather than one subcommand. Tell the user, propose the narrow entry built from the command that actually prompted, and ask before editing any settings file."

jq -n --arg text "$text" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $text}}'
exit 0
