---
name: knowledge-grill
description: "Interview the holder of an existing system to extract tacit knowledge and write it into durable artifacts. Use when knowledge needs capturing before it walks away (a handoff, project exit, or staffing change), when the user says things live only in their head, when documenting why past decisions were made, or when writing down how a system actually works. Not for stress-testing a plan before building — this is the backward counterpart."
---

# Knowledge Grill

A relentless interview that pulls tacit knowledge about *existing* work out of the person who holds
it, and writes it down where a successor will find it. A forward grill stress-tests a plan *before*
building; this is its backward sibling — it surfaces what is already true but undocumented, the
knowledge so internalized the holder no longer notices it is missing from the record. Surfacing it
takes an outside interviewer probing, not a request to "write down what's important."

## The interview

The mechanic, one question at a time:

- Interview the holder relentlessly about the system until you reach a shared understanding. Walk
  down each branch of the design, resolving dependencies between decisions one by one.
- Ask one question at a time, waiting for the answer before the next. A wall of questions is
  bewildering.
- For each question, offer your recommended answer rather than asking cold.
- If a question can be answered by exploring the codebase or existing artifacts, explore instead of
  asking. This matters most in the backward case: read the code, the commit history, and the
  existing docs *first*, and spend the interview only on what those cannot tell you — the reasons,
  the constraints, the gotchas that live in no file.

## Seed questions from evidence, not introspection

The open question — "what lives only in your head?" — has a built-in flaw: it asks the holder to
introspect on knowledge that is invisible to them *because* it is internalized (above). They blank,
or forget the days they just spent on something only they understand. Evidence flips this. The same
up-front read of the code and git history that tells you what *not* to ask also surfaces the
*footprint* of tacit knowledge — point at the footprint and the holder answers a concrete
observation instead of searching an empty field.

One pass through the repo, two jobs: prune the answerable, and surface the hotspots to ask about.
Signals worth mining:

- **Sole authorship, concentrated** — one person is the only author of an area and it is a large
  share of their recent commits. "You're the only one who's touched reconciliation, and it's most of
  your last month — walk me through it." This is the bus-factor-of-one hotspot, and the one the open
  question most often misses: work someone knows nobody else understands, yet never thinks to raise.
- **Recent intense focus** — recent commits cluster in one or two places. "Almost all of last week
  was in X — what would a successor need to know there?"
- **Churn without docs or tests** — an area changes often while nothing in docs or tests moves with
  it; the reasoning is living in a head, not the record.
- **Load-bearing code, terse history** — a complex module whose commits say only "fix" or "wip"; the
  why was never written down.

Turn each signal into a grounded hypothesis rather than an open question — the evidence is a strong
basis for the "offer your recommended answer" move above: "I'd guess the sole authorship is a timing
constraint that isn't written down — is that it?"

The open-ended catch-all — asking directly what would stall whoever inherits this (the *gap-as-risk*
below) — is the backstop, not the opener. Lead with the evidence-seeded threads; they surface what
the holder would never have volunteered. Reach for the open question last, for whatever no signal
pointed at.

## Aim it backward — what to extract

Point every question at knowledge that currently exists only in the holder's head:

- **The why behind decisions** — why it was built this way, which alternatives were rejected and for
  what reason. This is the part that leaves with the person.
- **Non-obvious constraints and gotchas** — the "don't touch X because Y", the load-bearing
  assumption nothing documents, the workaround that looks wrong but is deliberate.
- **Operational shape** — how the thing actually runs, what breaks it, the entry points a newcomer
  needs to find first.
- **The gap-as-risk** — the open catch-all, "what is the one thing that, only in your head right now,
  would stall whoever inherits this?" The backstop, not the opener — reach for it once the
  evidence-seeded threads are exhausted (see *Seed questions from evidence* above).

Two failure modes to push against while extracting:

- **Don't accept the first abstract answer** — push for the concrete decision and the case that
  forced it. "It was a performance thing" is not yet the knowledge; the query that timed out is.
