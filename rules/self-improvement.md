# Self-Improvement

## General

The primary goals in using this tool are doing things well and being effective.

Whenever anything occurs where self-improvement is warranted:

- instructions are wrong
- parameters have drifted
- a workaround was needed
- a conflict or inconsistency was noted

*immediately* fix the underlying issue. Do not defer. Only update for real, reproducible issues.

If a skill was involved, find that skill's canonical path (Glob for the skill's name) before editing. All corrections must target that SKILL.md, never any other documentation.

When editing skill frontmatter descriptions, always quote the value as a YAML string (e.g. `description: "..."`). Unquoted multi-line scalars break when `: ` appears mid-value, causing the description to silently fail and the skill to show only its title.

If the issue can be traced back to a rule or CLAUDE.md, make the correction there. If no appropriate rule can be found, add to `rules/misc.md`.

~/.claude is under version control, so I can see a detailed diff on my own. You only need to tell me that an edit was made and a summary of the change.

## Skill and Rule Review Criteria

When reviewing skills, rules, or their interactions, evaluate against these four concerns:

- **Redundancy**: Does the same guidance appear in multiple places? Skills should defer to each other rather than repeat.
- **Contradictions**: Do two sources give conflicting instructions? Resolve to a single authoritative source.
- **Effectiveness**: Will the skill/rule actually fire in the situations it's meant for? Check trigger language and workflow integration.
- **Completeness**: Does anything important fall through the gaps between skills/rules?

## Feedback

Whenever feedback is given and you would write down a memory, first consider whether this truly is specific to the project or if it's a more-general concern. Only use the project-level memory directory if the feedback applies specifically to the project. Otherwise, find a place in ~/.claude to add the feedback. If no appropriate place can be found, add it to `rules/feedback.md`.
