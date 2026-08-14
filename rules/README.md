# Rules

Rule files govern how Claude should behave across all projects, not just in specific tasks. Most load unconditionally at session start. Files with `paths` frontmatter load only when Claude reads a matching file.

## Rules vs. skills

Rules load eagerly, skills load on demand when their trigger description matches the context. Behavioral defaults — guidance that should apply to every response — belong in rules. Procedural workflows with their own steps, templates, or references belong in skills.

A single concern occasionally splits across both. The `project-notes` rule covers the recognition habit — when to notice something filing-worthy. The `project-notes` skill covers the production workflow — how to file it once recognized. The rule fires unconditionally so recognition stays on. The skill loads only when invoked.

---

**`agents.md`** — When to use each available agent type. Covers the distinction between `Explore` and `codebase-pattern-finder`, when to reach for `Plan`, when specialized agents beat `general-purpose`, when to parallelize (including the big-ADR-kickoff trigger), why one agent is the shape a fan-out has to be asked to exceed, which delegation shapes carry a standing authorization to spawn without asking, which noisy reads to route to one of them, and which constraints to restate in a spawning prompt — needed only for `Explore` and `Plan`, the two agents that don't load these rules.

**`claude-directory-hygiene.md`** — Keeping a project's `.claude/` readable: which files belong at top level versus in a subdirectory, when a file belongs in `.claude/` at all rather than the session scratchpad, how transient artifacts (commit messages, PR bodies, issue drafts) are named, and the delete-when-the-content-lands-somewhere-permanent trigger that keeps them from accumulating. Owns file placement; `long-form-output.md` owns the file-versus-inline call.

**`code-style.md`** — General code style: trailing newlines, simplicity, parser libraries over regex, naming, consistency.

**`code-style-ruby.md`** — Ruby and Rails conventions: instance-oriented design, no metaprogramming, Symbol#to_proc, aesthetic preferences, Rake task syntax, and verifying model names before scripting against them. Path-scoped to `*.rb`, `*.rake`, `*.erb`, `Gemfile`, and `Rakefile`.

**`development-workflow.md`** — How work should be approached: planning vs. spikes, ADRs over proprietary plan modes, git discipline (small commits, specific staging, amend recent changes, draft PRs), durable references (reference by stable identity, not volatile locator), review scope, refactoring policy, and commenting conventions. Three references hang off it: edge-case git recipes in `references/development-workflow/git-recipes.md`, the per-case reference table in `durable-references.md`, and GitHub's issue-closing keyword behavior in `issue-closing-keywords.md`.

**`diagnosis.md`** — Diagnose before retrying. When a command fails or gives unexpected output, reason about why before issuing variants — including not routing around the user's shell configuration to silence a symptom. Includes specific cases for git tree-ish ambiguity and RTK diff filtering, plus the detector-validation rule — with the mechanics of probing whether a command prompts in `references/diagnosis/permission-prompt-probes.md`.

**`honesty.md`** — Rules about factual claims: never present estimates as measurements, source every number, verify the framing of external systems and codebase concepts against the source before writing prose about them, check the claims in prose you're committing on someone else's behalf rather than only its shape, separate verified facts from assumptions, don't optimize for looking helpful over being accurate. Applies extra scrutiny to any external-facing content.

**`searching.md`** — How to pick the right tool and scope when looking something up: scoping searches to the known location, staying out of the home directory apart from the installed-gem-source exception, never searching locally for external library docs, choosing between trafilatura, curl, and WebFetch, and preferring a tool's plain output over de-formatting its rendered output.

**`self-improvement.md`** — Triggers for when to self-improve: user corrections, workarounds, failed commands, violated rules, and inconsistencies. Points to `rule-maintenance.md` for how to act on them.

**`project-notes.md`** — Recognition triggers for long-running project notes that don't belong in code, commit messages, memory, or session handoffs: cleanup-debt, drafted upstream feedback, lessons for a derived-template. Covers the *when* to file. The `project-notes` skill covers structure and the *how*. Destinations are project-specific config.

**`cross-project-notes.md`** — Sibling to `project-notes.md` for findings that generalize beyond any single project and don't have an upstream / template / external destination yet. Names `~/.claude/notes/` as the durable home for those, with one file per topic (`template-lessons.md`, `postgres-quirks.md`, …). Directory is intentionally outside version control.

**`knowledge-grill.md`** — Companion rule for the `knowledge-grill` skill: suggest a backward, tacit-knowledge-extraction grill *before* knowledge walks away (exit, handoff, staffing change on the horizon), while the holder is still around to interview. The skill runs the interview and routes output to durable artifacts. This rule covers the *when*. Same skill+rule split as `project-notes`. Broader triggers are deferred — see `skills/knowledge-grill/TODO.md`.

