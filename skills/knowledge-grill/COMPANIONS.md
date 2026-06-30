# Companion Infrastructure

What `knowledge-grill` depends on beyond the skill directory itself. The skill works standalone — it
fires by description-match and runs the interview on demand. But the behavior that makes it fire
*proactively*, before anyone thinks to ask, lives in a rule file the skill cannot carry.

## Why this file exists

A skill packages as a self-contained directory and can be installed many ways — a personal config
repo, a marketplace skill. But a rule loaded passively each session integrates with the host config
and does **not** ship with the skill package. Claude Code plugins and skill-only distributions
cannot carry `CLAUDE.md` or `rules/*.md` content; only the skill directory travels.

This file is the manual half: when you install `knowledge-grill`, this is the companion rule to set
up alongside it if you want the proactive behavior. Skip it and the skill still works when invoked
or when its description matches the conversation; adopt it and the grill gets suggested at the
moments it matters most.

## The companion rule: proactive firing

**Intent:** the model suggests a knowledge grill when knowledge is about to walk away — and ideally
*before* it does, while the holder is still around to be interviewed.

**Failure without it:** the highest-stakes extraction is exactly the one that gets deferred. Tacit
knowledge walks out the door because the grill waited for someone to remember it, and by the time
the handoff is written the person who held the why is already gone. Description-match alone fires
only when the conversation is *already about* leaving; it does not look up and notice the exit on
the horizon.

**Where it lives:** a rule in your own `~/.claude/rules/` (this repo keeps it at
`rules/knowledge-grill.md`), `@`-imported into `CLAUDE.md`. It is not part of the skill package and
is not synced with it.

**Sample wording** (paste into your own rule file and adjust):

> When an exit, handoff, or staffing change is on the horizon — not only the moment it happens —
> suggest a knowledge grill (the `knowledge-grill` skill) while the person who holds the context is
> still available to be interviewed. The value is highest *before* the holder leaves; a grill run
> after they are gone can only work from what survived in the code and docs.

## Trigger ideas beyond the exit case

The exit/handoff trigger is the first and highest-stakes one, but not the only plausible moment to
run a backward grill. See [TODO.md](./TODO.md) for triggers worth considering later — patterns of
tricky work, deviation from established norms, and others — deliberately kept out of the first
version of the rule.
