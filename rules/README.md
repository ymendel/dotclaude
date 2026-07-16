# Rules

Rule files govern how Claude should behave across all projects, not just in specific tasks. Most load unconditionally at session start. Files with `paths` frontmatter load only when Claude reads a matching file.

## Rules vs. skills

Rules load eagerly, skills load on demand when their trigger description matches the context. Behavioral defaults — guidance that should apply to every response — belong in rules. Procedural workflows with their own steps, templates, or references belong in skills.

A single concern occasionally splits across both. The `project-notes` rule covers the recognition habit — when to notice something filing-worthy. The `project-notes` skill covers the production workflow — how to file it once recognized. The rule fires unconditionally so recognition stays on. The skill loads only when invoked.

---

**`agents.md`** — When to use each available agent type. Covers the distinction between `Explore` and `codebase-pattern-finder`, when to reach for `Plan`, when specialized agents beat `general-purpose`, when to parallelize (including the big-ADR-kickoff trigger), and when to delegate noisy reads to preserve main context.

**`code-style.md`** — General code style: trailing newlines, simplicity, parser libraries over regex, naming, consistency.

**`code-style-ruby.md`** — Ruby and Rails conventions: instance-oriented design, no metaprogramming, Symbol#to_proc, aesthetic preferences, Rake task syntax, and verifying model names before scripting against them. Path-scoped to `*.rb`, `*.rake`, `*.erb`, `Gemfile`, and `Rakefile`.

**`development-workflow.md`** — How work should be approached: planning vs. spikes, ADRs over proprietary plan modes, git discipline (small commits, specific staging, amend recent changes, draft PRs), review scope, refactoring policy, and commenting conventions.

**`diagnosis.md`** — Diagnose before retrying. When a command fails or gives unexpected output, reason about why before issuing variants — including not routing around the user's shell configuration to silence a symptom. Includes specific cases for git tree-ish ambiguity and RTK diff filtering.

**`honesty.md`** — Rules about factual claims: never present estimates as measurements, source every number, verify the framing of external systems and codebase concepts against the source before writing prose about them, separate verified facts from assumptions, don't optimize for looking helpful over being accurate. Applies extra scrutiny to any external-facing content.

**`searching.md`** — How to pick the right tool and scope when looking something up: scoping searches to the known location, never searching locally for external library docs, and choosing between WebFetch and raw curl.

**`self-improvement.md`** — Triggers for when to self-improve: user corrections, workarounds, failed commands, violated rules, and inconsistencies. Points to `rule-maintenance.md` for how to act on them.

**`project-notes.md`** — Recognition triggers for long-running project notes that don't belong in code, commit messages, memory, or session handoffs: cleanup-debt, drafted upstream feedback, lessons for a derived-template. Covers the *when* to file. The `project-notes` skill covers structure and the *how*. Destinations are project-specific config.

**`cross-project-notes.md`** — Sibling to `project-notes.md` for findings that generalize beyond any single project and don't have an upstream / template / external destination yet. Names `~/.claude/notes/` as the durable home for those, with one file per topic (`template-lessons.md`, `postgres-quirks.md`, …). Directory is intentionally outside version control.

**`knowledge-grill.md`** — Companion rule for the `knowledge-grill` skill: suggest a backward, tacit-knowledge-extraction grill *before* knowledge walks away (exit, handoff, staffing change on the horizon), while the holder is still around to interview. The skill runs the interview and routes output to durable artifacts; this rule covers the *when*. Same skill+rule split as `project-notes`. Broader triggers are deferred — see `skills/knowledge-grill/TODO.md`.

**`knowledge-worker-toolkit.md`** — The map of the record-artifact skill family (`session-handoff`, `session-doc`, `project-notes`, ADRs, `orientation-doc`, `knowledge-grill`): what each captures, the boundary tests for when two seem to fit, and how to place a new member without overlapping an existing one. The authoritative cross-member view the individual skills defer to.

**`sensitive-knowledge.md`** — Companion production-hygiene rule to `knowledge-worker-toolkit.md`: when producing any artifact that lands in a repo (sharpest for the knowledge-worker toolkit), split system knowledge (commit) from people and relationship knowledge (route to a private, gitignored artifact) by default — keyed on the kind of knowledge, which can be read from the content, rather than on who owns the repo, which can't be reliably detected. Covers what counts as people knowledge, how to mark something safe to commit, and why repo ownership sets the stakes of a leak rather than the trigger. The family-wide statement of a split `knowledge-grill` and `orientation-doc` already carry inline.

**`rule-maintenance.md`** — Procedures for making corrections: where to edit skills and rules, YAML quoting requirements, feedback routing, permissions allow list, keeping `rules/README.md` up to date, and criteria for reviewing skills and rules.

**`feedback.md`** — Overflow for rules and feedback that don't fit an existing rule file. Periodically reviewed for extraction into topic-specific files.
**`RTK.md`** — Usage guide for RTK (Rust Token Killer), a token-optimized CLI proxy. Covers the hook scope limitation (Bash only, not built-in tools), the override for file/search operations, and command reference by workflow.

**`settings.md`** — Gotchas for `settings.json`: tilde vs. `$HOME` in path fields, `*` vs. `**` in permission globs, and backslash-escaped whitespace triggering permission dialogs.

**`long-form-output.md`** — When a turn's output is long enough that the user would have to scroll back and forth in the conversation to re-read it, write it to a file and post a short pointer in the chat instead of dumping it inline. Covers what counts as "long enough", what doesn't need a file, and the file-plus-pointer pattern.

**`writing.md`** — User-specific writing preferences that supplement the `writing-clearly-and-concisely` skill: avoid violent metaphors and military or war-origin idioms (including "in anger"); emulate the user's voice when appropriate (register, archaic Latin abbreviations like `&c.`, `viz.`, `cf.`), without mirroring his lowercase prompting shorthand in formal output.

**`stakeholder-questions.md`** — Keep *behavior* with whoever owns the requirement and *implementation* with engineering, in both directions: ask a stakeholder about behavior (not implementation) when they own the requirement, and state the behavior you want (not the mechanism) to implementers when you own it. Covers the implementer-direction mirror, two question techniques (turn internal insights into assumption checks, match the stakeholder's vocabulary), a worked example (temporal information on records), and the failure mode that motivates the rule. Applies to Slack drafts, meeting follow-ups, ADR Context-section research, and requirements handed down to contractors or vendor teams.

**`naming.md`** — Single name per concept across code, docs, ADRs, commit messages, and chat. Covers consistency (don't introduce synonyms for an existing concept) and adopting the domain expert's vocabulary in code. Companion to `stakeholder-questions.md`'s "Match the stakeholder's vocabulary" section — same discipline applied to naming the thing instead of asking about it. Distinct from the `naming-analyzer` skill, which judges quality of individual names rather than consistency across surfaces.
