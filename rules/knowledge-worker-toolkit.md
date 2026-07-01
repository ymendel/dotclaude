# Knowledge-Worker Toolkit

A family of record-artifact skills a knowledge worker owns and any project can opt into. Each
captures a different kind of knowledge for a different reader, and together they cover the transfer
points where knowledge has to cross to a lower-context reader — next session, a collaborator, a
successor. This rule is the authoritative cross-member map, the view no single skill holds. Use it to
pick the right member when producing a record, and to place a new member without overlapping one that
already exists. Each skill owns its own detail and defers here for the family's shape. For what must
*not* go into an artifact — the people-knowledge that defaults to a private file regardless of who
owns the repo — see `sensitive-knowledge.md`, the companion production-hygiene rule the whole family
inherits.

## The map

| Skill | Audience | Lifespan | Scope | Register / form |
|---|---|---|---|---|
| `session-handoff` | the resuming agent | short — until resumed, anywhere from an immediate `/clear` to days later | one session, in-flight state | mechanical, structured resume fields |
| `session-doc` | a human collaborator catching up (research partner, teammate), not the resuming agent | short — the same session horizon as the handoff | the same session(s) as the handoff | narrative — why it happened, judgment calls, lessons, in a different voice |
| `project-notes` | future self or a maintainer | long-running, appended across sessions | project threads — cleanup debt, upstream gaps, template lessons | per-finding notes routed to a declared destination |
| ADRs (`adr` / `adr-refine`) | a successor or teammate | durable, permanent record | one decision | Context / Decision / Consequences |
| `orientation-doc` | a newcomer arriving cold | durable, refreshed at transfers | the whole system | entry map — traps, soft spots, where the rest lives |
| `knowledge-grill` | producer, not artifact — feeds the rows above | — | — | adversarial interview producing an orientation doc or ADRs |

## Boundary tests — when two seem to fit

- **`session-handoff` vs. `session-doc`** — same session, but audience and register differ. If the
  reader is the next agent resuming the work, it is the handoff (mechanical state). If it is a person
  catching up on what happened and why, it is the doc (narrative). Their lifespan is the same, so do
  not split them on how-long-later.
- **`project-notes` vs. ADR** — a decision goes to an ADR. A debt, a limitation, or a lesson goes to
  project-notes.
- **`orientation-doc` vs. README** — the orientation doc is navigate-without-getting-hurt, the README
  is use-or-build. The orientation doc points at the README rather than restating it.

## Placing a new member

Before building a new toolkit skill, locate what it would capture on the four axes above: audience,
lifespan, scope, register. If its values match an existing row, it is not a new member, so extend
that row's skill or point at it. A genuinely new member has a combination no row above holds. Name
that combination before building it.

## Failure mode this prevents

Without a central map, the members drift toward overlap: a session-doc that is really a second
handoff, a project-note that should have been an ADR, a new skill that duplicates one that exists.
Each skill's own description guards its own boundary, but nothing holds the whole family's shape, so
a new capability gets built in a slot already taken and the reader ends up with two artifacts where
one was intended.