- **Don't let the holder narrate the happy path** — the value is in the exceptions, the workarounds,
  the things that broke once.

## When the "why" turns interpersonal

Sometimes the backward "why" leads into charged ground — a project that paused, a fraught handoff,
conflict between the people involved. Reconstructing that history is legitimate and often the most
valuable part of the capture — don't steer around it. But two things change when the subject turns
interpersonal:

- **Set expectations, and let the holder pace it.** Say up front that reconstructing this "why" will
  re-walk difficult ground, that surfacing it is intended, and that the holder sets the pace on that
  half — they can pause a thread or come back to it later. The relentless probing that's right for a
  technical branch is the wrong register for a painful one. The holder is usually one of the parties,
  not a neutral narrator, so the material lands heavier than a system question does.
- **Don't foreground a third party's grievance as a question's frame.** When a question's answer
  touches a grievance or conflict, lead with the neutral question and mention the charged context
  second — "independent of any of that, what's the actual coverage state?" rather than opening with
  "X said Y wasn't done." Leading with the grievance makes the holder re-encounter the sting before
  reaching the question they can actually answer.

## Route the output to durable artifacts

The interview is the engine; what makes it a toolkit member rather than a conversation is *where the
output lands*. Do not leave it in the chat — route each kind of finding to the artifact built for
it:

- **Decisions and their why → ADRs.** Prefer the `adr` skill when it is available; otherwise write the
  decision as a markdown ADR directly (Context / Decision / Consequences). When the capture is racing
  an exit and the decision content is already complete, hand-writing the ADR and offering `adr-refine`
  as a follow-up is fine even with `adr` present — don't let the heavier workflow stall a capture
  that's against the clock. Offer an ADR only when the decision is hard to reverse, surprising without
  context, and the result of a real trade-off; skip it otherwise. (Not depending on `adr` being
  installed keeps this skill self-contained when shipped alone — the same soft-dependency trap the
  mattpocock grill family falls into.)
- **Entry map and operational shape → an orientation doc** — the "read this first" map over setup,
  how the pieces relate, and where to start. Use the `orientation-doc` skill for its shape when
  present; otherwise write a plain "read this first" markdown doc.
- **Gap-as-risk → flag it** at the top of the orientation or handoff doc, so the inheritor sees the
  load-bearing unknown before anything else.
- **People and relationship knowledge → a private artifact, not the repo.** The interview surfaces
  system knowledge (safe to commit) alongside people knowledge — how to work with a client, what
  "approved" actually means, who brokers requirements. Split the two by default, keyed on the kind of
  knowledge rather than on who owns the repo — commit the orientation doc and ADRs, route the people
  knowledge to a private, gitignored file. Ownership sets the stakes — a leak into a repo you don't
  own can't be retracted — not whether to split. Treat the raw interview transcript as private by
  default too — it holds everything, including what was meant to stay out of the repo. When you write
  a person up, don't assume their pronouns, gender, last name, or title — a name is not evidence of
  gender; use the name or singular "they", and mark an attribute unknown rather than guessing. Mark
  each people-fact stated (written in a doc or given in an answer) vs. inferred (your reading), so a
  successor can tell recorded fact from interpretation.

Write private artifacts to a dedicated directory like `.claude/knowledge-grill/`. Avoid
`.claude/handoffs/` — that path is conventionally the home for session-resume handoffs, a different
kind of artifact, and handoff tooling that scans it (the `session-handoff` skill's hook, where
installed) can mistake your notes for a session to resume.

## Firing

For *proactive* firing (noticing an exit or handoff on the horizon before anyone asks) and trigger
ideas beyond the exit case, see [COMPANIONS.md](./COMPANIONS.md) and [TODO.md](./TODO.md).

## Attribution

The interview mechanic is adapted from the `grilling` skill in
[mattpocock/skills](https://github.com/mattpocock/skills) (MIT License, Copyright (c) 2026 Matt
Pocock). The backward aim and the output-routing to successor artifacts are this skill's additions.
