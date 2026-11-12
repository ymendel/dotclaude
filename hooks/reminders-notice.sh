#!/usr/bin/env bash
# reminders-notice.sh — SessionStart hook. Surfaces dated reminders that have come due.
#
# Two sources, read by the one hook:
#   - a central file ($REMINDERS_FILE, default ~/.claude/reminders.json) for reminders that should
#     travel between machines. Each entry carries a `scope`: "global", or the name of a repo, matched
#     against the basename of the session's git toplevel (or of its directory outside a repo).
#   - the session's own <cwd>/.claude/reminders.json, for reminders about that repo alone. Entries
#     there need no `scope`, since the file's location already is one.
#
# Both share one shape:
#
#   {"reminders": [{"due": "2026-12-12", "scope": "dotclaude",
#                   "what": "Run the usage report", "see": "usage-data/review-history.md"}]}
#
# An entry surfaces once `due` is today or earlier, and keeps surfacing at each session start until
# its date is moved or the entry removed. That is how a reminder gets cleared — there is no state
# file. The notice asks for an offer rather than an action, per rule-maintenance.md's "offer a new
# mechanism before automating it".
#
# A reminder that cannot be read is reported rather than skipped. Silence is this hook's normal
# state, so a malformed file or entry that went quiet would look exactly like nothing being due.
#
# Dated reminders only. "Occasionally"-style nudges with no due date are not handled yet.
#
# REMINDERS_TODAY overrides today's date (YYYY-MM-DD), for the suite in hooks/test/run-session-start.sh.

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CWD=$(jq -r '.cwd // empty' <<<"$INPUT" 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"

CENTRAL="${REMINDERS_FILE:-$HOME/.claude/reminders.json}"
LOCAL="$CWD/.claude/reminders.json"
TODAY="${REMINDERS_TODAY:-$(date '+%Y-%m-%d')}"

TOPLEVEL=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)
REPO=$(basename "${TOPLEVEL:-$CWD}")

lines=()

# collect <file> <match-scope: yes|no> — append a line per due or unreadable reminder.
collect() {
  local file="$1" match_scope="$2" out
  [ -f "$file" ] || return 0
  if ! out=$(jq -r --arg today "$TODAY" --arg repo "$REPO" --arg scoped "$match_scope" '
      (.reminders // error("no reminders array"))
      | if type != "array" then error("reminders is not an array") else . end
      | .[]
      | if (.due | type) != "string" or (.due | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$") | not)
          or (.what | type) != "string"
          or ($scoped == "yes" and (.scope | type) != "string")
        then "unreadable entry: \(tojson)"
        elif $scoped == "yes" and .scope != "global" and .scope != $repo then empty
        elif .due <= $today then
          "due \(.due): \(.what)" + (if (.see | type) == "string" then " (see \(.see))" else "" end)
        else empty end
    ' "$file" 2>/dev/null); then
    lines+=("could not read $file — check it is valid JSON with a reminders array")
    return 0
  fi
  while IFS= read -r line; do
    [ -n "$line" ] && lines+=("$line")
  done <<<"$out"
}

collect "$CENTRAL" yes
collect "$LOCAL" no

[ "${#lines[@]}" -eq 0 ] && exit 0

text="reminders: these have come due. Mention them to the user on the first turn as offers, and don't act on one unless asked. Once one is done, move its due date or remove it from its file ($CENTRAL or $LOCAL)."
for line in "${lines[@]}"; do
  text+=$'\n'"- $line"
done

jq -n --arg text "$text" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $text}}'

exit 0
