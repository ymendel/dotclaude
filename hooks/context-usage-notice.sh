#!/usr/bin/env bash
# context-usage-notice.sh — Stop hook. Reports how full the context window is.
#
# The handoff triggers in rules/development-workflow.md were proxies for volume — edit
# counts, topic switches, "long enough that compaction is plausible" — because the actual
# number is not available to Claude. It is available to a statusline script, which gets
# input_tokens, cache_creation_input_tokens, cache_read_input_tokens and
# context_window_size. statusline-command.sh now writes the computed percentage to
# ~/.claude/.context-usage/<session_id>, and this reads it back.
#
# This hook states a fact and nothing else. What to do about the number is the rule's
# call, because fullness is not the same question as whether resuming cold would be
# disorienting — a 40% session mid-refactor may want a handoff more than an 80% session
# of question-and-answer. Encoding that judgment in a shell script would get it wrong in
# both directions.
#
# Stop is the right event on two counts, both verified against the hooks docs on
# 2026-09-10. It accepts hookSpecificOutput.additionalContext "for non-error feedback that
# continues the conversation", so the next turn can act on it. And its feedback "is shown
# in the transcript as hook feedback rather than a hook error", so the user can see every
# time it fires — which is what feedback.md's "offer a new mechanism before automating it"
# asks for, at no extra cost.
#
# Design notes:
#   - One notice per band, per session. State lives beside the cache in <session_id>.bands.
#     Firing every turn above a threshold would be nagging; firing once risks the single
#     notice landing in a turn nobody reads. Bands are the middle, and they are a guess
#     pending calibration.
#   - Only the highest newly-crossed band fires, so a jump from 55% to 85% emits once
#     rather than emitting for 60, 70 and 80 in a burst.
#   - A stale cache under-reports rather than over-reports, because context only grows
#     within a session. That is the safe direction, so a slightly old figure is still
#     worth reporting. Beyond CACHE_MAX_AGE the session has probably been idle and the
#     number says nothing useful, so it is skipped.
#   - On resume, Claude Code replays saved hook text for past turns rather than re-running,
#     so an old percentage sits in scrollback. Turns after the resume fire live.
#
# Covered by hooks/test/run-checks.sh's Stop-shaped sibling, hooks/test/run-stop.sh — a second
# harness, as the shape required: run-checks.sh passes command strings to a PreToolUse guard, and
# this reads session JSON and a cache file. It points HOME at a fixture so the percentages are
# known rather than whatever the running session is at. The malformed-cache and stale-cache paths,
# which had only ever been reasoned about, are exercised there — as is the corrupt-band-file
# recovery, whose failure mode is the worst available here: permanent silence in a hook whose
# normal state is silence.
#
# The full design, the open questions, and the calibration state live in a working note
# under ideas/, which is not tracked in this repo.

BANDS="60 70 80 90"
CACHE_MAX_AGE=1800

if ! command -v jq &>/dev/null; then
  # Consistent with the other hooks: without jq we cannot parse the input, so pass through.
  exit 0
fi

INPUT=$(cat)
SESSION_ID=$(jq -r '.session_id // empty' <<<"$INPUT")

[ -z "$SESSION_ID" ] && exit 0

CACHE_FILE="$HOME/.claude/.context-usage/$SESSION_ID"
BANDS_FILE="$HOME/.claude/.context-usage/$SESSION_ID.bands"

[ -f "$CACHE_FILE" ] || exit 0

CONTEXT_PCT=$(grep '^CONTEXT_PCT=' "$CACHE_FILE" | cut -d= -f2)
CONTEXT_TOKENS=$(grep '^CONTEXT_TOKENS=' "$CACHE_FILE" | cut -d= -f2)
CONTEXT_SIZE=$(grep '^CONTEXT_SIZE=' "$CACHE_FILE" | cut -d= -f2)
CACHE_TS=$(grep '^TIMESTAMP=' "$CACHE_FILE" | cut -d= -f2)

# Every field has to be a number before anything is reported. A partial or malformed cache
# should produce silence, not a notice built from an empty string.
#
# Checked per field rather than over the four concatenated. An absent field contributes an empty
# string, so `60` + `120000` + `` + `<stamp>` stays all digits and passes a combined test — then
# prints "of 0K tokens". The field boundaries are what carry the information, and joining the
# values throws them away.
for value in "$CONTEXT_PCT" "$CONTEXT_TOKENS" "$CONTEXT_SIZE" "$CACHE_TS"; do
  case "$value" in
    '' | *[!0-9]*) exit 0 ;;
  esac
done

[ $(($(date +%s) - CACHE_TS)) -gt "$CACHE_MAX_AGE" ] && exit 0

HIGHEST_FIRED=0
if [ -f "$BANDS_FILE" ]; then
  FIRED=$(cat "$BANDS_FILE")
  case "$FIRED" in
    '' | *[!0-9]*) HIGHEST_FIRED=0 ;;
    *) HIGHEST_FIRED=$FIRED ;;
  esac
fi

CROSSED=0
for band in $BANDS; do
  if [ "$CONTEXT_PCT" -ge "$band" ] && [ "$band" -gt "$HIGHEST_FIRED" ]; then
    CROSSED=$band
  fi
done

[ "$CROSSED" -eq 0 ] && exit 0

printf '%s\n' "$CROSSED" > "$BANDS_FILE"

TOKENS_K=$((CONTEXT_TOKENS / 1000))
SIZE_K=$((CONTEXT_SIZE / 1000))

jq -n \
  --arg text "Context usage: ${CONTEXT_PCT}% (${TOKENS_K}K of ${SIZE_K}K tokens)." \
  '{hookSpecificOutput: {hookEventName: "Stop", additionalContext: $text}}'

exit 0
