# Feedback

Overflow for rules and feedback that don't fit an existing rule file. When in doubt, capture a lesson here rather than agonizing over its permanent home or skipping it — but this file loads into context every session like any rule, so it's revisable staging, not free staging. Periodically review: if an entry has grown into a pattern or belongs with a coherent topic, extract it into an appropriate rule file; prune what hasn't earned its place rather than letting the file accrete.

## Disambiguate global vs. project scope before editing

When the user refers to "the rule," "the skill," "settings.json," "the hook," or a similar artifact that exists in both global (`~/.claude/...`) and project-local (`.claude/...`, `CLAUDE.md`) forms, ask which scope is meant before editing — unless the surrounding context makes it unambiguous (e.g., the user just opened the global file, or just named a project-only artifact).

**Why:** Ambiguity here has consistently produced edit-and-revert cycles where Claude guessed the wrong scope. The user shouldn't have to talk like a robot ("the global naming-analyzer skill") to keep Claude from guessing — one disambiguating question is cheaper than a wrong edit.

**How to apply:** A one-line question is enough: "Global `~/.claude/settings.json` or project `.claude/settings.json`?" Do not begin editing or searching until the scope is settled. When the context truly is unambiguous, proceed without asking — over-asking is its own friction.

## Show templates in full; don't compress them

When reviewing or designing a skill, "don't restate what Claude already knows" (the standard knowledge-delta rubric) applies to *concepts and procedures*, not to *templates and reference artifacts*. A template is the artifact the model is supposed to produce — showing it in full is what makes the output reliable. Compressing it to "you know the standard shape, right?" risks drift in exactly the parts that matter (heading capitalization, status vocabulary, section ordering, project-specific overlays like a required prefix or label).

**Why:** Misapplied this on 2026-05-21 when reviewing the `adr` skill via `skill-judge`. Suggested cutting the Nygard template restatement as "Activation, Claude knows this" — but the template was the *artifact*, and the project-specific Consequences-valence prescription was baked into it inline. Cutting it would have undone work just done to make that prescription concrete. User caught it.

**How to apply:** When skill-judge or any similar review flags a section as "Claude already knows this," ask whether the section is a *template/example to copy* or *guidance to internalize*. If template/example, the right action is keep-and-tighten (drop redundant examples, keep the canonical one), not compress-to-pointer. If guidance, the standard compression rule applies.

## Don't escape inside single-quoted heredocs

In a `<<'EOF'` heredoc (single-quoted delimiter), the shell preserves content literally — no parameter expansion, no command substitution, no backslash processing. Backticks, double-quotes, and dollar signs inside one don't need escaping; doing so ships the literal backslash through to whatever consumes the heredoc.

**Why:** On 2026-05-31, I filed a GitHub issue with `gh issue create --body "$(cat <<'EOF' ... EOF)"` and reflexively escaped backtick fences (`` \`\`\` ``) and quoted Ruby strings (`\"`) inside the body. The result rendered with literal backslashes wherever markdown was supposed to format — broken code fences, broken quotes. User caught it and asked for a fix. The escaping was a reflex carried over from double-quoted contexts, where backslashes do matter.

**How to apply:** When writing inside `<<'EOF'`, write content as-is. The single-quoted delimiter is the explicit "treat this as a string literal" signal; escaping inside it always overshoots. If you find yourself reaching for a backslash inside a heredoc, check the opening — if it's `'EOF'`, don't. (The same caution applies in reverse to `<<EOF` without quotes, where backticks and dollar signs *do* need escaping if you want them literal.)
