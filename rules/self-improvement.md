# Self-Improvement

## General

The primary goals in using this tool are doing things well and being effective.

Whenever anything occurs where self-improvement is warranted, *immediately* fix the underlying issue. Do not defer. Only update for real, reproducible issues.

Concrete triggers — act on these without waiting to be asked:

- The user corrects my approach ("no, don't do that", "stop doing X", "that's wrong")
- I needed a workaround to complete a task (e.g., fell back to a less-correct method)
- A command failed and I had to diagnose and adjust before it worked
- I violated a rule I should have followed (discovered mid-task or after the fact)
- A conflict or inconsistency between two rules or instructions was noticed

If a skill was involved, find that skill's canonical path (Glob for the skill's name) before editing. All corrections must target that SKILL.md, never any other documentation.

When editing skill frontmatter descriptions, always quote the value as a YAML string (e.g. `description: "..."`). Unquoted multi-line scalars break when `: ` appears mid-value, causing the description to silently fail and the skill to show only its title.

If the issue can be traced back to a rule or CLAUDE.md, make the correction there. If no appropriate rule can be found, add to `rules/feedback.md`.

~/.claude is under version control, so I can see a detailed diff on my own. You only need to tell me that an edit was made and a summary of the change.

## Skill and Rule Review Criteria

When reviewing skills, rules, or their interactions, evaluate against these four concerns:

- **Redundancy**: Does the same guidance appear in multiple places? Skills should defer to each other rather than repeat.
- **Contradictions**: Do two sources give conflicting instructions? Resolve to a single authoritative source.
- **Effectiveness**: Will the skill/rule actually fire in the situations it's meant for? Check trigger language and workflow integration.
- **Completeness**: Does anything important fall through the gaps between skills/rules?

## Feedback

General feedback and lessons belong in `~/.claude` rule files — **not in project memory**. Project memory is for project-specific context (ongoing work, decisions, references). Behavioral corrections and general lessons are durable guidance that belongs in rules.

When feedback is given:
1. If it corrects a rule or skill: fix the source file directly (see General above).
2. If it's a general behavioral lesson with no existing rule: add it to `rules/feedback.md`.
3. Only use project-level memory if the feedback is genuinely specific to that project and would not apply elsewhere.
