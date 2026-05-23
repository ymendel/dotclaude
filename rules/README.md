# Rules

Rule files govern how Claude should behave across all projects, not just in specific tasks. Most load unconditionally at session start; files with `paths` frontmatter load only when Claude reads a matching file.

---

**`agents.md`** — When to use each available agent type. Covers the distinction between `Explore` and `codebase-pattern-finder`, when to reach for `Plan`, when specialized agents beat `general-purpose`, and when to parallelize.

**`code-style.md`** — General code style: trailing newlines, simplicity, parser libraries over regex, naming, consistency.

**`code-style-ruby.md`** — Ruby and Rails conventions: instance-oriented design, no metaprogramming, Symbol#to_proc, aesthetic preferences, Rake task syntax, and verifying model names before scripting against them. Path-scoped to `*.rb`, `*.rake`, `*.erb`, `Gemfile`, and `Rakefile`.

**`development-workflow.md`** — How work should be approached: planning vs. spikes, ADRs over proprietary plan modes, git discipline (small commits, specific staging, amend recent changes, draft PRs), review scope, refactoring policy, and commenting conventions.

**`diagnosis.md`** — Diagnose before retrying. When a command fails or gives unexpected output, reason about why before issuing variants — including not routing around the user's shell configuration to silence a symptom. Includes specific cases for git tree-ish ambiguity and RTK diff filtering.

**`honesty.md`** — Rules about quantitative claims: never present estimates as measurements, source every number, separate verified facts from assumptions, don't optimize for looking helpful over being accurate. Applies extra scrutiny to any external-facing content.

**`searching.md`** — How to pick the right tool and scope when looking something up: scoping searches to the known location, never searching locally for external library docs, and choosing between WebFetch and raw curl.

**`self-improvement.md`** — Triggers for when to self-improve: user corrections, workarounds, failed commands, violated rules, and inconsistencies. Points to `rule-maintenance.md` for how to act on them.

**`project-notes.md`** — Recognition triggers for long-running project notes that don't belong in code, commit messages, memory, or session handoffs: cleanup-debt, drafted upstream feedback, lessons for a derived-template. Covers the *when* to file; the `project-notes` skill covers structure and the *how*. Destinations are project-specific config.

**`cross-project-notes.md`** — Sibling to `project-notes.md` for findings that generalize beyond any single project and don't have an upstream / template / external destination yet. Names `~/.claude/notes/` as the durable home for those, with one file per topic (`template-lessons.md`, `postgres-quirks.md`, …). Directory is intentionally outside version control.

**`rule-maintenance.md`** — Procedures for making corrections: where to edit skills and rules, YAML quoting requirements, feedback routing, permissions allow list, keeping `rules/README.md` up to date, and criteria for reviewing skills and rules.

**`feedback.md`** — Overflow for rules and feedback that don't fit an existing rule file. Periodically reviewed for extraction into topic-specific files.

**`graphify.md`** — How to use a graphify knowledge graph when one is present in a project (`graphify-out/graph.json`). Conditional: applies only when the artifact exists, surfaced via `PreToolUse` and `SessionStart` hooks.

**`RTK.md`** — Usage guide for RTK (Rust Token Killer), a token-optimized CLI proxy. Covers the hook scope limitation (Bash only, not built-in tools), the override for file/search operations, and command reference by workflow.

**`settings.md`** — Gotchas for `settings.json`: tilde vs. `$HOME` in path fields, `*` vs. `**` in permission globs, and backslash-escaped whitespace triggering permission dialogs.

**`writing.md`** — User-specific writing preferences that supplement the `writing-clearly-and-concisely` skill: avoid violent metaphors and military or war-origin idioms (including "in anger"); emulate the user's voice when appropriate (register, archaic Latin abbreviations like `&c.`, `viz.`, `cf.`), without mirroring his lowercase prompting shorthand in formal output.
