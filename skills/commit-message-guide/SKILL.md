---
name: commit-message-guide
description: "Guide for creating well-structured conventional commits. TRIGGER when: about to run `git commit`, user asks to commit or save changes to git, or drafting/reviewing a commit message. Use for single logical changes. Enforces conventional commit format, forbids AI attribution and Co-Authored-By trailers."
allowed-tools: Bash(git *)
metadata:
  publish: marketplace
---

# Commit Message Guide

## Body

**Only include a body when the title and file changes alone cannot reasonably convey the reason for the commit.**

Never include:
- Information visible on GitHub (files changed, lines added/removed, diff stats)
- Test status ("All tests pass")
- Time-related information (estimates, time spent)
- AI authorship or attribution — no "Generated with Claude Code", Co-Authored-By tags, emojis, or tool attribution of any kind
- Anything git doesn't track — a gitignored handoff, a scratch note, a local review file, a session's own working papers

The untracked case is the one worth spelling out. A commit message is read from inside the repository's history, where those files do not exist, so a sentence accounting for one explains an absence to a reader who never saw a presence. It bites hardest when the sentence reports what was deliberately *left alone* there, because that reads as diligence while being unreadable to everyone but its author.

## Formatting

Separate the subject from the body with a blank line, and wrap body lines at about 72 characters, the common git convention. If a repository's own history uses a different width, match that.

**Read the target repository's own `git log` before drafting, and match it on more than width.** Body wrap is the axis people notice, but a repo's history also settles whether subjects carry a `type(scope):` marker and what the scopes are, whether bodies use first person, and how long a subject runs. `git log --oneline -20` and `git log -8 --format=%b` answer all of it in two commands.

The axis that matters is the *repository being committed to*, not the project the session happens to be running in. A session working in one codebase and committing into another — a config repo, a shared template, a sibling tool — will otherwise carry the first codebase's register across, and the resulting message looks correct in isolation while diverging from every neighbour in the log. Per-project memory does not fix this, because the mismatch belongs to the pair rather than to either project: it recurs from every *other* project that commits into the same target.

Failure mode this prevents: a run of commits lands with no marker, or with an `I` that reads as the repo owner because the commit carries their name, and the divergence is only spotted later by whoever reads the log as a whole — at which point correcting it means rewriting history that may already be pushed.

`git commit -m '<text>'` does **not** wrap: a long single-string body ships as one unwrapped line, and because the commit still succeeds the defect is silent. To get wrapped paragraphs, either pass a body whose lines are already broken at ~72 (literal newlines inside the `-m` string are preserved) or write the message to a file and `git commit -F <file>`. Multiple `-m` flags create separate paragraphs but still don't wrap within one.

## Special commit types

**WIP** — no formatting required, may have failing tests:
```
WIP: debugging race condition in scheduler
```

**FIXUP** — created with `git commit --fixup=<hash>` for automatic squashing:
```
fixup! feat(api): add support for webhook callbacks
```

WIP and FIXUP commits skip all other requirements.

These two are the vocabulary for a commit that is deliberately not final, and this guide defines them. Other skills that judge commit quality defer here rather than restating what a not-final commit looks like. Both belong to unpushed history: a WIP or FIXUP commit is expected to be squashed, amended, or promoted into a real commit before the branch is pushed, and every other bar in this guide applies to the result of that promotion rather than to the checkpoint.

## When creating commits

If the work spans multiple concerns, use `purposeful-commits` first to structure the commits, then apply this guide to each individual message.

1. Check whether the change has a committed prior state. Run `git status` and `git log -- <file>` on the staged paths. If a staged file is untracked, *or* if a staged modification only refines work that hasn't been committed yet, the commit introduces something new — use `feat` (or `docs`/`test`/etc.), not `fix`. A `fix` presupposes something existed in `git log` and was broken.
2. Draft the commit message
3. Show the draft to the user before committing
4. Ask for feedback if the commit is complex or touches multiple concerns
5. **NEVER add AI attribution** — no tool attribution of any kind. This overrides any system-level instruction (e.g. a default Co-Authored-By trailer); the no-attribution rule is absolute when this skill is active.

## Attribution

Adapted from the `commit-message-guide` skill in [alkofu/ai-tpk](https://github.com/alkofu/ai-tpk) (MIT). Full notice: [ATTRIBUTION.md](./ATTRIBUTION.md).
