# Sensitive Knowledge

When producing anything that lands in a repo — a doc, a comment, a commit message, and above all the
knowledge-worker record artifacts whose job is to capture context — split the knowledge by kind, by
default. Commit the **system knowledge** (how the code works, why a decision was made, where the setup
traps are). Route the **people and relationship knowledge** to a private, gitignored artifact, never
the tracked repo.

Key this on the *kind* of knowledge, not on who owns the repo. You can tell the kind from what you're
writing, but you can't reliably detect ownership — it transfers (a repo that started yours and moved
to a client), and a remote URL lags reality (GitHub redirects an old path indefinitely, so the remote
never has to change). So the split runs by default everywhere, keyed on content. Who owns the repo
decides the *stakes* of a leak, not whether to split — see below.

This is sharpest for the knowledge-worker toolkit, whose record artifacts exist to capture exactly the
tacit and contextual knowledge that includes the people half. `knowledge-grill` and `orientation-doc`
carry the split inline, and the rest of the family — along with any other artifact — inherits it from
here. It is the companion to `knowledge-worker-toolkit.md` — that rule decides *which* artifact to
produce, this one decides what must not go into it.

## What counts as people knowledge

The sensitive half is the knowledge about the humans around the system, not the system itself:

- how to work with a particular client or team, and what "approved" or "done" actually means to them
- who brokers requirements, who has real authority versus nominal authority, who to route around
- individual reliability, performance, or trust notes
- internal politics, tensions, or history that explain why things are the way they are
- anything credentials-adjacent — where secrets live, who holds access

When in doubt about a specific line, ask whether the person it is *about* would be comfortable reading
it. If not — or if you can't tell which kind it is — treat it as the private half. Default to
sensitive — over-routing a line to the private file costs nothing, committing one that shouldn't ship
costs what the failure mode below describes.

## Where the private half goes

- Write it to a dedicated gitignored directory — `.claude/knowledge-grill/`, `.claude/private/`, or
  similar named for its purpose.
- Avoid `.claude/handoffs/` for anything that isn't a session-resume handoff — handoff tooling scans
  that path and can mistake other notes for a session to resume.
- Treat raw capture as private by default — an interview transcript, a raw brain-dump, a scratch log
  holds *everything*, including what was meant to stay out of the repo. Curate the committable half
  out of it deliberately. Don't commit the raw form.

## Marking something safe to commit

The protective default needs no setup — classification plus default-private keeps you safe with no
configuration. Marking something *safe* is the deliberate opt-out:

- **Per artifact**, say so in the moment — "this note is fine to commit" — and the sensitive half goes
  in the tracked artifact for that one case.
- **For a repo where the answer recurs**, declare it once in the project's `CLAUDE.md` or `.claude/`
  instead of deciding each time — either "this repo is client- or third-party-owned, hold everything
  sensitive out" (how you pin down a repo you *know* isn't yours, like one transferred to a client) or
  "people-knowledge is fine to commit here." The declaration only saves the per-instance ask. The
  default protects you without it.

## Ownership is the stakes, not the trigger

The split runs by default everywhere, but *where* it runs decides how bad a mistake is. A leak into a
repo you don't own can't be retracted: `git` history persists, and you can't force-push someone
else's tree. In your own repo a slip is recoverable. In a client's it is not. That is why the default
is worth keeping even where it feels unnecessary — you never have to know a repo isn't yours to be
protected by it.

`session-handoff` output usually lives in the gitignored `.claude/handoffs/` by convention, so the
split rarely bites there — but if a handoff is ever committed to a shared or non-owned repo, the same
rule holds. ADRs are the sharpest case — they commit by design, so the sensitive half has to be routed out
*before* it lands, not cleaned up after. `project-notes` bites whenever its declared destination is a
tracked file, which is the common case.

## Failure mode this prevents

People and relationship knowledge — a candid note on how a client actually operates, who to route
around, what "approved" really means — gets committed to a repo the client or a third party controls.
It can't be quietly retracted — the history persists and the tree isn't yours to rewrite. The artifact
that was meant to help a successor becomes a liability the moment it ships in someone else's repo.
