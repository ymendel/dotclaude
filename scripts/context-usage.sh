#!/usr/bin/env bash
# Report how full this session's context window is, on demand.
#
# hooks/context-usage-notice.sh reports the same number automatically, but only when a
# band is crossed. This is the deliberate read for when judgment says the number is worth
# knowing at a moment the bands do not cover — deep into a multi-file refactor at 40%,
# where resuming cold would be disorienting long before the window is full.
#
# The reading comes from ~/.claude/.context-usage/<session_id>, written by
# statusline-command.sh on every render. Reports only — never edits, never fails.
#
# Identifying the session is the one soft spot. A Bash invocation is not given the session
# id the way a hook is, so this matches on the working directory the statusline recorded
# and takes the most recent reading. Two sessions in the same directory cannot be told
# apart, and that case is reported rather than resolved silently.

CACHE_DIR="$HOME/.claude/.context-usage"

if [ ! -d "$CACHE_DIR" ]; then
  echo "No reading available. The statusline has not written one yet."
  exit 0
fi

# Collect readings whose recorded CWD matches this one, newest first. The .bands files
# beside them are hook state, not readings.
matches=()
while IFS= read -r file; do
  case "$file" in
    *.bands) continue ;;
  esac
  recorded_cwd=$(grep '^CWD=' "$file" | cut -d= -f2-)
  [ "$recorded_cwd" = "$PWD" ] && matches+=("$file")
done < <(ls -t "$CACHE_DIR" 2>/dev/null | sed "s|^|$CACHE_DIR/|")

scope="this directory"
if [ ${#matches[@]} -eq 0 ]; then
  # Nothing recorded for this directory. Fall back to the newest reading anywhere and say
  # so, rather than reporting a figure from another project as though it were this one.
  while IFS= read -r file; do
    case "$file" in
      *.bands) continue ;;
    esac
    matches+=("$file")
  done < <(ls -t "$CACHE_DIR" 2>/dev/null | sed "s|^|$CACHE_DIR/|")
  scope="another directory"
fi

if [ ${#matches[@]} -eq 0 ]; then
  echo "No reading available. The statusline has not written one yet."
  exit 0
fi

reading="${matches[0]}"
pct=$(grep '^CONTEXT_PCT=' "$reading" | cut -d= -f2)
tokens=$(grep '^CONTEXT_TOKENS=' "$reading" | cut -d= -f2)
size=$(grep '^CONTEXT_SIZE=' "$reading" | cut -d= -f2)
stamp=$(grep '^TIMESTAMP=' "$reading" | cut -d= -f2)

# Checked per field rather than over the four concatenated. An absent field contributes an empty
# string, so `42` + `` + `` + `<stamp>` stays all digits and passes a combined test — then reports
# "0K of 0K tokens" as though it were a reading. The field boundaries are what carry the
# information, and joining the values throws them away.
all_numeric() {
  local value
  for value in "$@"; do
    case "$value" in
      '' | *[!0-9]*) return 1 ;;
    esac
  done
  return 0
}

if ! all_numeric "$pct" "$tokens" "$size" "$stamp"; then
  echo "The most recent reading is malformed. Delete $reading and let the statusline rewrite it."
  exit 0
fi

age=$(($(date +%s) - stamp))
printf 'Context usage: %s%% (%sK of %sK tokens), recorded %ss ago.\n' \
  "$pct" "$((tokens / 1000))" "$((size / 1000))" "$age"

if [ "$scope" = "another directory" ]; then
  echo "Note: no reading for $PWD. This one is from $(grep '^CWD=' "$reading" | cut -d= -f2-)."
elif [ ${#matches[@]} -gt 1 ]; then
  echo "Note: ${#matches[@]} sessions have run in this directory. Showing the most recent reading."
fi

# The figure only grows within a session, so an old reading under-reports rather than
# over-reports. Worth saying when it is old enough to matter.
if [ "$age" -gt 300 ]; then
  echo "That reading is over five minutes old, so treat it as a floor."
fi

exit 0
