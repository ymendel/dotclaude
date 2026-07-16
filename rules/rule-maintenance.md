# Rule Maintenance

Procedures for correcting and updating the `~/.claude` configuration.

## Making Corrections

If the issue can be traced back to a rule or CLAUDE.md, make the correction there. If no appropriate rule can be found, add to `rules/feedback.md`.

If a skill was involved, find that skill's canonical path (Glob for the skill's name) before editing. All corrections must target that SKILL.md, never any other documentation.

A special case: when a bypassed skill's trigger and content were already complete and it simply wasn't invoked, add *no prose* anywhere — a reminder only duplicates the always-visible description and shares the very failure mode that caused the miss (passively-loaded text going unconsulted). Edit prose only for a genuine gap (trigger doesn't match, or content is missing); if such a bypass recurs enough to need enforcement, reach for a `PreToolUse` hook (ADR 0004's rule-vs-hook split), not another note.

When editing skill frontmatter descriptions, always quote the value as a YAML string (e.g. `description: "..."`). Unquoted multi-line scalars break when `: ` appears mid-value, causing the description to silently fail and the skill to show only its title.

The repository history captures the details — just report what changed and summarize.

## Get it down first, refine later

When changing a rule or skill, prioritize getting the substance down over polishing the specifics — exact wording, section placement, cross-references, heading style. The configuration is under version control and the user runs his own refinement pass in the dotclaude project, so a recorded-but-rough change beats a delayed-but-polished one. Capture the lesson while the context that exposed it is still fresh.

This goes double when the edit is made from inside another project rather than from dotclaude itself. There the surrounding rules aren't all in view, lint and review tooling aren't at hand, and the user will see and refine the edit later in dotclaude regardless. Don't stall an out-of-repo edit on getting the wording perfect — get it right in substance, report what changed, and leave the polish for the refinement pass.

Sibling: `self-improvement.md` governs *when* to capture a lesson — immediately, while the trigger is fresh. This governs *how polished* that capture has to be — rough is fine.

Failure mode this prevents: treating a rule edit like a public artifact that must ship perfect, which either delays the capture until the context has gone stale or drops it altogether. Because the config is recoverable, version-controlled, and owner-refined, over-polishing is pure cost.

## Writing Rules

Use imperative voice throughout ("do X", "never Y"). Avoid both first-person ("I will...") and second-person ("you should...") — "I" is ambiguous about whether the author is Claude or the user, "you" about whether it addresses Claude or the reader, and both create inconsistency across files. The imperative carries the actor implicitly, so neither pronoun is needed. When a rule must distinguish the agent's own actions from a human's, frame it by the situation (a programmatically issued command vs. an interactive prompt), not by a pronoun.

When writing a new rule, include the failure mode it prevents — not just what to do, but what goes wrong without it. Rules that only describe the happy path leave room for the exact failure they're meant to prevent.

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

Craft the entry from the command string the gate *actually matched*, never from an inferred or speculative invocation. The string the permission gate sees is not always the form written into the Bash call — the RTK hook rewrites some commands and passes others through unchanged (see `RTK.md`'s Golden Rule exception and `settings.md` on how patterns match). Before adding a pattern, look at the literal command that prompted; if none was observed, don't add a "just in case" entry. Confirmed 2026-07-15: a speculative `Bash(python3 *validate_handoff.py*)` entry turned out redundant because the command reaches the gate as a bare `python3 skills/session-handoff/scripts/validate_handoff.py …` string, already covered by the path-scoped `Bash(python3 *skills/session-handoff/scripts/*.py*)` glob. Failure mode: building the pattern from how the command *would* be written rather than from the string the gate matched, producing an entry that silently duplicates an existing rule (dead weight) or never fires (a false grant).

## Skill and Rule Review Criteria

When reviewing skills, rules, or their interactions, evaluate against these four concerns:

- **Redundancy**: Does the same guidance appear in multiple places? Skills should defer to each other rather than repeat.
- **Contradictions**: Do two sources give conflicting instructions? Resolve to a single authoritative source.
- **Effectiveness**: Will the skill/rule actually fire in the situations it's meant for? Check trigger language and workflow integration.
- **Completeness**: Does anything important fall through the gaps between skills/rules?
