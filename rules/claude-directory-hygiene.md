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

Anything written to feed a single command — a commit message, a PR body, an issue body —
goes in `.claude/scratch/`, not at top level, unless the user will open and act on it
directly (`long-form-output.md` governs that call). Live PR bodies are the common
exception worth hoisting, since they get re-read and re-edited across a PR's life; a
`pr-bodies/` subdirectory serves them better than the top level does.

When a project's `.claude/` grows a directory its layout section doesn't mention, add the
line rather than leaving the reader to infer what the directory is for.

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
