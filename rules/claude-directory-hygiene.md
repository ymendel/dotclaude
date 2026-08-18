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

**Inlining the script with `-e` satisfies that paragraph and fails on two others.** A
`ruby -e '…'`, `python3 -c '…'` or `node -e '…'` carries its whole logic in the command
string, so the reviewability argument above is answered — which is exactly why the form
gets reached for, and why nothing in that paragraph fires on it. Two things still go wrong:

- **It cannot be granted, only re-approved.** The only entry that would cover an inline
  program is `Bash(ruby *)` — bare, since `RTK.md` lists these interpreters as passthrough —
  which is a standing grant to run arbitrary code in that language. So the choices are a
  prompt per invocation or an entry nobody should write, and the prompts arrive in a run of
  near-identical commands, which is the shape most likely to get the broad one added just to
  stop them. Same trap as `RTK.md`'s bare-`:` grant: the entry that would end the prompting
  is the one that must be declined.

  **A path-scoped entry is not the narrow alternative it reads as.**
  `Bash(ruby .claude/scratch/*)` constrains almost nothing, on three counts: writing the
  file it runs is itself granted, by `Edit(**/.claude/**)`; a Bash pattern matches the
  command *string* rather than a path (`settings.md`'s pattern-matching section), so
  `.claude/scratch/../../elsewhere.rb` satisfies it; and a Bash rule cannot be scoped to a
  project, so any repo shipping that path is covered, including code neither of us wrote.
  Against `settings.md`'s breadth test — how far a wrong invocation reaches — a general
  interpreter has no bounded area of effect at all. So prefer the file form for what the
  next bullet gives, and never on the grounds that the path makes it grantable.
- **Its logic is gone the moment it scrolls past.** An inline program is not re-runnable
  without retyping, has nowhere to put the judgement it encodes, and cannot be corrected —
  the retype is where the second version quietly differs from the first.

That second cost is worst when the program **produces a number that lands in a durable
artifact.** A figure in a note, a plan or an ADR carries an implicit claim that it can be
re-derived, and `honesty.md`'s *Re-query numbers at draft time* asks for exactly that
later. An inline one-liner voids it: the number survives, its derivation does not, and any
threshold or heuristic inside it — which is the part a reader would want to disagree with —
was never written down at all. Two runs of the "same" one-liner can then disagree without
anyone noticing which was wrong.

**How to apply.** Reach for `-e` only for something whose output is read once and decides
nothing that gets written down — a quick shape check, a one-off conversion. The moment a
program is worth running twice, encodes a judgement, or feeds a figure into prose, it is a
file under `.claude/scratch/` with its threshold stated in a header comment. Reference the
file by path where the figure lands, so the next reader can re-run it rather than trust it.

Failure mode this prevents: `-e` reads as the *more* transparent choice, so the drift into
it is invisible — the visible-logic argument is genuinely satisfied while the grant story
and the provenance story both quietly fail. The tell is having typed a near-identical
one-liner twice, or having just quoted its output into a document.

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
