# ADR 0006: Licensing and Attribution

**Date:** 2026-07-15
**Status:** Accepted — amended 2026-08-14 (see Amendment below)

## Context

This repo is the author's public Claude Code configuration, symlinked to
`~/.claude` (ADR 0001, ADR 0003), with its tracked tree public on GitHub. It
exists to be reused: as an inspiration/template for others building their own
configuration, and as a source of individual skills that ship on their own —
distributed through the parallel team repo (ADR 0001), through marketplace
publish metadata carried in skill frontmatter, and through standalone packaging.

Despite that reuse intent, the repo carries **no `LICENSE` file**. Under
copyright law the default for an unlicensed public work is all-rights-reserved:
a reader may look, but has no grant to copy, adapt, or redistribute any of it.
That default directly contradicts what the repo is for. Anyone who wants to lift
a skill has, formally, no permission to.

The gap is compounded by provenance. The repo's content is not all original.
Most skills, and all of the agents, were adapted from upstream projects, and a license the
author grants downstream can only cover what the author is entitled to
sublicense. An audit conducted while writing this ADR established the upstream
picture:

- **Upstream, MIT-licensed, adaptation credit owed.** The `agent-toolkit` batch
  (softaworks), the VoltAgent subagents, `terrylica/cc-skills`, `supabase`, and
  `mattpocock` (`tdd`, `knowledge-grill`) are all MIT. `commit-message-guide` is
  adapted near-verbatim in its core prose from `alkofu/ai-tpk` (MIT).
  `rails-test-discipline` originated as `rspec-discipline` in a Flagrant repository
  (MIT) and was renamed on the way into this repo. `adr` and `adr-refine` also come from
  Flagrant (MIT). For all of these the safe, honest grant is repo-level —
  credit the source repository under its own license. Authorship at the person level
  was inferred from commit metadata and is not relied on. (The `graphify` skill also
  derives from an MIT upstream, `Graphify-Labs/graphify`, but it is being retired in
  a separate change and is not part of the licensed set.)
- **Author's own work.** `orientation-doc`, `project-notes`, `session-doc`, the
  `session-handoff` additions, and `yuml-diagrams`.
- **Both a code lineage and a concept credit.** `purposeful-commits` carries two
  debts: its skill body originated in a Flagrant repository (MIT), and the underlying
  method is Chris Arcand's public "Purposeful Commits" approach. The author's own
  contribution is a later refinement — separating its trigger from
  `commit-message-guide` — not the substance. Credit is owed to the repo (for the
  code) and to Chris Arcand (for the concept).
- **Upstream unlicensed — a hard blocker.** `rails-upgrade` derives from
  `robzolkos/skill-rails-upgrade`, which carries no license and has been dormant
  since early 2026. An unlicensed upstream cannot be sublicensed under any terms,
  so this one skill cannot ship under a repo-wide grant.

The agents are a simpler case than the skills. All 24 are third-party — none was
authored here — and every one is MIT: 22 from `VoltAgent/awesome-claude-code-subagents`
and 2 from `softaworks/agent-toolkit`, both already credited in the README.
(`VoltAgent` aggregates subagents from many authors under its own MIT license, so the
grant that matters is `VoltAgent`'s, repo-level. Per-file lineage inside it is neither
pinned nor needed.) The skills, by contrast, have supported channels that distribute
a single skill on its own — marketplace publish metadata in frontmatter, standalone
packaging, the bidirectional team-repo sync (ADR 0001). Agents have none of these:
the channels the repo runs ship an agent only as part of the whole tree.

That difference is what a top-level license alone cannot handle for skills. When a
skill goes out through one of those channels it leaves the repo-root `LICENSE` behind,
so whatever grant and upstream credit it needs must travel with the skill or it
arrives with neither. Informal copying — anyone lifting a single file into their own
`.claude/`, which nothing here prevents — sits outside any channel the repo controls.
There the repo-level `LICENSE` and README are the backstop, as with any public repo.

### Options

**1. MIT (chosen).** A permissive license: anyone may use, copy, modify, and
redistribute, including commercially, provided the copyright notice and license
text travel with the work.

- *Pros:* Matches the reuse intent with the least friction. Nearly every upstream
  is already MIT, so there is no license-compatibility problem in redistributing
  the adapted work — MIT-in, MIT-out. It is the license a reader of a config
  template expects, so it imposes no unusual obligations on anyone who borrows a
  skill. It is short enough to carry per-skill without ceremony.
- *Cons:* Fully permissive means others may also use and *sell* the skills, with
  no obligation to share back and no recourse if someone redistributes them. MIT
  retains no exclusivity — a property to accept deliberately, not to discover later.

**2. Copyleft (GPL / MPL).** A share-alike license: downstream users may reuse
the work but must release their derivatives under the same terms.

- *Pros:* Keeps derivatives open and prevents a closed-source fork of the
  configuration.
- *Cons:* Copyleft obligations are a poor fit for configuration and prompt text
  meant to be lifted freely into other people's private setups — the share-alike
  requirement would attach to a user's own config the moment they adapted a skill,
  which is exactly the friction this repo wants to avoid. It also introduces a
  compatibility mismatch with the MIT upstreams the work is built on.
