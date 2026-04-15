# Skills

Skills extend Claude's capabilities for specific tasks. The `description` frontmatter is always in context so Claude knows what's available; the full skill body loads only when the skill is invoked. Most skills trigger automatically when relevant — a few are manual-only (marked below) because they have side effects or should only run when explicitly asked.

Invoke manually with `/skill-name [args]`.

---

## Git & code changes

**`commit-message-guide`** — Conventional commit format, command tense, when to include a body and what to leave out. Also pre-approves git tool calls.

**`explain-changes-mental-model`** `[commit|branch|range|custom]` — Breaks a diff into logical groups ordered by dependency so changes can be understood incrementally. Accepts a commit hash, branch name, git range, or "custom" to paste a diff manually.

**`explain-pr-changes`** `[issue-ref]` ⚠️ manual-only, runs in subagent — Generates a full PR summary (high-level overview, optional Mermaid diagrams, per-changeset breakdown with triage status) then asks for confirmation before touching GitHub.

## Writing & documentation

**`writing-clearly-and-concisely`** — Applies Strunk's rules for clarity and concision. Also covers AI writing anti-patterns (puffery, empty -ing phrases, overused vocabulary). Reference files contain the relevant chapters from *The Elements of Style*.

**`crafting-effective-readmes`** — README guidance and templates matched to project type (OSS, personal, internal, XDG config). Not all READMEs are the same.

## Architecture & design

**`adr`** — Writes Architecture Decision Records or advises whether a decision is ADR-worthy. Follows the format defined in `rules/adrs.md`.

**`mermaid-diagrams`** — Comprehensive Mermaid syntax reference and diagram-type selection guide. Reference files cover each diagram type in depth; the skill body covers selection logic and quick-start examples.

**`database-schema-designer`** — Production-ready SQL and NoSQL schema design: normalization, indexing strategies, constraints, migrations, performance. Reference files contain the checklist and migration templates.

**`requirements-clarity`** — Transforms vague feature requests into actionable PRDs through structured dialogue. Scores clarity on a 100-point rubric; generates the PRD when the score reaches 90.

## Code quality

**`naming-analyzer`** — Suggests better names for variables, functions, and classes based on context and language conventions.

**`lesson-learned`** — Extracts grounded software engineering lessons from recent git history. Produces a dominant pattern mapped to SE principles, with actual file/line references. Reference files contain the principles and anti-patterns catalog.

## Rails

**`rails-upgrade`** — Analyzes a Rails application's upgrade path: checks current version, fetches upgrade notes and diffs, performs selective upgrade while preserving local customizations.

## Database

**`supabase-postgres-best-practices`** — Postgres performance and best practices from Supabase's engineering. Covers query optimization, indexing, connection pooling, locking, schema design, security (RLS), and monitoring. Heavy on reference files; the skill body is a navigation index.

## Skills & config

**`skill-architecture`** — Creating and modifying skills: YAML frontmatter standards, progressive disclosure patterns, structural patterns, troubleshooting descriptions that don't trigger. Extensive reference files.

**`skill-judge`** — Evaluates skill quality against the official spec across 8 dimensions (120 points total). Use when reviewing or auditing a SKILL.md.

**`agent-md-refactor`** — Refactors bloated CLAUDE.md or AGENTS.md files using progressive disclosure: essentials at root, detailed content in linked files.

## Tooling

**`dependency-updater`** ⚠️ manual-only — Smart dependency management for any language. Auto-detects project type, applies safe updates (patch/minor) automatically, prompts for major versions.

**`ascii-diagram-validator`** — Validates alignment of ASCII box-drawing diagrams in markdown. Runs a bundled Python script via `uv`; reports issues with file:line:column locations and suggested fixes.

**`session-handoff`** — Creates handoff documents for transferring context between sessions. Also handles resuming from a handoff. Proactively suggested after substantial work or when context is running low.
