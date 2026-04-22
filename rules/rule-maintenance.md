# Rule Maintenance

Procedures for correcting and updating the `~/.claude` configuration.

## Making Corrections

If the issue can be traced back to a rule or CLAUDE.md, make the correction there. If no appropriate rule can be found, add to `rules/feedback.md`.

If a skill was involved, find that skill's canonical path (Glob for the skill's name) before editing. All corrections must target that SKILL.md, never any other documentation.

When editing skill frontmatter descriptions, always quote the value as a YAML string (e.g. `description: "..."`). Unquoted multi-line scalars break when `: ` appears mid-value, causing the description to silently fail and the skill to show only its title.

`~/.claude` is under version control, so I can see a detailed diff on my own. You only need to tell me that an edit was made and a summary of the change.

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

## Skill and Rule Review Criteria

When reviewing skills, rules, or their interactions, evaluate against these four concerns:

- **Redundancy**: Does the same guidance appear in multiple places? Skills should defer to each other rather than repeat.
- **Contradictions**: Do two sources give conflicting instructions? Resolve to a single authoritative source.
- **Effectiveness**: Will the skill/rule actually fire in the situations it's meant for? Check trigger language and workflow integration.
- **Completeness**: Does anything important fall through the gaps between skills/rules?