- **Rejected:** the share-alike obligation defeats the "borrow this freely into
  your own setup" purpose and clashes with the MIT lineage.

**3. Keep it unlicensed / source-available (status quo).** Leave the repo with no
`LICENSE`, or add terms that permit viewing but not reuse.

- *Pros:* Preserves maximal control — nobody can redistribute without asking.
- *Cons:* All-rights-reserved is the current state, and it is precisely the
  problem — it contradicts the repo's stated purpose and leaves every would-be
  reuser without a grant. A view-only source-available license would formalize a
  restriction the author does not actually want.
- **Rejected:** it is the status quo the ADR exists to fix.

## Decision

Adopt the **MIT License** for this repository. Add a top-level `LICENSE` file,
`Copyright (c) 2026 Yossef Mendelssohn`.

**The grant covers everything tracked.** MIT applies to all of dotclaude's tracked
content — skills, agents, rules, hooks, scripts — not only the skills.

**A per-skill `LICENSE` travels with substantial original work.** The root `LICENSE`
is the author's grant for the whole tree, but a skill that ships individually leaves
that root grant behind — the same problem the per-skill `ATTRIBUTION.md` solves for
upstream credit, applied to the author's own grant. So a skill carrying substantial
*original* work of the author's also carries its own `LICENSE` (the same MIT text,
`Copyright (c) 2026 Yossef Mendelssohn`), so the grant rides along when the skill is
copied out. Where the original work lives decides which files a skill carries:

- An **own-work skill** — `orientation-doc`, `project-notes`, `session-doc`,
  `yuml-diagrams` — carries a `LICENSE` and no `ATTRIBUTION.md`. There is no upstream
  to credit; the only rights-holder is the author, and his grant has to travel.
- A **heavily-derived skill** whose own additions are themselves a substantial work —
  `session-handoff`, `knowledge-grill`, `skill-architecture`, `naming-analyzer`,
  `mermaid-diagrams`, `adr` — carries *both*: an `ATTRIBUTION.md` preserving the
  upstream's notice, and a `LICENSE` granting the author's additions. A derivative work
  of this weight has more than one rights-holder, and every grant must travel.
  (`skill-architecture` has three: its base is MIT from `terrylica/cc-skills`, its
  vendored scripts are Apache 2.0 from Anthropic's skill-creator, and its rework is the
  author's.) The set was chosen by reading each skill's post-import git history for the
  weight of original work, not by assumption.
- A **lightly-derived skill** — the rest — carries only its `ATTRIBUTION.md`. Its
  original delta is too thin to stand as a separately licensable work, so the upstream
  notice plus the repo-root grant is the whole obligation.

Stated once: a per-skill `LICENSE` rides wherever there is substantial original work
of the author's — alone for an own-work skill, alongside the upstream notice for a
heavy derived one.

**Attribution has two tiers.** The baseline is repo-level: the README's Appreciation
section credits every upstream the repo draws from. That is the whole obligation for
any content the repo distributes only as a whole — which is where all 24 agents sit
(22 from `VoltAgent`, 2 from `softaworks/agent-toolkit`, all MIT). The second tier
is per-skill: each *derived skill* also carries an `ATTRIBUTION.md` in its own
directory preserving the upstream's MIT notice. Because skills — unlike agents — ship
individually, that file has to ride along when a skill is copied out of the tree, so a
standalone skill arrives with both its grant and its credit intact. The pattern is
already established for `session-handoff` (softaworks) and `knowledge-grill`
(mattpocock). This decision generalizes it to all derived skills.

Agents get the repo-level tier only. A per-agent `ATTRIBUTION.md` would be ceremony
for a distribution path agents do not have — if that ever changes and agents start
shipping individually, they take the per-item tier too. Two attribution rules hold at
both tiers:

- Credit the source **repository** under its license (always a safe grant). Name a
  **person** as author only where authorship is confirmed — a commit's git-author
  is not proof of authorship.
- A debt to an *approach* (a method or idea, no code copied) is credited in the
  skill's own text, naming the approach and its author — no upstream license notice
  is owed, because there is no copied code to carry one. A debt to a *code lineage*
  takes an `ATTRIBUTION.md` as above. The two can co-occur: `purposeful-commits`
  owes an `ATTRIBUTION.md` to Flagrant for its body *and* an in-text
  credit to Chris Arcand for the "Purposeful Commits" method.

**`rails-upgrade` is dropped.** Its upstream is unlicensed, so it cannot ship under
this repo's MIT grant, and the author has never used it. Removing it clears the only
hard licensing blocker. If the capability is wanted later, the path back is a
clean-room rewrite, not a re-import.

The concrete implementation — adding the root `LICENSE`, adding a `## License` section
to the README that names MIT and points at it, adding or fixing the per-skill
`ATTRIBUTION.md` files, adding the per-skill `LICENSE` files where substantial original
work warrants one, reconciling the README's appreciation section (adding missing
upstreams, removing the line for the dropped skill), and removing `rails-upgrade` —
follows in the attribution pass and is out of scope for this record beyond naming
that it happens.

