# Rules

Rule files govern how Claude should behave across all projects, not just in specific tasks. Most load unconditionally at session start; files with `paths` frontmatter load only when Claude reads a matching file.

---

**`agents.md`** — When to use each available agent type. Covers the distinction between `Explore` and `codebase-pattern-finder`, when to reach for `Plan`, when specialized agents beat `general-purpose`, and when to parallelize.

**`adrs.md`** — Format, writing style, and lifecycle for Architecture Decision Records. Covers the required sections (Context, Decision, Consequences), immutability rules, and how to reference superseding ADRs. Pairs with the `adr` skill, which handles actually writing them.

**`code-style.md`** — General code style: trailing newlines, simplicity, parser libraries over regex, naming, consistency.

**`code-style-ruby.md`** — Ruby and Rails conventions: instance-oriented design, no metaprogramming, Symbol#to_proc, aesthetic preferences, Rake task syntax, and testing (factories, not fixtures). Path-scoped to `*.rb`, `*.rake`, `*.erb`, `Gemfile`, and `Rakefile`.

**`development-workflow.md`** — How work should be approached: planning vs. spikes, ADRs over proprietary plan modes, git discipline (small commits, specific staging, amend recent changes, draft PRs), refactoring policy, and commenting conventions.

**`honesty.md`** — Rules about quantitative claims: never present estimates as measurements, source every number, separate verified facts from assumptions, don't optimize for looking helpful over being accurate. Applies extra scrutiny to any external-facing content.

**`self-improvement.md`** — Triggers for when to self-improve: user corrections, workarounds, failed commands, violated rules, and inconsistencies. Points to `rule-maintenance.md` for how to act on them.

**`rule-maintenance.md`** — Procedures for making corrections: where to edit skills and rules, YAML quoting requirements, feedback routing, permissions allow list, keeping `rules/README.md` up to date, and criteria for reviewing skills and rules.

**`feedback.md`** — Overflow for rules and feedback that don't fit an existing rule file. Periodically reviewed for extraction into topic-specific files.

**`graphify.md`** — How to use a graphify knowledge graph when one is present in a project (`graphify-out/graph.json`). Conditional: applies only when the artifact exists, surfaced via `PreToolUse` and `SessionStart` hooks.

**`RTK.md`** — Usage guide for RTK (Rust Token Killer), a token-optimized CLI proxy. Covers the hook scope limitation (Bash only, not built-in tools), the override for file/search operations, and command reference by workflow.

**`settings.md`** — Gotchas for `settings.json`: tilde vs. `$HOME` in path fields, `*` vs. `**` in permission globs, and backslash-escaped whitespace triggering permission dialogs.