**`knowledge-worker-toolkit.md`** — The map of the record-artifact skill family (`session-handoff`, `session-doc`, `project-notes`, ADRs, `orientation-doc`, `knowledge-grill`): what each captures, the boundary tests for when two seem to fit, and how to place a new member without overlapping an existing one. The authoritative cross-member view the individual skills defer to.

**`sensitive-knowledge.md`** — Companion production-hygiene rule to `knowledge-worker-toolkit.md`: when producing any artifact that lands in a repo (sharpest for the knowledge-worker toolkit), split system knowledge (commit) from people and relationship knowledge (route to a private, gitignored artifact) by default — keyed on the kind of knowledge, which can be read from the content, rather than on who owns the repo, which can't be reliably detected. Covers what counts as people knowledge, how to mark something safe to commit, and why repo ownership sets the stakes of a leak rather than the trigger. The family-wide statement of a split `knowledge-grill` and `orientation-doc` already carry inline.

**`rule-maintenance.md`** — Procedures for making corrections: where to edit skills and rules, YAML quoting requirements, feedback routing, permissions allow list, keeping `rules/README.md` up to date, and criteria for reviewing skills and rules.

**`feedback.md`** — Overflow for rules and feedback that don't fit an existing rule file. Periodically reviewed for extraction into topic-specific files.
**`RTK.md`** — Usage guide for RTK (Rust Token Killer), a token-optimized CLI proxy. Covers the hook scope limitation (Bash only, not built-in tools), the override for file/search operations, when not to reach for awk, and the golden rule plus its passthrough exceptions. Command tables and install troubleshooting are in `references/rtk/commands.md`; the `find`/`grep` empty-result traps are in `references/rtk/traps.md`; awk's three wrong-reach cases are in `references/rtk/awk.md` — all three pointed at from the rule.

**`tool-and-shell-safety.md`** — Operating the shell and file tools without silent misfires: don't reflexively `cd` into the working directory (gated by `reflexive-cd-guard.sh`, whose blocked-and-allowed breakdown is in `references/tool-and-shell-safety/cd-guard.md`), don't escape inside single-quoted heredocs, invoke a project script by the relative path its allow rule names, verify where an assembled Write path actually landed, and copy off-disk-only state before overwriting it when a pending decision depends on it.

**`settings.md`** — Gotchas and conventions for `settings.json`, grouped as how a rule matches and why a command prompts (permission globs, Bash string matching, compound commands, shell expansion, deny substrings, escaped whitespace), how to choose and organize entries (which of the three files, skill-script grants, the offered-save trap, allow-list layout), and hook mechanics (per-hook-type output, exit 2 over JSON deny). Path-scoped to `settings.json` and `settings.local.json`. Permission behavior through the `~/.claude → dotclaude` symlink is in `references/settings/claude-symlink.md`.

**`long-form-output.md`** — Where content the user must read or decide on has to live so they reliably see it. Main case: long output goes to a file with a short pointer in chat, not dumped inline; which directory that file lands in is `claude-directory-hygiene.md`'s call. Also covers two non-file cases — a decision-critical AskUserQuestion option and a claimed-visible finding — which belong in the chat message itself, not a clipped preview or ephemeral tool output.

**`writing.md`** — User-specific writing preferences that supplement the `writing-clearly-and-concisely` skill: avoid violent metaphors and military or war-origin idioms (including "in anger"); emulate the user's voice when appropriate (register, archaic Latin abbreviations like `&c.`, `viz.`, `cf.`), without mirroring his lowercase prompting shorthand in formal output.

**`stakeholder-questions.md`** — Keep *behavior* with whoever owns the requirement and *implementation* with engineering, in both directions: ask a stakeholder about behavior (not implementation) when they own the requirement, and state the behavior you want (not the mechanism) to implementers when you own it. Covers the implementer-direction mirror, two question techniques (turn internal insights into assumption checks, match the stakeholder's vocabulary), and the failure mode that motivates the rule. Three references hang off it: worked examples (currently temporal information on records) in `references/stakeholder-questions/worked-examples.md`, the mechanism-versus-outcome case in `requirements-to-implementers.md`, and the limits on a correctable best guess in `correctable-best-guess.md`. Applies to Slack drafts, meeting follow-ups, ADR Context-section research, and requirements handed down to contractors or vendor teams.

**`naming.md`** — Single name per concept across code, docs, ADRs, commit messages, and chat. Covers consistency (don't introduce synonyms for an existing concept), adopting the domain expert's vocabulary in code, and the serialize/deserialize default for object-to-persisted-form vocabulary (full model in `references/naming/serialization-vocabulary.md`). Companion to `stakeholder-questions.md`'s "Match the stakeholder's vocabulary" section — same discipline applied to naming the thing instead of asking about it. Distinct from the `naming-analyzer` skill, which judges quality of individual names rather than consistency across surfaces.
