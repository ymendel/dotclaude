# Stakeholder Questions — Worked Examples

> Not loaded in context by default. See `rules/stakeholder-questions.md` for behavioral guidance.

## Temporal information on records

When a record's state changes over time, the implementation choices are:

1. No time tracking.
2. A single timestamp per record (e.g., `updated_at`).
3. A validity range per record (valid-from / valid-to).
4. A full history of changes (audit log, event sourcing).

Plus cross-cutting choices that apply regardless of which of the above is chosen: nullability, overlap rules, gap rules, edge handling.

These are not the questions to ask. The behavior questions that point us toward the right implementation are:

1. Do you need to see how things looked at a particular past time, or are you only ever concerned with what's valid right now?
2. If you need history, do you need to operate on snapshots ("what was the state on March 1?") or on validity ranges ("this rate is in effect from X to Y")?
3. Can two things apply at the same time? (i.e., are overlapping ranges meaningful?)
4. Is something always in effect, or can there be a gap with nothing valid?

The answers settle the implementation without asking the stakeholder to think about it. These also belong in the **Context** section of an ADR, feeding the Decision.
