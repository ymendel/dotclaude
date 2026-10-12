# Probing Whether a Command Prompts

> Not loaded in context by default. See `rules/diagnosis.md` for behavioral guidance.

## The four outcomes, and which leave a trace

| Outcome | Trace |
|---|---|
| Rejected | a log entry, and an error in the tool result |
| Approved with "don't ask again" | a log entry, and a new rule in the repo's `.claude/settings.local.json` |
| Approved with a plain "Yes" | a log entry only |
| Auto-allowed | no log entry |

The log is `~/.claude/.permission-suggestions.jsonl`, written by `hooks/notify-permission-context.sh`
on `PermissionRequest`. Without it, plain-Yes and auto-allow both leave nothing — and they are the
pair that matters when the question is whether a config change suppressed a prompt. A saved rule alone
is only a one-way detector: its presence proves a prompt happened, its absence proves nothing.

An absent log entry is a negative only while the hook is alive. It exits silently without `jq`, and
it suppresses its own write errors, so confirm it with a recent entry from the same session before
reading a missing one as "auto-allowed".

The `PermissionRequest` payload carries no `tool_use_id`, so matching a log entry to a call goes by
session, tool and command text. A manual "No" fires neither `PostToolUse` nor `PermissionDenied`
(which runs only in auto mode), so no hook records it — the tool-result error is the only trace, and
it is visible from inside the session that ran the probe.

## The user's report carries the same skew

A plain "Yes" leaves nothing behind for the user either, so "I was only prompted once" over-weights
the prompts that offered a save. Treat a recollection as evidence with a known skew, and when the
answer matters, ask for a fresh probe rather than theorizing on the recollection.

## The notification is not the detector it looks like

A `Notification` hook on `permission_prompt` is the obvious instrument, because it observes without
needing the user to report anything. It is wrong in both directions.

**False positives.** The type covers more than a permission gate. `AskUserQuestion` and
`ExitPlanMode` are delivered through the permission flow — the hooks docs class them as tools that
"require user interaction" and say Claude Code offers them only where a permission host can receive
the prompt — so a multiple-choice question fires `permission_prompt` exactly as a gated `Bash` call
does. Nothing in the payload separates them, and no sub-type exists: MCP elicitation has
`elicitation_dialog` and `elicitation_url_dialog`, this has nothing. So a fired notification does not
establish that a command was gated.

**False negatives.** It fires only after about six seconds of not typing, each keystroke defers it,
and answering inside that window means it never fires at all. A probe run attentively is the case
least likely to produce the signal.

**`PermissionRequest` is the clean one.** The docs scope it to the moment Claude Code is about to
ask, it carries `tool_name` and `tool_input`, and a hook that returns no `decision` object leaves the
flow unchanged — so it observes without deciding. One exclusion: it does not fire for a sandboxed
command's network request, which reaches `permission_prompt` only.

`PermissionRequest` separates *prompted* from *never going to prompt*. It says nothing about which
answer the user gave, which is why the table above pairs it with the tool result and the saved rule.

**An MCP tool reaches it identically**, which the docs state rather than leave to inference: "MCP
server tools appear as regular tools in tool events (`PreToolUse`, `PostToolUse`,
`PostToolUseFailure`, `PermissionRequest`, `PermissionDenied`)". So probing an MCP call needs no
different instrument — `tool_name` carries `mcp__<server>__<tool>` like any other, and the payload
adds an `mcp_server` object on top.

What it does *not* carry is the title the dialog shows. A prompt reading "honeycomb — Get Dataset
Tool" is served by a payload holding only `mcp__honeycomb__get_dataset`, so anything rendering that
prompt from hook input is working from the name and will not match what the user saw. Whether the
title rides in `permission_suggestions` — the one documented input field not read for this — is
open, and the log records that field on every request so a single live MCP prompt settles it. The
field is not always the rule the dialog offers either: one prompt logged its exact command while the
dialog offered `git *`.

## Shaping a probe that attributes cleanly

One command, with no pipe, redirect, or command substitution. Claude Code evaluates each segment of a
compound command independently, so a pipeline leaves any prompt unattributable to the command under
test — and an expansion cannot be matched against an allow rule at all, so it prompts for its own
reasons (see `rules/settings.md`).
