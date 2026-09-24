# Handing a Rule Edit to a Session in the Config Tree

Companion to `rule-maintenance.md`'s *Get it down first, refine later*. Load this when a rule or
skill edit originates outside the config tree and a peer session might land it — the moment the
handover has to be addressed, and who owns the commit, are decided here.

## Why message rather than commit

Peer sessions are listable with `ListAgents` and addressable with `SendMessage`, so an out-of-repo
edit can hand its context to a session already sitting in the config tree: what the edit is for,
the incident behind it, which parts were left rough.

That avoids the two options such an edit otherwise picks between. Committing the change from
outside invites an amend as soon as the wording gets reworked in the refinement pass. Loading the
rule prose with the dated incident and the provenance instead puts both in an always-loaded file,
which is what *Where dated observations go* routes away. A message carries both and lands neither.

## Ask what a session can reach, not where it sits

Read *either tree* literally. A private rule reached through the `rules/private` symlink is a rule
edit like any other, so the public repo's name is not what decides this.

**A listed name is not evidence of which tree a session sits in.** Names arrive from several
documented sources — a naming model working from conversation or plan content, an explicit
`/rename`, a hostname prefix, a uniquifying variant when two live sessions collide — so a name that
merely reads as configuration says nothing about the repo behind it. Confirm rather than infer.

Reach and residence come apart. A session whose working directory is the public tree can still
commit to the private one when that tree is an added working directory, since `git -C <path>` needs
reachability rather than residence. Asking the residence question gets a true answer that routes the
edit wrongly, which is worse than no answer: the session says "I'm in the public repo", the handover
goes elsewhere, and the one session that could have landed it has just talked itself out of doing
so.

Often no such session is running at all. When none is, report what changed and leave it.

The observed correspondences between names and directories, and the changelog entries showing the
other naming paths that make them unsafe to rely on, are in the cross-session-messaging note.

## The artifact decides, not the repo

This governs a rule or a skill. A note filed under `notes/` goes straight in per
`cross-project-notes.md`, which asks only for a one-line report of where it landed — a note composes
with nothing, never loads always-on, and exists to hold the dated observation rule prose has to
route away.

The shared surface a note does have is its index line. `notes/README.md` and `ideas/README.md` each
take appends from any session at once, so expect to resolve a conflict there rather than to prevent
one by messaging.

## Send it with the edit

Nothing prompts the message otherwise. The editing session's work is finished and the user is the
audience visibly in front of it, so the report goes to them — and the session in the tree never
learns the edit exists. Waiting to be asked also throws away the reason for messaging at all, since
the context that made the edit obvious is what a later prompt cannot reconstruct. Send it when the
edit lands, in the same turn.

## The receiver commits, and claims it

The rule above tells the editing session not to commit, which leaves the commit unowned unless this
is said: the receiving session commits, including the parts a peer wrote. Never answer a handover by
inviting the other session to commit after all — both sides then defer to the other and the change
sits dirty indefinitely, which is worse than either having just committed it.

Two things the receiver owes:

- **Read what the prose asserts before staging it**, per `honesty.md`'s *Check the Claims in Prose
  You Are About to Commit*. A style pass is not a review, and committing puts your name on claims
  you neither made nor checked.
- **Commit the whole file where it also carries a concurrent session's edit**, and name the other
  change in the body rather than handing the commit away. `git add --patch` is interactive and
  unavailable here, so there is no way to stage one hunk, and that constraint is a reason to write a
  clearer commit body rather than to give up the commit. Where the peer's content is not ready to
  land, ask it to hold rather than waiting silently.

Failure mode this prevents: the division of labor reads as obvious from each side and is agreed by
neither, so an edit either sits uncommitted while both sessions wait, or lands from outside the tree
— the exact thing the messaging rule exists to avoid. Nothing errors, and each session's own conduct
looks correct in isolation.
