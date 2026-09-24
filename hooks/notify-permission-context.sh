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
# answering inside that window means no notification fires at all — which is the correct behavior
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

# THE SUGGESTIONS LOG answers the one question the descriptor below cannot. `permission_suggestions`
# is the only documented input field this hook does not read, and the open question is whether the
# MCP title the dialog shows ("honeycomb — Get Dataset Tool") rides in it — the tool name is all the
# descriptor has to work from, and it renders `calls: honeycomb get dataset` instead.
#
# A separate file from the descriptor record, deliberately. That one is per-session, overwritten by
# the next prompt, and deleted by the reader once used; this is append-only and nothing consumes it.
#
# EVERY parseable request is logged, including those carrying no suggestions, which record `null`.
# Logging only the ones that carry the field would leave a later absence ambiguous between "that
# tool never prompted" and "it prompted and carried nothing" — and distinguishing those two is the
# entire reason for the log.
#
# Growth is unbounded by decision rather than by oversight: these are log lines, and rotation is
# available if the size ever matters. Same call as `.notification-probe.jsonl`.
#
# Appended to a file, never printed. Emitting anything on stdout would make this observer a
# decision-maker, which is what the suite's silence assertions exist to catch.
SUGGESTIONS_LOG="${CLAUDE_PERMISSION_SUGGESTIONS_LOG:-$HOME/.claude/.permission-suggestions.jsonl}"

jq -c --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{at: $at,
      session_id: (.session_id // null),
      tool_name: (.tool_name // null),
      permission_suggestions: (.permission_suggestions // null)}' \
    <<<"$INPUT" >> "$SUGGESTIONS_LOG" 2>/dev/null

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
  mcp__*)
    # `mcp__<server>__<tool>`, per the hooks docs, which gloss these the way this renders them —
    # "Memory server's create entities tool" for `mcp__memory__create_entities`. The prompt dialog
    # shows a title the server advertises ("honeycomb — Get Dataset Tool"); that title is not in
    # this payload, so the name is all there is to work from.
    #
    # Split on the DOUBLE underscore. A plugin-sourced server carries single underscores inside its
    # own segment — `mcp__plugin_my-plugin_db__query` is the docs' own example — so splitting on `_`
    # would put the boundary in the wrong place and hand the tool half a piece of the server name.
    REST=${TOOL#mcp__}
    # Every claude.ai-hosted connector is named `claude_ai_<Name>`, so the prefix separates one from
    # none of the others and only takes up room. A plugin-sourced server carries `plugin_` for the
    # same reason and gets the same treatment — the two are the provenance, not the identity, and
    # the same vendor's tools arrive under both depending on how the server was installed.
    REST=${REST#claude_ai_}
    REST=${REST#plugin_}
    case "$REST" in
      *__*)
        # Both halves get underscores as spaces. Finding the boundary is what the `__` split is for;
        # it says nothing about how either side then reads, and leaving the server half verbatim
        # rendered the two sides in two different styles in one line.
        MCP_SERVER=${REST%%__*}
        MCP_TOOL=${REST#*__}
        # What is left of a plugin server is `<plugin>_<server>`, and a plugin serving a server of
        # its own name leaves that doubled — `plugin_figma_figma` renders "figma figma" otherwise.
        # Collapse only an exact repeat, which no real pair produces: `my-plugin_db` keeps both.
        #
        # This assumes the plugin's own name holds no underscore. Where one does,
        # `plugin_<name>_<server>` is genuinely ambiguous and nothing here can split it — the
        # descriptor degrades to an extra word rather than to a wrong one, which is why this is a
        # note and not a guard.
        case "$MCP_SERVER" in
          *_*)
            [ "${MCP_SERVER%%_*}" = "${MCP_SERVER#*_}" ] && MCP_SERVER=${MCP_SERVER%%_*}
            ;;
        esac
        DESCRIPTOR="calls: ${MCP_SERVER//_/ } ${MCP_TOOL//_/ }"
        ;;
      *)
        DESCRIPTOR="calls: ${REST//_/ }"
        ;;
    esac
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
