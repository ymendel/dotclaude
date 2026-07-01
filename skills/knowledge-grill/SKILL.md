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

## Aim it backward — what to extract

Point every question at knowledge that currently exists only in the holder's head:

- **The why behind decisions** — why it was built this way, which alternatives were rejected and for
  what reason. This is the part that leaves with the person.
- **Non-obvious constraints and gotchas** — the "don't touch X because Y", the load-bearing
  assumption nothing documents, the workaround that looks wrong but is deliberate.
- **Operational shape** — how the thing actually runs, what breaks it, the entry points a newcomer
  needs to find first.
- **The gap-as-risk** — ask directly: "what is the one thing that, only in your head right now,
  would stall whoever inherits this?"

Two failure modes to push against while extracting:

- **Don't accept the first abstract answer** — push for the concrete decision and the case that
  forced it. "It was a performance thing" is not yet the knowledge; the query that timed out is.
- **Don't let the holder narrate the happy path** — the value is in the exceptions, the workarounds,
  the things that broke once.

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
  default too — it holds everything, including what was meant to stay out of the repo.

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
