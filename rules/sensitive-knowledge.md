# Sensitive Knowledge

When producing a knowledge-worker record artifact — a handoff, session doc, project note, ADR,
orientation doc, or the output of a knowledge grill — in a repo you may not own, split the knowledge
by kind. Commit the **system knowledge** (how the code works, why a decision was made, where the
setup traps are). Route the **people and relationship knowledge** to a private, gitignored artifact,
never the tracked repo.

This is the family-wide statement of a split that `knowledge-grill` and `orientation-doc` already
carry inline. Its purpose here is to cover the members that don't — `session-handoff`, `session-doc`,
`project-notes`, and ADRs — with one authoritative rule the whole family inherits. Companion to
`knowledge-worker-toolkit.md`: that rule decides *which* artifact to produce, this one decides *what
must not go into it* when the repo isn't yours.

## What counts as people knowledge

The sensitive half is the knowledge about the humans around the system, not the system itself:

- how to work with a particular client or team, and what "approved" or "done" actually means to them
- who brokers requirements, who has real authority versus nominal authority, who to route around
- individual reliability, performance, or trust notes
- internal politics, tensions, or history that explain why things are the way they are
- anything credentials-adjacent — where secrets live, who holds access

When in doubt about a specific line, ask whether the client or third party who owns the repo would be
comfortable reading it in their own tree. If not, it is the private half.

## Where the private half goes

- Write it to a dedicated gitignored directory — `.claude/knowledge-grill/`, `.claude/private/`, or
  similar named for its purpose.
- Avoid `.claude/handoffs/` for anything that isn't a session-resume handoff: handoff tooling scans
  that path and can mistake other notes for a session to resume.
- Treat raw capture as private by default — an interview transcript, a raw brain-dump, a scratch log
  holds *everything*, including what was meant to stay out of the repo. Curate the committable half
  out of it deliberately; don't commit the raw form.

## When it applies

The trigger is **a repo you don't own** — a client engagement, a third-party or vendor codebase, any
tree whose history you can't quietly rewrite. In your own repo the split is optional. The distinction
matters because a leak into a repo you don't control can't be retracted: `git` history persists, and
you can't force-push someone else's tree.

`session-handoff` output usually lives in the gitignored `.claude/handoffs/` by convention, so the
split rarely bites there — but if a handoff is ever committed to a shared or non-owned repo, the same
rule holds. ADRs and `project-notes` are the sharpest cases: both commit by design, so the sensitive
half has to be routed out *before* it lands, not cleaned up after.

## Failure mode this prevents

People and relationship knowledge — a candid note on how a client actually operates, who to route
around, what "approved" really means — gets committed to a repo the client or a third party controls.
It can't be quietly retracted: the history persists and the tree isn't yours to rewrite. The artifact
that was meant to help a successor becomes a liability the moment it ships in someone else's repo.
