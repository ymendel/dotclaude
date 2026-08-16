# `.claude/` Directory Hygiene

A project's `.claude/` accumulates two kinds of file, and only one of them is meant to
last. Durable material — declared notes destinations, handoffs, reviews, plans, config —
earns a permanent home. Transient material — a commit message written for `git commit -F`,
a PR body for `gh pr edit --body-file`, an issue draft for `gh issue create` — exists to
carry text into a tool and has no reason to survive the trip. Nothing distinguishes them
on disk, so the transient half silts up until someone notices the directory has become
unreadable.

## Where a file goes

Top level is for the curated set the project's own `CLAUDE.md` (or `.claude/CLAUDE.md`)
names: the declared notes destinations, the settings files, and the subdirectories.
Everything else goes in a subdirectory. A file that is neither named in that layout nor
inside one of its directories is the thing this rule exists to prevent.

Anything written to feed a single command and then discarded — a commit message, an issue
body, a PR body posted once — does not belong here at all. It goes in the session
scratchpad, for the reason the next section gives. What earns a place in `.claude/scratch/`
is material the user may want to open: a draft to read back, a working file whose
usefulness is not settled yet. Live PR bodies outgrow both, since they get re-read and
re-edited across a PR's life, so give them a `pr-bodies/` subdirectory.

When a project's `.claude/` grows a directory its layout section doesn't mention, add the
line rather than leaving the reader to infer what the directory is for.

## `.claude/` versus the session scratchpad

The session scratchpad is the model's working directory; `.claude/` is where the user can
reach a file. So the question is who will open it.

Anything the user will open and act on directly — a rebase message sheet, a command list,
anything they will paste or run from their own terminal — goes one step from the project
root, in `.claude/` or a gitignored `tmp/`. A deep `/private/tmp/claude-…/` path makes them
copy a long string just to see what they were handed.

When it isn't clear who the file is for, start it under `.claude/scratch/` anyway. Rescuing
a file *out* of the scratchpad is a chore that has to be remembered and mostly isn't, while
deleting one the user can see costs nothing. So only genuinely one-shot output — a commit
message, an issue body — stays in the scratchpad.

Failure mode this prevents: a file that only became worth keeping *after* it was written
evaporates with the session, or an artifact meant *for the user* lands where only the model
navigates comfortably and they are left asking "where is it?" before they can use it.

**A script you are about to run is not one-shot output, whatever its lifespan.** Its logic
*is* the work, and the command that runs it reaches the permission gate as an opaque
`python3 /private/tmp/claude-…/derive-thing.py` — a path and nothing else. The user is then
asked to approve a step whose substance they cannot see, which is not an approval. So write
any script under `.claude/scratch/` where they can open it, and say in the message what it
computes before running it. The same holds for a config, a fixture, or a filter list a
command reads: if the command's behaviour is decided by a file's contents rather than by
its own arguments, the file has to be reachable.

Failure mode this prevents: the reflex is to keep working files out of the project, which
is right for output and wrong for input — a hidden script converts a reviewable command
into an unreviewable one, and the user's only options are to approve blind or to stop the
work and ask what it does.

## What it gets named

Name the file for the work, not the tool: `commit-<slug>.txt`, `pr-body-<slug>.md`,
`issue-<slug>.md`. Never a sequence number keyed to a moment (`commit-1-message.txt`,
`pr-14-body.md`) — the moment passes, the number stops meaning anything, and nothing in
the name says whether the file is still live.

## When it gets deleted

**The trigger is that the content now lives somewhere permanent, not that time has
passed.** A commit message is dead the moment the commit lands, because `git log` holds it
verbatim. A PR body is dead when the PR merges, because GitHub holds the description. An
issue draft is dead when the issue is filed, unless it is deliberately kept as the source
to edit from — say so in the file itself if so.

Check this at the moment the content lands, which is the moment you know it landed. Delete
the file in the same breath as the commit, the merge, or the filing.

When cleaning up in bulk afterwards, prove the recoverability before deleting rather than
assuming it from the filename: open the ambiguous ones, confirm the commit subject appears
in `git log`, confirm the PR is merged. `.claude/` is gitignored in most setups, so a
wrong deletion here is not recoverable from the repo — the recoverability is entirely in
the external record you are relying on, and that claim is worth one command.

## Failure mode this prevents

Every task leaves two or three files behind and none of them announce that they are spent,
so the directory fills with dead PR bodies and commit messages whose commits merged months
ago. The cost is not disk — it is that the live artifacts stop being findable among them,
and that a reader can no longer tell which files the project actually depends on. By the
time it is obvious enough to clean up, the cleanup requires re-deriving what each file was
for, which is the work the delete-on-landing habit would have made unnecessary.
