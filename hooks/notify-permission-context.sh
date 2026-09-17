#!/usr/bin/env bash
# notify-permission-context.sh — PermissionRequest hook. Records what the pending prompt is for, so
# notify-session-attention.sh can name it six seconds later.
#
# It decides nothing. A PermissionRequest hook grants or denies only through a `decision` object, so
# writing none leaves the permission flow exactly as it was — this is an observer wearing a
# decision-maker's event.
#
# WHY THIS EVENT rather than reading the transcript. The Notification payload carries
# `transcript_path`, and the pending call really is the last assistant `tool_use` with no
# `tool_result` — but the hooks docs say the transcript "is written asynchronously and may lag the
# in-memory conversation, so it may not yet include the current turn's most recent messages when a
# hook fires." Two samples here showed a five-to-seven second lead, which is a measurement rather
# than a guarantee. PermissionRequest carries `tool_name` and `tool_input` directly.
#
# WHY NOT NOTIFY FROM HERE. This event fires the moment Claude Code asks. The six-second
# no-typing gate that makes the notifications worth having lives on the Notification event, and
# answering inside that window means no notification fires at all — which is the correct behaviour
# and would be lost by notifying here.
#
# Registered with no matcher, so every tool reaches it. A matcher is a regex tested anywhere in the
# tool name (rules/settings.md), so there is no pattern for "all tools" short of omitting it.
#
# ONE GAP, by design upstream: this does not fire for a sandboxed command's network request, which
# the docs route to the `permission_prompt` notification type only. Those prompts still notify, just
# without a descriptor — the reader falls back to the generic label.
#
# Checks live in hooks/test/run-permission-request-context.sh.

CONTEXT_DIR="${CLAUDE_PERMISSION_CONTEXT_DIR:-$HOME/.claude/.permission-context}"

INPUT=$(cat)

# No jq, no parse, nothing to record. Abstaining is free here — the notification still fires, just
# generically — so there is never a reason for this hook to fail loudly.
command -v jq &>/dev/null || exit 0

jq -e . >/dev/null 2>&1 <<<"$INPUT" || exit 0

SESSION=$(jq -r '.session_id // empty' <<<"$INPUT")
TOOL=$(jq -r '.tool_name // empty' <<<"$INPUT")

# The session id is the key the reader looks up, so without it there is nowhere to put this. It also
# has to be a plain id rather than anything with a slash in it, since it becomes a filename.
[ -z "$SESSION" ] && exit 0
[ -z "$TOOL" ] && exit 0
case "$SESSION" in
  */* | . | ..) exit 0 ;;
esac

# The descriptor is read by a human off a desktop notification, so it names the thing rather than
# the field it came from. Tools not listed here fall through to their own name, which is already
# more than the generic label says.
case "$TOOL" in
  AskUserQuestion)
    # `header` is the short chip label, capped at ~12 chars by the tool's own schema, which is
    # exactly the length a notification wants. Falling back to the full question is worth it for a
    # caller that omitted the header.
    DETAIL=$(jq -r '.tool_input.questions[0].header // .tool_input.questions[0].question // empty' <<<"$INPUT")
    DESCRIPTOR="asks: ${DETAIL:-a question}"
    ;;
  ExitPlanMode)
    DESCRIPTOR="wants to leave plan mode"
    ;;
  Bash)
    DETAIL=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
    DESCRIPTOR="runs: ${DETAIL:-a command}"
    ;;
  Edit | Write | NotebookEdit)
    # NotebookEdit carries notebook_path where the other two carry file_path.
    DETAIL=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$INPUT")
    DESCRIPTOR="writes: ${DETAIL##*/}"
    [ -z "$DETAIL" ] && DESCRIPTOR="writes a file"
    ;;
  *)
    DESCRIPTOR="$TOOL"
    ;;
esac

# One line, so a newline inside a command or a question would make the reader see two records. Cut
# at the first newline and cap the length — a notification body truncates anyway, and the cap is
# what keeps a here-doc payload from writing kilobytes per prompt.
DESCRIPTOR=${DESCRIPTOR%%$'\n'*}
if [ "${#DESCRIPTOR}" -gt 80 ]; then
  DESCRIPTOR="${DESCRIPTOR:0:77}..."
fi

mkdir -p "$CONTEXT_DIR" 2>/dev/null || exit 0

# The epoch goes in the file rather than being read back off the mtime: the reader needs it to reject
# a stale record, and a field it can parse is testable with an invented fixture where an mtime is
# not. Overwrite rather than append — only the pending prompt matters, and the reader deletes the
# file once it has been used.
printf '%s %s\n' "$(date -u +%s)" "$DESCRIPTOR" > "$CONTEXT_DIR/$SESSION" 2>/dev/null

exit 0
