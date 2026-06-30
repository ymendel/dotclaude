# Skills

Skills extend Claude's capabilities for specific tasks. The `description` frontmatter is always in context so Claude knows what's available; the full skill body loads only when the skill is invoked. Most skills trigger automatically when relevant — a few are manual-only (marked below) because they have side effects or should only run when explicitly asked.

Invoke manually with `/skill-name [args]`.

## Skills vs. rules

Skills load on demand; rules load eagerly. Procedural workflows with their own steps, templates, or references belong in skills. Behavioral defaults that should apply to every response belong in rules. A single concern occasionally splits across both — see the `project-notes` and `graphify` entries below, each paired with a rule for the always-on side.

---

## Git & code changes

**`commit-message-guide`** — Conventional commit format, command tense, when to include a body and what to leave out. For single logical changes. Pairs with `purposeful-commits` for multi-concern work.

**`purposeful-commits`** — Structures a working tree with mixed concerns into logical, ordered commits (refactoring → feature → supporting). Proposes a commit plan before executing. For single logical changes, defers to `commit-message-guide`.

**`explain-changes-mental-model`** `[commit|branch|range|custom]` — Breaks a diff into logical groups ordered by dependency so changes can be understood incrementally. Accepts a commit hash, branch name, git range, or "custom" to paste a diff manually.

**`explain-pr-changes`** `[issue-ref]` ⚠️ manual-only, runs in subagent — Generates a full PR summary (high-level overview, optional Mermaid diagrams, per-changeset breakdown with triage status) then asks for confirmation before touching GitHub.

## Writing & documentation

**`writing-clearly-and-concisely`** — Applies Strunk's rules for clarity and concision. Also covers AI writing anti-patterns (puffery, empty -ing phrases, overused vocabulary). Reference files contain the relevant chapters from *The Elements of Style*. Optionally pairs with `rules/writing.md`, a personal-voice overlay that supplements (not replaces) the skill — see the skill's `COMPANIONS.md` for the pattern.

**`crafting-effective-readmes`** — README guidance and templates matched to project type (OSS, personal, internal, XDG config). Not all READMEs are the same.

**`project-notes`** — Files long-running project notes that don't belong in code, commit messages, memory, or session handoffs: cleanup debt, drafted upstream feedback, lessons for a derived template. Per-destination templates and a deterministic search for declared destinations. Pairs with `rules/project-notes.md`, which covers the recognition habit.

**`knowledge-grill`** — Interviews the holder of an existing system to extract tacit knowledge — the why behind decisions, non-obvious constraints, the gap that would stall a successor — and routes it to durable artifacts (ADRs, an orientation doc, a private people-notes file). The backward counterpart to forward plan-stressing. Pairs with `rules/knowledge-grill.md`, which watches for an exit on the horizon and suggests the grill before the knowledge walks away.

## Architecture & design

**`adr`** — Writes Architecture Decision Records, advises on ADR-worthiness, or updates an existing ADR (accept, supersede, deprecate, or amend when a downstream ADR shifts the facts under an intact decision). Auto-invokes `adr-refine` after drafting.

**`adr-refine`** — Critiques a draft ADR: surfaces unclear context, missing tradeoffs, hand-wavy language, and codebase inconsistencies. Auto-invoked by `adr`; also use when reviewing an existing draft, re-refining a Proposed ADR after implementation surfaces new info, or refining a newly-appended Amendment block on an Accepted ADR.

**`mermaid-diagrams`** — Comprehensive Mermaid syntax reference and diagram-type selection guide. Reference files cover each diagram type in depth; the skill body covers selection logic and quick-start examples.

**`yuml-diagrams`** — yUML DSL syntax reference and diagram-type selection guide. Covers class, sequence, activity, use case, state, C4, journey, timeline, roadmap, canvas (SWOT, Strategy Choice Cascade), and chart diagrams. Reference files cover each type in depth; the skill body covers type selection, loading triggers, NEVER rules, and render troubleshooting.

**`graphify`** — Builds a knowledge graph of a codebase or folder with community detection. Outputs interactive HTML, GraphRAG-ready JSON, and a plain-language audit report. Pairs with `rules/graphify.md`, which directs graph-first exploration in projects where a `graphify-out/` artifact already exists.

**`database-schema-designer`** — Production-ready SQL and NoSQL schema design: normalization, indexing strategies, constraints, migrations, performance. Reference files contain the checklist and migration templates.

**`requirements-clarity`** — Transforms vague feature requests into actionable PRDs through structured dialogue. Scores clarity on a 100-point rubric; generates the PRD when the score reaches 90.

## Code quality

**`naming-analyzer`** — Suggests better names for variables, methods, classes, and modules. Ruby/Rails-primary, with conventions for JS and Python. Includes a pre-rename thinking framework for weighing corrections against consistency.

**`lesson-learned`** — Extracts grounded software engineering lessons from recent git history. Produces a dominant pattern mapped to SE principles, with actual file/line references. Reference files contain the principles and anti-patterns catalog.

**`tdd`** — Language-agnostic TDD via red/green/refactor. Covers test-first workflow (vertical slices, tracer bullets), mocking strategy (mock only at system boundaries, use a real database), public interface testing, and testable interface design. Pairs with `rails-test-discipline` for Rails projects.

## Rails

**`rails-upgrade`** — Analyzes a Rails application's upgrade path: checks current version, fetches upgrade notes and diffs, performs selective upgrade while preserving local customizations.

**`rails-test-discipline`** — Test level selection, ADR alignment, and review posture for Rails (RSpec or Minitest). Defers general TDD principles to `tdd`; handles what's Rails-specific: model vs. system vs. request selection, factory/fixture guidance, and structured output with explicit coverage gaps. Loads automatically when working in `spec/` or `test/`.

## Database

**`supabase-postgres-best-practices`** — Postgres performance and best practices from Supabase's engineering. Covers query optimization, indexing, connection pooling, locking, schema design, security (RLS), and monitoring. Heavy on reference files; the skill body is a navigation index.

## Skills & config

**`skill-architecture`** — Creating and modifying skills: YAML frontmatter standards, progressive disclosure patterns, structural patterns, troubleshooting descriptions that don't trigger. Extensive reference files.

**`skill-judge`** — Evaluates skill quality against the official spec across 8 dimensions (120 points total). Use when reviewing or auditing a SKILL.md.

**`agent-md-refactor`** — Refactors bloated CLAUDE.md or AGENTS.md files using progressive disclosure: essentials at root, detailed content in linked files.

## Tooling

**`dependency-updater`** ⚠️ manual-only — Smart dependency management for any language. Auto-detects project type, applies safe updates (patch/minor) automatically, prompts for major versions.

**`ascii-diagram-validator`** — Validates alignment of ASCII box-drawing diagrams in markdown. Runs a bundled Python script via `uv`; reports issues with file:line:column locations and suggested fixes.

**`session-handoff`** — Creates handoff documents for transferring context between sessions. Also handles resuming from a handoff. Proactively suggested after substantial work or when context is running low. Auto-invokes `session-doc` after confirming a handoff when the project declares a session-docs destination.

**`session-doc`** — Produces a narrative session document for a human re-reader weeks later: why this session happened, what was done, inline decisions worth re-examining, lessons, and suggested next moves. Paired with `session-handoff` (the mechanical resume artifact), not collapsed with it — their audiences and shapes differ. Auto-fires alongside `session-handoff` when the project's `CLAUDE.md` declares a `## Session docs` destination.
