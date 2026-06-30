# orientation-doc — TODO and ideas

Deferred work and design notes, kept out of the first version on purpose.

## Per-project-type variants

`crafting-effective-readmes` carries a template per project type (OSS, personal, internal, config)
because a README's audience shifts with the project. An orientation doc's audience is more constant —
always someone working inside the system — but the emphasis still shifts: a library leans on *Terms
that bite* and the public surface, an internal service on *Soft spots* and *Where the rest lives*, a
client engagement on *What's not in this repo*. The single template covers all three for now. Add
variants only once a second and third real orientation doc show the single shape straining — don't
pre-build them.

## Proactive firing rule

`knowledge-grill` ships a local companion rule (`rules/knowledge-grill.md`) that watches the horizon
for an exit and suggests the grill before the knowledge walks away. An orientation doc has a parallel
proactive moment — a newcomer joining, a system being handed off, a codebase nobody has touched in
months getting reopened — but for v1 the skill relies on description-match firing. If the "suggest it
before it's needed" pattern proves worth forcing, add a companion rule on the same model as the
grill's. Note that a rule does not ship with a skill through the marketplace (skills-only
distribution), so it would stay local like the grill's.

## Slot in the record-artifact toolkit

The planned coherence pass over the toolkit (`session-handoff`, `session-doc`, `project-notes`, ADRs,
`knowledge-grill`, this) maps members by *audience* (self / successor / client) and *timeframe*
(resume tomorrow / hand off on exit / long-running). The orientation doc's slot: **successor- or
newcomer-facing, durable, whole-system** — distinct from the handoff (self-facing, one work session)
and the README (user/contributor-facing, how-to). Confirm there's no overlap to collapse when that
pass runs.
