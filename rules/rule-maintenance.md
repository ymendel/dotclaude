# Rule Maintenance

Procedures for correcting and updating the `~/.claude` configuration.

## How rules load

`rules/*.md` load into context automatically via Claude Code's native memory-directory discovery — there is **no** `@import` in the root `CLAUDE.md`, so don't go looking for one. A rule file is *not* always-loaded when it is listed in `settings.json`'s `claudeMdExcludes` (e.g. `README.md`), carries `paths:` frontmatter that loads it only on matching paths (e.g. `settings.md`, `code-style-ruby.md`), or lives under `rules/references/` (consult-on-demand material excluded by one glob — see [ADR 0007](../docs/adr/0007-progressive-disclosure-for-rules.md)). `/context` lists exactly what loaded.

## Making Corrections

If the issue can be traced back to a rule or CLAUDE.md, make the correction there. If no appropriate rule can be found, add to `rules/feedback.md`.

Prefer relocating the correction to an action-keyed general rule over patching the site that failed. When a vague instruction at one call site produces a failure, the reflex is to expand that site with more prose — but a rule keyed on the *action* fires wherever the reflex shows up, while prose keyed on one site's phrasing fires only where it first bit. Leave a light pointer at the site and let the general rule carry the substance. Where even an action-keyed rule gets bypassed, the next rung is a hook rather than a third draft of the prose — see the special case below and [ADR 0004](../docs/adr/0004-rule-vs-hook-enforcement-split.md).

If a skill was involved, find that skill's canonical path (Glob for the skill's name) before editing. All corrections must target that SKILL.md, never any other documentation.

A special case: when a bypassed skill's trigger and content were already complete and it simply wasn't invoked, add *no prose* anywhere — a reminder only duplicates the always-visible description and shares the very failure mode that caused the miss (passively-loaded text going unconsulted). Edit prose only for a genuine gap (trigger doesn't match, or content is missing). If such a bypass recurs enough to need enforcement, reach for a `PreToolUse` hook (ADR 0004's rule-vs-hook split), not another note.

When editing skill frontmatter descriptions, always quote the value as a YAML string (e.g. `description: "..."`). Unquoted multi-line scalars break when `: ` appears mid-value, causing the description to silently fail and the skill to show only its title.

The repository history captures the details — just report what changed and summarize.

## Disambiguate global vs. project scope before editing

When the user refers to "the rule", "the skill", "settings.json", "the hook", or a similar artifact that exists in both global (`~/.claude/...`) and project-local (`.claude/...`, `CLAUDE.md`) forms, ask which scope is meant before editing — unless the surrounding context makes it unambiguous (e.g., the user just opened the global file, or just named a project-only artifact).

**Why:** Ambiguity here has consistently produced edit-and-revert cycles where Claude guessed the wrong scope. The user shouldn't have to talk like a robot ("the global naming-analyzer skill") to keep Claude from guessing — one disambiguating question is cheaper than a wrong edit.

**How to apply:** A one-line question is enough: "Global `~/.claude/settings.json` or project `.claude/settings.json`?" Do not begin editing or searching until the scope is settled. When the context truly is unambiguous, proceed without asking — over-asking is its own friction.

**Exception — the `dotclaude` repo itself:** `~/.claude` is a symlink to this repo (per its Makefile). The two paths are one tree, one set of files — there is no global-vs-project distinction to resolve. Don't diff `~/.claude/X` against `dotclaude/X`, and don't ask which scope. Editing either edits the live config. When the answer to "how do these two paths relate" is wanted, it's structural (the symlink) and documented (Makefile, README) — reach for those, not an empirical diff. See `settings.md`'s `~/.claude → dotclaude` section for the permission-matching consequences of the symlink.

## Get it down first, refine later

When changing a rule or skill, prioritize getting the substance down over polishing the specifics — exact wording, section placement, cross-references, heading style. The configuration is under version control and the user runs his own refinement pass in the dotclaude project, so a recorded-but-rough change beats a delayed-but-polished one. Capture the lesson while the context that exposed it is still fresh.

