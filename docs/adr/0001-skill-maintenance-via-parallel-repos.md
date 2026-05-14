# ADR 0001: Skill Maintenance via Parallel Git Repos

**Date:** 2026-05-13
**Status:** Accepted

## Context

This repository is, first and foremost, the author's personalized Claude Code
configuration — skills, rules, agents, settings. The `Makefile` symlinks
`~/.claude` to this repo's working directory, so Claude Code loads skills,
rules, and agents directly from the working tree — edits are live without a
copy or install step. Most skills here were originally sourced from elsewhere
(community projects, teammates, examples) and have since been adjusted to suit
the author's taste, prompted by feedback, or evolved through self-improvement
passes. Heavy iteration is the norm, not the exception.

Some of these skills are also useful to teammates and are mirrored in a
separate team skills repository. The team repo and the personal repo are
independent git repositories with independent histories; their contents
overlap heavily but neither is a strict subset of the other. Some skills
originated on the personal side and were shared to the team; some originated
on the team side and were brought in here; and at any given moment the two
copies of a shared skill may have drifted in either direction. How teammates
actually consume the team repo (clone, package, private marketplace, or some
other mechanism) is outside the scope of this ADR — what matters is that the
team repo is a separate working surface with its own review process.

Meaningful edits happen on both sides:

- Personal repo → team repo when a skill is judged useful and stable enough
  to share. This is a judgment call, not a threshold.
- Team repo → personal repo when review on the team side produces
  improvements worth pulling back, or when a skill originated team-side and
  is being adopted personally.

Most edits on the personal side never leave it. The subset that does goes
through code review on the team side, and review outcomes flow back.

Claude Code also offers two first-party distribution mechanisms that could
ostensibly serve the same purpose:

- **Plugins**, where a skill (or bundle of skills) is published as an
  installable unit and consumers install it into their own configuration.
- **Skill marketplaces**, where skills are discoverable and installed via a
  registry.

Both were considered and rejected for reasons described under *Options* below.
The immediate trigger for writing this ADR is the introduction of
`scripts/sync-skill.sh` as a companion to `scripts/compare-skills.sh` — a pair
of scripts that formalize the parallel-repo workflow.

### Options

**1. Parallel git repos with comparison/sync scripts (chosen).** Maintain two
independent repos. `compare-skills.sh` reports drift and direction of newer
commits per skill; `sync-skill.sh` copies a chosen skill across in a chosen
direction.

- *Pros:* No publish step, no install step, no version bump. Refinements
  are immediately live in the author's environment. Sharing is a deliberate,
  reviewed act (running `sync-skill.sh` and opening a PR), not a side effect
  of saving. The team gets a code-review surface for shared skills without
  paying the publish-install tax for unshared ones.
- *Cons:* The two repos drift continuously and that drift is normal, not
  exceptional — there is no concept of "latest version", only "newer commit
  on each side". Sync is manual; nothing prevents a skill from being updated
  on one side and forgotten on the other. No version pinning: once a change
  lands in either repo, downstream consumers see it on their next sync,
  whenever that happens. No dependency tracking for skills that rely on
  hooks or rules outside the skill directory (e.g. `graphify` depends on
  `settings.json` hooks and `rules/graphify.md`).

**2. Claude Code plugins.** Package shared skills as installable plugin units;
teammates install via the plugin mechanism.

- *Pros:* Versioning, installation, and discovery are handled by the
  platform. Updates are an explicit, controlled event for consumers.
- *Cons:* The publish-install loop is too slow for the iteration cadence on
  the personal side. A typical refinement session touches a skill several
  times before it stabilizes; routing every change through publish-install
  would either gate every edit behind a release process or fork the workflow
  into "edit locally, publish occasionally," adding ceremony for no clear
  gain. Plugin packaging also imposes structure that cuts against keeping
  skills as plain directories editable in place.

**3. Skill marketplace.** Publish to a registry; consumers install from there.

- *Pros:* Same as plugins, plus discoverability for teammates.
- *Cons:* Same as plugins — the publish-install cadence is the dominant
  cost, and a marketplace doesn't change that. Marketplaces also impose
  stronger conventions around description, categorization, and update
  cadence, none of which fit the in-place editing workflow.

**4. Single source of truth with symlinks or submodules.** Keep one canonical
repo and have the other reference it (git submodule, symlink, sparse
checkout).

- *Pros:* No drift; one history.
- *Cons:* Forces a single review model on both sides. The personal repo is
  not reviewed; the team repo is. Submodules in particular pin the team
  repo to a specific commit of the personal repo, which is backwards — the
  personal repo is the unreviewed working surface, not a stable upstream.
  Symlinks create cross-repo coupling that breaks if either side is cloned
  independently.

## Decision

Maintain skills in two parallel git repositories — this personal repo and the
team skills repo — and bridge them with shell scripts in `scripts/`:

- `compare-skills.sh` reports, for each skill present on both sides, whether
  it differs and which side has the more recent commit. For skills present
  on only one side, it lists them so the author can decide whether to
  propose sharing.
- `sync-skill.sh` (the script this ADR is motivating) copies one named skill
  between the two repos. Direction is bidirectional; the caller picks each
  time — sometimes personal → team for a new share, sometimes team → personal
  to pull back review-driven changes. Overwrite vs. merge semantics, dry-run
  flags, and other shape questions are implementation concerns for the script
  itself, not for this ADR.

Skills move between repos by running `sync-skill.sh` and then opening a PR on
the destination. Plugins and marketplaces are not used.

## Consequences

- **Positive:** Iteration on the personal side has zero distribution
  overhead — edits are immediately live. The subset of skills that get
  shared still goes through code review on the team side. The tooling
  (`compare-skills.sh`, `sync-skill.sh`) makes the drift visible and the
  sync explicit, so "what's in each repo" is always answerable by running
  one command.

- **Neutral:** There is no canonical version of any given skill. The team
  copy is a baseline, not a frozen artifact, and either side may have
  diverged from the other since the last sync. This is by design — both
  repos are working surfaces, with the meaningful difference being that
  changes on the team side go through review.

- **Negative:** Sync is manual. A bug fix on one side does not propagate
  until someone decides to sync it; there is no notification mechanism.
  (Drift itself is *visible* — `compare-skills.sh` surfaces it — but acting
  on the drift is still a human step.) The author is also a structural
  bottleneck in practice: most cross-repo movement is author-initiated, and
  teammates rarely add skills to the team repo directly even though they
  technically could. Plugins or marketplaces would naturally distribute that
  publish authority; this approach concentrates it. Finally, the approach
  does not address skills that depend on resources outside their own
  directory (hook configuration, rule files, settings) — those have to be
  shared by hand. `sync-skill.sh` prints a heuristic warning when it detects
  likely external dependencies (either the skill referencing outside paths,
  or top-level `rules/`/`hooks/`/`agents/`/`settings.json` referencing the
  skill by name), but the heuristic is best-effort and will miss implicit
  dependencies. Re-evaluate if the team repo gains active contributors
  beyond the author, or if the iteration cadence on the personal side slows
  enough that the plugin publish-install loop becomes tolerable.

## References

- `scripts/compare-skills.sh` — drift report between the two repos
- `scripts/sync-skill.sh` — per-skill bidirectional copy (to be added)
