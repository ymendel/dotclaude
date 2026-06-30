# knowledge-grill — TODO and ideas

Deferred work and design notes for this skill, kept out of the first version on purpose.

## Trigger ideas beyond the exit case

The companion rule (see COMPANIONS.md, and `rules/knowledge-grill.md`) ships with one trigger:
knowledge about to walk away (exit, handoff, staffing change), ideally caught on the horizon rather
than at the moment of departure. That is the highest-stakes case, but a backward grill is worth
running at other moments too. Candidates, deliberately *not* in the first version of the skill or
the rule:

- **Patterns of tricky work** — when the same area keeps demanding careful, hard-won reasoning, the
  knowledge being exercised is probably tacit and undocumented. A grill could surface it before it
  is needed under pressure.
- **Deviation from established norms** — when the code or process departs from an industry-standard
  way of doing things, there is usually a reason, and that reason is exactly the kind of why that
  evaporates. A grill could capture "we do it this non-standard way because…".
- **Repeated friction or re-discovery** — the second or third time the same question gets asked, or
  the same gotcha bites, the underlying knowledge is worth extracting into a durable artifact.

These overlap with the `project-notes` recognition triggers and (for repeated patterns) the
unbuilt `pattern-tracker` idea. Before adding any of them, decide whether the right home is a new
trigger in this rule or a hand-off to one of those siblings.

## Lineage and the "go fully custom" option

The interview mechanic is currently adapted from mattpocock's `grilling` (a leaf skill — no
transitive dependencies), with attribution in SKILL.md. The output routing and backward aim are
ours.

The rest of mattpocock's grill family does *not* fit this repo and was deliberately not adopted:
`grill-with-docs` pulls in `domain-modeling`, which carries its own `CONTEXT-FORMAT.md` and
`ADR-FORMAT.md` and targets a `CONTEXT.md` glossary. This repo already has its own ADR convention
(the `adr` / `adr-refine` skills, `docs/adr/`), so importing a competing ADR format would conflict.
That mismatch is why this skill routes decisions through the existing `adr` skill instead.

Two further-custom options, if wanted:

- **Fully custom mechanic.** Rewrite the interview paragraph in our own framing and drop the
  adapted lineage (keep a "see also" courtesy reference at most). The interview technique itself is
  generic; only the specific wording is borrowed. Worth doing only if the borrowed phrasing starts
  to feel like a poor fit.
- **A shared custom `grilling` primitive.** If a grill *family* emerges here (a forward
  plan-stressing grill alongside this backward one, and maybe others), factor the mechanic into one
  shared primitive skill the others compose — mirroring mattpocock's own architecture. The cost:
  a cross-skill dependency that complicates skill-only marketplace distribution (the primitive must
  be installed alongside). The current self-contained embed avoids that; revisit only when a second
  grill actually exists.

## Output artifact — built

This skill routes the entry-map output to "an orientation doc", which is now backed by the
`orientation-doc` skill (its shape: gap-as-risk first, then what-this-is, terms that bite, concepts
that moved, soft spots, where the rest lives, what's not in the repo). When that skill isn't
installed, the grill falls back to a plain "read this first" markdown doc.
