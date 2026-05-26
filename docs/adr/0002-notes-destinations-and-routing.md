# ADR 0002: Notes Destinations and Routing

**Date:** 2026-05-26
**Status:** Accepted

## Context

This ADR is a historical record of an architecture that has been in practice
for months within this `dotclaude` repo (the user's personalized Claude Code
configuration) and is currently load-bearing across three rule files. The
reasoning has been valid for a long time but is scattered enough that "where
does this finding go?" has been re-derived several times in recent sessions.
Backfilling now while the rationale is still fresh.

During real work, findings surface that don't belong in code, commits, or
single-session state (facts that don't outlive one conversation) — and don't
fit a uniform bucket either. They differ along two axes that turn out to
matter:

- **Audience and scope.** Some findings are about *this project* and would
  die with it. Some generalize beyond any single project — an ecosystem
  quirk, a template default, a CLI gotcha — and need a home that outlives
  any one project's lifecycle.
- **Kind of content.** Some findings are *behavioral* — they describe how
  the model should approach work, what to avoid, what to keep doing. Others
  are *contextual or factual* — they describe how a system works, what setup
  was non-obvious, what debt was consciously deferred.

Without an explicit routing structure, findings either get force-fit into
project memory (where they die with the project), force-fit into rules
(where they pollute behavioral guidance with topical content), or evaporate.
The cost shows up later as the same discovery being made twice, as upstream
feedback never reaching the project that needed it, or as a "we'll revisit
when X happens" condition that no one was watching for when X happened.

There is also a separate but adjacent concern — *behavioral* feedback routes
to `~/.claude/rules/`, not to any of the notes destinations. The notes
architecture sits next to the rules destination, not under it; this ADR is
about the notes side specifically, with rules named only as the routing
partner that the notes rules have to disambiguate themselves against.

Several other in-repo locations are also out of scope here: `ideas/` holds
long-form draft thinking that hasn't crystallized into a rule, skill, or
note; `.claude/handoffs/` carries session-to-session continuity; `docs/adr/`
records architectural decisions like this one. Each is a durable destination,
but for *drafts*, *handoffs*, and *decisions* respectively — not for
findings. This ADR is scoped to findings only.

### Options

**1. Three destinations split by audience and durability (chosen).** Project
memory (per-project, Claude-only, not in-repo); project-notes (per-project,
in-repo, with shape declared per-project); `~/.claude/notes/` (cross-project,
long-lived, gitignored). Routing rules live in three rule files:
`rules/project-notes.md` (recognition triggers and per-project destination
semantics), `rules/cross-project-notes.md` (the cross-project home and what
does and doesn't belong there), and `rules/rule-maintenance.md` feedback-routing
section (the rules-vs-notes distinction).

- *Pros:* Each destination has a single, defensible purpose. Behavioral
  guidance (rules) stays separate from topical content (notes). Project-scoped
  findings stay near the project where they're useful; cross-project findings
  get a durable home that survives any single project's lifecycle. The
  decision tree is small enough to internalize, and the per-project
  destinations are configurable so a project can declare its own notes shape
  (cleanup-debt, upstream-feedback, derived-template lessons) without
  changing the rule files.
- *Cons:* Three destinations means routing is a judgment call on every
  filing. The rules describing the architecture live across three files and
  have drift potential — the cross-project rule has to keep saying "not
  project-specific, not behavioral," and the project-notes rule has to keep
  saying "not cross-project, not in code or commit." A dotclaude-style repo
  that *is* the rule home complicates the model: a finding about that repo
  could plausibly route to rules, to project memory, or to cross-project
  notes depending on framing.

**2. Single notes file per project.** One `NOTES.md` (or equivalent) per
project, no cross-project location, no distinction between behavioral and
contextual content.

- *Pros:* Simpler — one file, one destination, no routing decision. The
  "where does this go?" question disappears.
- *Cons:* Cross-project findings have no home. Behavioral lessons (which
  apply across all projects) get repeated in every project's notes file or
  get lost entirely. Project memory becomes redundant with the file but
  doesn't go away. The routing judgment isn't actually eliminated — it just
  moves underground, as the question of "what's worth keeping vs. dropping"
  becomes harder without a destination to file against.

**3. Memory-only.** Use Claude's per-project memory directory for everything
that isn't code or commit content. No in-repo notes, no cross-project notes
file, no rules separate from memory.

- *Pros:* The mechanism already exists (Claude's persistent memory) and is
  automatically loaded into context. No new directory structures or routing
  rules to maintain.
- *Cons:* Memory is designed to be *recalled* contextually, not *browsed* —
  it doesn't serve the "teammate spinning up this project" or "future-me
  reading this in a year" audiences. Memory lives at
  `~/.claude/projects/<...>/memory/`, invisible to collaborators looking at
  the repo. Cross-project lessons fragment across per-project memory
  directories with no shared home. Behavioral guidance and topical content
  blur together in the same MEMORY.md index, defeating the separation that
  makes rules legible.

## Decision

Maintain three distinct destinations for findings that aren't code, commit
content, or single-session state, with routing rules carried by three
corresponding rule files:

- **Project memory** (`~/.claude/projects/<project-slug>/memory/`) —
  Claude-only, per-project, contextual facts the model should re-encounter
  when working on this project: ongoing work, decisions, references,
  surfaced per-conversation as work uncovers them. Routing partner:
  `rules/rule-maintenance.md` feedback-routing section.
- **Project-notes** (in-repo, per-project, declared shape) — durable,
  human-readable notes about *this project* that belong with the repo:
  cleanup-debt for an MVP, drafted upstream feedback, lessons to roll back
  into a template the project was derived from. Each project declares its
  destinations (file paths, structures) in `CLAUDE.md` or an imported rule
  file. Routing partner: `rules/project-notes.md`.
- **Cross-project notes** (`~/.claude/notes/`) — long-lived, non-behavioral
  knowledge that generalizes beyond any single project: ecosystem quirks,
  defaults to include in a future template, drafts that haven't found a
  home yet. One file per topic. Gitignored. Routing partner:
  `rules/cross-project-notes.md`.

Behavioral guidance — how the model should approach work — does *not* go to
any of these; it goes to `~/.claude/rules/`. That destination is named in
`rules/rule-maintenance.md` and is the routing partner the notes architecture
lives next to.

The destinations form a small decision tree: behavioral → rules;
project-specific contextual that the model needs → memory; project-specific
contextual that humans need → project-notes; generalizes beyond this project
→ cross-project notes. When a finding plausibly fits two, prefer the more
specific one.

## Consequences

- **Positive:** "Where does this go?" has a small, learnable answer set with
  defensible distinctions. Behavioral lessons stay legible because they're
  not mixed with topical content; project-specific notes stay near the
  project where they're useful; cross-project lessons survive any single
  project's lifecycle. Each rule file's purpose is sharper because what it
  *doesn't* cover is explicitly off-loaded to a sibling destination.

- **Positive:** Per-project destination configurability — each project
  declares its own notes shape (cleanup-debt, upstream-feedback,
  derived-template) in its own `CLAUDE.md` — lets the architecture stretch
  to project shapes without rewriting the rule.

- **Neutral:** Routing is a judgment call on every filing. The cost is small
  per-finding but accumulates over many. The decision tree is short enough
  to internalize, and the rule files repeat the boundaries explicitly to
  make routing easier.

- **Negative:** The architecture is described across three rule files
  (`rules/project-notes.md`, `rules/cross-project-notes.md`,
  `rules/rule-maintenance.md`) plus one skill (`skills/project-notes/`).
  Drift between them is possible — a boundary rephrased on one side and not
  the other can create inconsistency. The "what this file is *not* for"
  lines in each rule are doing structural work and have to stay accurate
  as the architecture evolves. The "Skill and Rule Review Criteria" section
  in `rule-maintenance.md` is the architectural mitigation — periodic
  review against redundancy, contradictions, effectiveness, and completeness.

- **Negative:** When a project is the rule home itself (this `dotclaude`
  repo), the routing model bends. A finding about how dotclaude works could
  route to rules, to project memory, or to cross-project notes depending on
  framing. There is no clean answer — the same artifact plays two roles, and
  routing has to be done case by case rather than by destination.

- **Negative:** Cross-project notes are gitignored and live in
  `~/.claude/notes/`. They never sync across machines through git, and any
  value extracted from them has to be promoted (to a rule, a skill, or a
  project's notes) explicitly. The "draft that hasn't found a home yet"
  failure mode — where a note never gets promoted and the lesson it carries
  never reaches the audience that needs it — is real and not currently
  mitigated.

## References

- `rules/project-notes.md` — recognition triggers and per-project destination semantics
- `rules/cross-project-notes.md` — the cross-project home; what belongs and what doesn't
- `rules/rule-maintenance.md` — feedback-routing section (rules vs. project memory); skill-and-rule review criteria (drift mitigation)
- `skills/project-notes/` — the production workflow for project-notes filing
- Per-project `CLAUDE.md` — where each project declares its notes destinations
- Project memory directory: `~/.claude/projects/<project-slug>/memory/MEMORY.md`