This goes double when the edit is made from inside another project rather than from dotclaude itself. There the surrounding rules aren't all in view, lint and review tooling aren't at hand, and the user will see and refine the edit later in dotclaude regardless. Don't stall an out-of-repo edit on getting the wording perfect — get it right in substance, report what changed, and leave the polish for the refinement pass.

**Where a session in either config tree is reachable, message it rather than commit.** Peer sessions are listable with `ListAgents` and addressable with `SendMessage`, so an out-of-repo edit can hand its context to a session already sitting in the config tree — what the edit is for, the incident behind it, which parts were left rough. That avoids the two options such an edit otherwise picks between. One is committing the change from outside, which invites an amend as soon as the wording gets reworked in the refinement pass. The other is loading the rule prose with the dated incident and the provenance that belong in a commit body, per *Where dated observations go* below — a message carries both without either landing in an always-loaded file. Read *either tree* literally: a private rule reached through the `rules/private` symlink is a rule edit like any other, so the public repo's name is not what decides this. The listing names sessions rather than the directories they run in, so such a session is not always identifiable there and often is not running at all. When none is, report what changed and leave it, exactly as above.

What decides it is the artifact, not the repo. This governs a rule or a skill. A note filed under `notes/` goes straight in per `cross-project-notes.md`, which asks only for a one-line report of where it landed — a note composes with nothing, never loads always-on, and exists to hold the dated observation rule prose has to route away. The shared surface a note does have is its index line, since `notes/README.md` and `ideas/README.md` each take appends from any session at once, so expect to resolve a conflict there rather than to prevent one by messaging.

Sibling: `self-improvement.md` governs *when* to capture a lesson — immediately, while the trigger is fresh. This governs *how polished* that capture has to be — rough is fine.

Failure mode this prevents: treating a rule edit like a public artifact that must ship perfect, which either delays the capture until the context has gone stale or drops it altogether. Because the config is recoverable, version-controlled, and owner-refined, over-polishing is pure cost.

## Writing Rules

Use imperative voice throughout ("do X", "never Y"). Avoid both first-person ("I will...") and second-person ("you should...") — "I" is ambiguous about whether the author is Claude or the user, "you" about whether it addresses Claude or the reader, and both create inconsistency across files. The imperative carries the actor implicitly, so neither pronoun is needed. When a rule must distinguish the agent's own actions from a human's, frame it by the situation (a programmatically issued command vs. an interactive prompt), not by a pronoun.

When writing a new rule, include the failure mode it prevents — not just what to do, but what goes wrong without it. Rules that only describe the happy path leave room for the exact failure they're meant to prevent.

## Where dated observations go

Dated observations, confirmation records ("Confirmed <date>: …"), and "here's the incident that motivated this" asides belong in the commit body that introduces or changes a rule — git history — not in the always-loaded rule prose. Keep the actionable directive and the failure-mode-it-prevents in the rule. Move the dated incident to the commit. This is ADR 0007's destination 3 (see [ADR 0007](../docs/adr/0007-progressive-disclosure-for-rules.md) for the full four-destination routing policy). The one nuance: where an incident carried reusable insight, keep a compressed, un-dated version of that insight in prose and move only the dated narrative to the commit.

**The incident travels de-identified.** Most rule edits originate in another project, so the incident routed into the commit body arrives carrying that project's name, repo, file paths, and sometimes a client's. This repo is public. Keep the date, the mechanism, and what it cost; drop the identifiers, or generalize them ("that repository's own workflow" rather than the repo by name). This is `code-style.md`'s *Invent example values* applied to provenance rather than to example values — same trap, and the commit body is the channel that walks into it, because routing incidents there is exactly what the paragraph above asks for.

Failure mode this prevents: incident narratives accrete in always-loaded prose, growing the context floor with documentation of what happened rather than guidance on what to do. And the correctly-routed ones carry a client or project identifier into public git history, where — unlike prose in a file — it can only be removed by rewriting published commits.

## Referencing skills and other rules

A rule may reference a skill or another rule freely. Rules load passively in the same config where everything they reference already co-resides, so the pointer never dangles — the target is present whenever the rule fires.

