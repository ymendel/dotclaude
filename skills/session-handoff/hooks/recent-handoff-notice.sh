#!/usr/bin/env bash
# SessionStart hook: surface a reminder if a recent handoff exists in the project.
#
# Output is read by the harness as a system reminder. Stays silent when:
#  - .claude/handoffs/ does not exist
#  - no timestamped handoff was modified in the last 7 days
#
# Pairs with the session-handoff skill — the model can invoke /session-handoff
# to resume from the surfaced handoff.

set -e

HANDOFF_DIR=".claude/handoffs"
[ -d "$HANDOFF_DIR" ] || exit 0

# Most recent handoff modified within the last 7 days.
#
# The glob is load-bearing, not cosmetic: `sort -r` orders lexically, which only
# matches chronological order while every candidate carries the same fixed-width
# YYYY-MM-DD-HHMMSS prefix. Don't relax it. See references/setup.md.
RECENT=$(find "$HANDOFF_DIR" -maxdepth 1 \
  -name '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]-*.md' \
  -mtime -7 -type f 2>/dev/null \
  | sort -r \
  | head -1)

if [ -n "$RECENT" ]; then
  echo "session-handoff: Before responding to the user, surface the recent handoff at $RECENT (within last 7 days) and ask whether to resume — unless the first message already answers that (e.g. 'resume'/'continue' -> resume directly; an explicit 'start fresh' -> skip). The 'don't judge from the prompt alone' guard is against inferring a decline from an unrelated-looking prompt, not against honoring an explicit instruction."
fi

exit 0