## Consequences

- **Positive:** The reuse intent is finally backed by an actual grant. A reader
  who wants to lift a skill, fork the template, or publish an adapted version now
  has explicit permission, per-skill and per-repo.
- **Positive:** MIT-in, MIT-out means the adapted upstreams redistribute without a
  license-compatibility problem — the whole tree, original and derived, ships under
  one coherent grant.
- **Positive:** The per-skill `ATTRIBUTION.md` convention makes a standalone-shipped
  skill self-contained: its license lineage and upstream credit travel with the
  directory, not just with the repo root.
- **Negative:** MIT permits others' commercial use — including reselling or
  redistributing the skills — with no obligation to share back and no recourse. The
  author gives up any "only the author may distribute this" control, for every piece,
  permanently. This is a deliberate tradeoff, not an oversight: the sharing intent is
  judged to outweigh the control a more restrictive license would preserve. A piece
  that later needs more restrictive terms would have to be carved out before its first
  release under MIT — a grant already made cannot be revoked for copies already out.
- **Negative:** Attribution correctness rests on provenance reconstructed after the
  fact — repo-level credit, commit dates, inferred authorship. It is honest about
  its limits (person-level authorship is not claimed where unconfirmed), but a
  missed or mis-scoped upstream would ship an incomplete notice until caught.
- **Negative:** Dropping `rails-upgrade` loses a working capability, and the only
  clean way back is a rewrite from scratch — the unlicensed upstream stays
  off-limits unless its author licenses it.
- **Negative:** The per-skill `ATTRIBUTION.md` and `LICENSE` convention is manual
  upkeep. Every new derived skill needs an `ATTRIBUTION.md`, every own-work skill and
  every heavily-derived one needs a `LICENSE`, and judging whether a skill's original
  delta is "substantial" enough to warrant its own grant is a per-skill call with no
  bright line. The bidirectional team-repo sync (ADR 0001) can carry or drop either
  file depending on which direction a skill moves; nothing enforces that the notice or
  the grant stays attached.
- **Neutral:** Skills and agents are attributed asymmetrically — skills get a
  travelling per-item notice, agents get repo-level credit only — because only skills
  ship on their own. The asymmetry is deliberate and has a named revisit trigger
  (agents beginning to ship individually), so it is a documented choice rather than an
  inconsistency to trip over later.

## Amendment — 2026-08-14

The agent count this ADR states throughout is now historical. The directory was pruned
from 24 agents to 6, keeping only those with a trigger path in `rules/agents.md`. The
counts in Context and Decision above ("all 24 agents", "22 from `VoltAgent`, 2 from
`softaworks/agent-toolkit`") describe the tree as it stood on 2026-07-15 and are left
as written, since they are the state the decision was taken against.

Nothing in the Decision changes. Both upstreams still supply kept agents, so both
grants still matter and both remain credited in the README's Appreciation section. The
repo-level-only tier still applies, for the same reason as before — the channels this
repo runs still ship an agent only as part of the whole tree — and its revisit trigger
(agents beginning to ship individually) is untouched.

Two things the prune makes worth stating, because a smaller tree invites the wrong
inference. Removing an agent does not narrow the grant this ADR gives, since it is
repo-wide over what is tracked rather than an enumeration of files. And adding one back
carries the same obligation it always did: a new agent from an uncredited upstream needs
that upstream added to Appreciation, which is the whole per-agent obligation and is easy
to skip precisely because no per-agent `ATTRIBUTION.md` exists to prompt for it.

## References

- [ADR 0001](0001-skill-maintenance-via-parallel-repos.md) — Skill Maintenance via
  Parallel Git Repos; the per-skill distribution mechanism that makes a per-skill
  license and attribution necessary rather than a repo-root `LICENSE` sufficing.
- [ADR 0003](0003-allowlist-gitignore.md) — Allowlist-Based .gitignore; governs
  what is tracked and therefore what the license actually covers.
- [ADR 0005](0005-private-skills-separate-repo.md) — Separate Repository for Private
  Skills; the private incubator whose skills are deliberately *not* under this grant
  until promoted.
- Upstreams (all MIT unless noted): `softaworks/agent-toolkit`, `mattpocock/skills`,
  `VoltAgent/awesome-claude-code-subagents`, `terrylica/cc-skills`,
  `supabase/agent-skills`, `alkofu/ai-tpk`, a Flagrant repository
  (`Copyright (c) 2026 Flagrant`), `anthropics/skills` (Apache 2.0 — the skill-creator
  scripts vendored into `skill-architecture`); `robzolkos/skill-rails-upgrade` (no
  license — the reason `rails-upgrade` is dropped).
- [Chris Arcand — "Purposeful Commits"](https://chrisarcand.com/purposeful-commits/) —
  the method `purposeful-commits` is built on; a concept credit, not a code lineage.
- [`LICENSE`](../../LICENSE) — the top-level MIT grant added by the implementation pass.
