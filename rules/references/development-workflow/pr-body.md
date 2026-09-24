# Writing a pull request body

Companion to `development-workflow.md`'s *Pull Requests*, which carries the directives. This carries
the reasoning behind the three that are consulted only while composing or editing a body. Load it
when writing one, or when a body mentions an issue it must not close.

Everything here presumes a PR is the right artifact at all. On a personally-owned repo it usually
isn't — the no-PR sub-bullet under *Version Control* governs that first.

## Why closing keywords belong on the PR and not on a commit

The user closes issues through the PR that merges the work, so the linkage belongs on that one
artifact. A commit-level `Closes` still fires on merge, but it scatters the trigger across commits,
where a squash- or rebase-merge can fire it at a moment the user didn't intend, or off a commit the
user hadn't tied to the issue.

A commit may still *reference* an issue for context — `part of #NN`, "see #NN" — just not carry the
closing keyword.

## The footer block, and why it is a discipline rather than a guarantee

Keep intended closing keywords in a footer at the end of the body, one issue reference per line
(`Closes #NN`), set off from the prose above by a blank line. GitHub needs a keyword before *each*
reference, so a list under a single `Closes` closes only the first.

Then grep the body before finalizing and confirm every keyword-plus-number hit sits in that footer
and is intended. For any issue the PR should *not* close, use a non-keyword verb: `addresses #NN`,
`part of #NN`, `see #NN`.

The footer cannot enforce itself. A close fires on the pattern *anywhere* in the description,
explanatory prose about a different PR included, which is exactly how an issue gets marked done by a
sentence that was describing something else. `issue-closing-keywords.md` beside this file carries the
verb families and the grep.

## Why a blocking dependency is a pointer and never a status

`Depends on <bare URL>` — the upstream PR, the issue, the deploy's own run or release — and stop.

The pull is to explain the block instead, because the reason feels like the useful part: which tier
is behind, what has and hasn't merged, which job did or didn't run, how the reviewer should confirm
it. All of that is a dead copy of a live surface, and it rots in the one direction that misleads. The
dependency clears, the prose still says it hasn't, and nobody edits a PR body to retract a block. A
link is the only form that stays true, because the thing it points at reports its own state.

**Where the snapshot genuinely wants recording, an ADR is where it stays true.** The difference
between the two destinations is liveness, not importance. An ADR is dated by construction and read as
what held when the decision was taken, so the sequencing and the reason the block existed are as
accurate in ten months as on the day. A PR body is read as *current* right up to merge and then
becomes history with nobody editing it, so the identical paragraph inverts from true to false at a
moment nothing marks.

**The one durable addition is a second condition the linked artifact does not itself carry**: a data
migration that has to have run and not merely shipped, an approval outside the repo, an ordering
constraint between two upstreams. Say that, because a reviewer following the link cannot infer it and
it can pass silently. Then name what settles it rather than reporting where it stands.

**Once it clears, the pointer degrades gracefully and a narration does not.** `Depends on <URL>` reads
as history a reader can follow, where "waits on the API reaching production" reads as a live block
that is simply false. So the correction on merge is nothing.

Failure mode all three prevent: the block clears or the issue closes itself, and a reviewer arriving
afterwards either acts on a constraint that no longer exists or stops trusting the body and re-checks
every claim in it — including the ones that were never about status.
