#!/usr/bin/env bash
# How often does a Bash command write to a `.claude/` path, and is the traffic repetitive enough to
# be worth granting away?
#
# `.claude/` is a protected path: a write there prompts however the allow list is written, and only
# bypassPermissions or a PermissionRequest hook reaches it (rules/settings.md). A hook covering Bash
# would have to whitelist command shapes, which pays off only on repetitive traffic — so the
# distinct-strings line at the bottom decides the question, not the volume.
#
# Usage:
#
#   ./scripts/measure-claude-dir-writes.sh [--exclude-session <id>]
#
# Pass the current session's id to leave it out. A session that has been probing permissions writes
# to `.claude/` far more than a working one, and including it inflates the rate it is measuring.
#
# WHAT THIS COUNTS, and the judgment in it:
#
# - Only the **write** verbs below, plus shell redirects into a `.claude/` path. Only a write hits
#   the protected-path gate, so counting reads would fill the total with `rtk read` and `rtk grep`
#   calls that are allow-listed and were never gated.
# - The verb list is deliberately generous. Over-counting argues *for* building such a hook, so a
#   small or unrepetitive result is the trustworthy direction.
#
# WHAT IT CANNOT COUNT:
#
# - Whether any given command actually prompted. A transcript records the command, not the
#   permission outcome, and an auto-allowed call is byte-identical to an approved one. So the write
#   count is an UPPER BOUND on prompts.
# - Anything outside the retention window. Transcripts rotate after roughly 30 days, the same limit
#   usage-report.sh documents, so this is a current rate rather than a lifetime total.

set -o pipefail

PROJECTS="$HOME/.claude/projects"
EXCLUDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --exclude-session)
      EXCLUDE="$2"
      shift 2
      ;;
    *)
      echo "measure-claude-dir-writes: unknown argument '$1'" >&2
      exit 2
      ;;
  esac
done

if ! command -v jq &>/dev/null; then
  echo "measure-claude-dir-writes: jq is required." >&2
  exit 1
fi

if [ ! -d "$PROJECTS" ]; then
  echo "measure-claude-dir-writes: $PROJECTS not found." >&2
  exit 1
fi

WRITE_VERBS='rm|rmdir|mv|cp|touch|mkdir|ln|chmod|truncate|tee|install|sed'

total_bash=0
touching=0
writing=0
sessions_seen=0
sessions_with_writes=0
WRITES=$(mktemp)
BYPROJECT=$(mktemp)
trap 'rm -f "$WRITES" "$BYPROJECT"' EXIT

for transcript in "$PROJECTS"/*/*.jsonl; do
  [ -e "$transcript" ] || continue
  session=$(basename "$transcript" .jsonl)
  project=$(basename "$(dirname "$transcript")")
  [ -n "$EXCLUDE" ] && [ "$session" = "$EXCLUDE" ] && continue
  sessions_seen=$((sessions_seen + 1))

  # `-R` reads each line as a raw string and `fromjson?` yields nothing when it will not parse, so
  # one malformed line costs that line rather than the rest of the file. Passing the file as a JSON
  # *stream* instead — the obvious form — aborts jq on the first bad line, and since stderr is
  # discarded here the whole session's commands vanish with no sign. A transcript truncated
  # mid-write by a killed session is enough to trigger it.
  commands=$(jq -rR 'fromjson?
      | .message.content[]?
      | select(.type == "tool_use" and .name == "Bash")
      | .input.command' "$transcript" 2>/dev/null)
  [ -z "$commands" ] && continue
  total_bash=$((total_bash + $(printf '%s\n' "$commands" | grep -c '')))

  mentions=$(printf '%s\n' "$commands" | grep -F '.claude/')
  [ -z "$mentions" ] && continue
  touching=$((touching + $(printf '%s\n' "$mentions" | grep -c '')))

  writes=$(printf '%s\n' "$mentions" \
    | grep -E "(^|[|&;[:space:]])(${WRITE_VERBS})[[:space:]]|>[[:space:]]*[^[:space:]]*\.claude/")
  [ -z "$writes" ] && continue

  n_writes=$(printf '%s\n' "$writes" | grep -c '')
  writing=$((writing + n_writes))
  sessions_with_writes=$((sessions_with_writes + 1))
  printf '%s\n' "$writes" >> "$WRITES"
  # One line per write. Appending once per session made this table count sessions-with-writes while
  # reading as a write count, and its column then summed to the session total.
  for _ in $(seq "$n_writes"); do printf '%s\n' "$project" >> "$BYPROJECT"; done
done

printf 'Sessions scanned:                   %s\n' "$sessions_seen"
printf 'Bash calls in them:                 %s\n' "$total_bash"
printf 'mentioning a .claude/ path:         %s\n' "$touching"
printf 'of those, writing to one:           %s\n' "$writing"
printf 'sessions with any such write:       %s\n' "$sessions_with_writes"

if [ "$writing" -eq 0 ]; then
  exit 0
fi

printf '\nWrites per project:\n'
sort "$BYPROJECT" | uniq -c | sort -rn

# The crux. A whitelist is a bet on repetition, so report the whole distribution rather than a
# capped head — a cap here reads as the answer.
printf '\nDistinct command strings:           %s (of %s writes)\n' \
  "$(sort -u "$WRITES" | grep -c '')" "$writing"
printf 'Strings appearing more than once:    %s\n' "$(sort "$WRITES" | uniq -d | grep -c '')"
printf 'Compound (pipe, && , ; or redirect): %s\n' "$(grep -cE '\||&&|;|>' "$WRITES")"
printf 'Carrying a $ expansion:              %s\n' "$(grep -c '\$' "$WRITES")"

printf '\nThe repeated shapes, if any:\n'
sort "$WRITES" | uniq -cd | sort -rn | cut -c1-140
