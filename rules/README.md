# Rules

Rule files are always loaded into context — unlike skills, they don't need to be invoked. They govern how Claude should behave across all projects, not just in specific tasks.

---

**`adrs.md`** — Format, writing style, and lifecycle for Architecture Decision Records. Covers the required sections (Context, Decision, Consequences), immutability rules, and how to reference superseding ADRs. Pairs with the `adr` skill, which handles actually writing them.

**`code-style.md`** — General code style (trailing newlines, simplicity, parser libraries over regex) plus Ruby- and Rails-specific conventions. Aesthetic preferences, naming rules, and testing guidance (factories, not fixtures).

**`development-workflow.md`** — How work should be approached: planning vs. spikes, ADRs over proprietary plan modes, git discipline (small commits, specific staging, amend recent changes, draft PRs), refactoring policy, and commenting conventions.

**`honesty.md`** — Rules about quantitative claims: never present estimates as measurements, source every number, separate verified facts from assumptions, don't optimize for looking helpful over being accurate. Applies extra scrutiny to any external-facing content.

**`self-improvement.md`** — When and how to fix the config itself. Errors, drifted parameters, and workarounds should be corrected immediately in the canonical location (the relevant SKILL.md, rule file, or CLAUDE.md). Feedback that isn't project-specific lives in `~/.claude`.

**`feedback.md`** — Overflow for feedback that doesn't fit an existing rule file.

**`misc.md`** — Overflow for rules that don't fit elsewhere.

**`RTK.md`** — Usage guide for RTK (Rust Token Killer), a token-optimized CLI proxy. Covers the hook scope limitation (Bash only, not built-in tools), the override for file/search operations, and command reference by workflow.
