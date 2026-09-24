#!/usr/bin/env bash
# notify-session-attention.sh — Notification hook. Says which session wants you.
#
# Registered with no matcher, so every notification type reaches this script and the branching
# happens here. That is deliberate: a matcher on `permission_prompt` would silently drop any type
# Claude Code adds later, where a generic fallback surfaces it the first time it fires.
#
# The routing:
#   permission_prompt  → notify, "<project> · <what the prompt is for>", or "· needs a response"
#                        when notify-permission-context.sh left nothing to name. That script is the
#                        PermissionRequest half of this pair and its header carries why the work is
#                        split across two events.
#   idle_prompt        → silent. It is ~two thirds of all traffic and says only that a session
#                        finished and you have not typed since, which is not a call for attention.
#   anything else      → notify, naming the type, so an unfamiliar event is legible rather than
#                        dressed up as a permission prompt.
#
# "needs a response" rather than "needs permission": `permission_prompt` also covers
# `AskUserQuestion` and `ExitPlanMode`, which the docs class as tools that "require user
# interaction" and which Claude Code delivers through the permission flow. No sub-type separates a
# question from a gate — MCP elicitation got `elicitation_dialog` and `elicitation_url_dialog` of
# its own, and this did not — so any label naming permission is wrong for a share of the traffic.
#
# Every payload is appended to the log regardless of routing, including the silent ones. The type
# vocabulary is only partly observed — `permission_prompt` and `idle_prompt` seen, the elicitation,
# agent and quota families documented but never yet fired here — so the log is what will show the
# rest arriving. `notes/claude-code-notification-hooks.md` carries the full vocabulary and the
# timing rules.
#
# The label is `basename "$cwd"`. The payload carries no title and its `message` names no session,
# so the working directory is the only human-readable key available, and it matches what an editor's
# terminal tab already shows. Two sessions in one directory are indistinguishable here; `--name`
# fixes that for `claude agents` and `ListAgents` but does not reach this payload.
#
# Timing is not this script's to control. `permission_prompt` only fires once you have not typed for
# about six seconds, and `idle_prompt` about 60 seconds after a response — so the away-heuristic is
# already applied upstream, and a notification arriving means the gate was cleared.
#
# A desktop notification is the only channel there is. Marking the terminal tab instead would say
# *which* session, which this cannot — but no hook-reachable sequence moves Zed's tab label. Bell,
# OSC 0 and OSC 2 were each tried and measured; `notes/claude-code-notification-hooks.md` records
# what happened so it is not re-attempted.
#
# Delivery is `osascript`, which needs nothing installed.

# Overridable so a test run can be pointed at a scratch file rather than appending to the real log.
LOG="${CLAUDE_NOTIFY_LOG:-$HOME/.claude/.notification-probe.jsonl}"
SOUND="Submarine"   # blank for silent notifications

# A hook must not print. osascript's own chatter would land in the session, so it is discarded —
# the log is the record of what fired.
#
# TODO: prefer terminal-notifier when it is present, keeping this osascript path as the fallback so
# a machine that lacks it still notifies. Two reasons, in order.
#
# It carries its own bundle, so it gets its own System Settings > Notifications entry — its own
# alert style, icon, and Focus behavior. osascript is unbundled and attributed to
# com.apple.ScriptEditor2, so the only way to make these notifications persist rather than
# auto-dismiss is to set *Script Editor*'s Alert Style to Persistent, which catches every unbundled
# `display notification` on the machine. A separate entry is a setting you can aim.
#
# Its Notification grouping also keys on the app, so every session stacks under one Script Editor
# group — the wrong key, since the thing worth separating is the project.
#
# And `-group` replaces an earlier notification carrying the same group id, so grouping by project
# means a session's second prompt supersedes its first instead of stacking.
#
# Its click actions are not a reason: they can focus an editor but not a terminal tab inside it.
# Install is `brew install terminal-notifier`, and the Brewfile line belongs in dotfiles rather than
# here, being machine setup rather than Claude config.
notify() {
  local title=$1 body=$2
  if [ -n "$SOUND" ]; then
    osascript \
      -e 'on run argv' \
      -e 'display notification (item 1 of argv) with title (item 2 of argv) sound name (item 3 of argv)' \
      -e 'end run' \
      "$body" "$title" "$SOUND" >/dev/null 2>&1
  else
    osascript \
      -e 'on run argv' \
      -e 'display notification (item 1 of argv) with title (item 2 of argv)' \
      -e 'end run' \
      "$body" "$title" >/dev/null 2>&1
  fi
}

INPUT=$(cat)

[ -z "$INPUT" ] && exit 0

if ! command -v jq &>/dev/null; then
  # Consistent with the other hooks: without jq we cannot parse the input, so pass through.
  exit 0
fi

# -c keeps one payload per line. A malformed payload is the interesting case rather than one to
# discard, so record the bytes as they arrived and stop — there is nothing to route on.
if ! STAMPED=$(jq -c --arg received_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '. + {received_at: $received_at}' <<<"$INPUT" 2>/dev/null); then
  printf 'UNPARSED %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$INPUT" >> "$LOG"
  exit 0
fi

printf '%s\n' "$STAMPED" >> "$LOG"

NOTIFICATION_TYPE=$(jq -r '.notification_type // empty' <<<"$INPUT")
CWD=$(jq -r '.cwd // empty' <<<"$INPUT")
SESSION=$(jq -r '.session_id // empty' <<<"$INPUT")

# Without a type there is nothing to route on, and without a cwd there is no label worth showing.
[ -z "$NOTIFICATION_TYPE" ] && exit 0
[ -z "$CWD" ] && exit 0

PROJECT=$(basename "$CWD")

# Reads and consumes what notify-permission-context.sh left for this session, echoing a descriptor
# or nothing. Consuming is what keeps the directory bounded: a record is written per prompt but read
# at most once, so what accumulates is one file per session whose prompt went unanswered past the
# six-second gate, and the next prompt in that session overwrites it.
#
# The staleness window rejects a record left by a prompt that was answered promptly — no
# notification fires inside six seconds, so that file is still sitting there when a later prompt
# notifies without having written one. The only prompt that reaches here without a record is a
# sandboxed command's network request, which PermissionRequest does not fire for.
consume_context() {
  local dir="${CLAUDE_PERMISSION_CONTEXT_DIR:-$HOME/.claude/.permission-context}"
  local file="$dir/$SESSION" written descriptor

  [ -n "$SESSION" ] || return 0
  [ -f "$file" ] || return 0

  read -r written descriptor < "$file"
  rm -f "$file"

  # A record whose first field is not a number is not one of ours; treat it as no record at all.
  case "$written" in
    '' | *[!0-9]*) return 0 ;;
  esac

  [ $(($(date -u +%s) - written)) -le 60 ] || return 0
  printf '%s' "$descriptor"
}

case "$NOTIFICATION_TYPE" in
  idle_prompt)
    exit 0
    ;;
  permission_prompt)
    CONTEXT=$(consume_context)
    notify "$PROJECT" "${CONTEXT:-needs a response}"
    ;;
  *)
    notify "$PROJECT" "$NOTIFICATION_TYPE"
    ;;
esac

exit 0