The reverse direction is fragile, and it is the skill author's concern, not the rule author's — a *skill* that references a rule may ship to an environment where that rule is absent, because rules never travel with a skill package. The `skill-architecture` skill covers how a skill degrades gracefully there (a `COMPANIONS.md` entry, a conditional sentence). Nothing symmetric is needed when writing a rule — cross-reference skills and rules as freely as the prose wants.

## Rule File Index

When adding a new rule file, update `rules/README.md` with a description before committing.

## Feedback Routing

General feedback and lessons belong in `~/.claude` rule files — **not in project memory**. Project memory is for project-specific context (ongoing work, decisions, references). Behavioral corrections and general lessons are durable guidance that belongs in rules.

When feedback is given:
1. If it corrects a rule or skill: fix the source file directly (see Making Corrections above).
2. If it's a general behavioral lesson with no existing rule: add it to `rules/feedback.md`.
3. Only use project-level memory if the feedback is genuinely specific to that project and would not apply elsewhere.

Observations about how global tools behave (e.g., RTK filtering output unexpectedly) count as corrections to the relevant rule file — go there directly, not project memory.

## Permissions Allow List

When the user approves a Bash permission prompt, ask whether it was a one-time command or should be added to the allow list in `settings.json`. If they want it added, do so immediately — do not let other work cause this follow-up to be skipped or deferred.

Craft the entry from the command string the gate *actually matched*, never from an inferred or speculative invocation. The string the permission gate sees is not always the form written into the Bash call — the RTK hook rewrites some commands and passes others through unchanged (see `RTK.md`'s Golden Rule exception and `settings.md` on how patterns match). Before adding a pattern, look at the literal command that prompted. If none was observed, don't add a "just in case" entry. Failure mode: building the pattern from how the command *would* be written rather than from the string the gate matched, producing an entry that silently duplicates an existing rule (dead weight) or never fires (a false grant).

**Prompt frequency is not an argument for breadth.** A run of near-identical prompts reads as friction the allow list should remove, and the entry that would remove it is usually the broad one — a whole interpreter, a bare path glob, a whole tool. The interruption is doing work the user wants, being where they see what is about to run and stay the owner of the result, which outweighs an uninterrupted investigation. So report what is prompting and name the entry that would end it, but never offer that entry as a remedy for the volume. Where a genuinely narrow entry covers the case, propose it and say what it leaves prompting. The worked case is the inline-`-e` bullet in `claude-directory-hygiene.md`, where the only entry that would stop the prompts is a standing grant to run arbitrary code and the path-scoped alternative constrains almost nothing.

Failure mode this prevents: the case for a grant gets built from how often the prompt fires rather than from what the grant would permit, and it arrives sounding like the removal of friction rather than the removal of a control.

## Skill and Rule Review Criteria

When reviewing skills, rules, or their interactions, evaluate against these four concerns:

- **Redundancy**: Does the same guidance appear in multiple places? Skills should defer to each other rather than repeat.
- **Contradictions**: Do two sources give conflicting instructions? Resolve to a single authoritative source.
- **Effectiveness**: Will the skill/rule actually fire in the situations it's meant for? Check trigger language and workflow integration.
- **Completeness**: Does anything important fall through the gaps between skills/rules?

## Show templates in full, don't compress them

When reviewing or designing a skill, "don't restate what Claude already knows" (the standard knowledge-delta rubric) applies to *concepts and procedures*, not to *templates and reference artifacts*. A template is the artifact the model is supposed to produce — showing it in full is what makes the output reliable. Compressing it to "you know the standard shape, right?" risks drift in exactly the parts that matter (heading capitalization, status vocabulary, section ordering, project-specific overlays like a required prefix or label).

**How to apply:** When skill-judge or any similar review flags a section as "Claude already knows this", ask whether the section is a *template/example to copy* or *guidance to internalize*. If template/example, the right action is keep-and-tighten (drop redundant examples, keep the canonical one), not compress-to-pointer. If guidance, the standard compression rule applies.
