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

## Shaping a probe that attributes cleanly

One command, with no pipe, redirect, or command substitution. Claude Code evaluates each segment of a
compound command independently, so a pipeline leaves any prompt unattributable to the command under
test — and an expansion cannot be matched against an allow rule at all, so it prompts for its own
reasons (see `rules/settings.md`).
