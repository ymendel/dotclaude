# Probing Whether a Command Prompts

> Not loaded in context by default. See `rules/diagnosis.md` for behavioral guidance.

## The four outcomes, and which leave a trace

| Outcome | Trace |
|---|---|
| Rejected | an explicit error in the tool result |
| Approved with "don't ask again" | a new entry in the repo's `.claude/settings.local.json` |
| Approved with a plain "Yes" | nothing |
| Auto-allowed | nothing |

The blind spot is one pair — plain-Yes and auto-allow — and they are the two that matter when the
question is whether a config change suppressed a prompt. A saved rule is therefore a **one-way
detector**: its presence proves a prompt happened, and its shape shows what string the gate matched;
its absence proves nothing. The session transcript holds no per-call record either, only the
session's own `permissionMode`.

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

This does not reopen the plain-Yes blind spot above. `PermissionRequest` separates *prompted* from
*never going to prompt*; it still says nothing about which answer the user gave.

## Shaping a probe that attributes cleanly

One command, with no pipe, redirect, or command substitution. Claude Code evaluates each segment of a
compound command independently, so a pipeline leaves any prompt unattributable to the command under
test — and an expansion cannot be matched against an allow rule at all, so it prompts for its own
reasons (see `rules/settings.md`).
