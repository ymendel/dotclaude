# Feedback

Overflow for rules and feedback that don't fit an existing rule file. Periodically review this file — if an entry has grown into a pattern or belongs with a coherent topic, extract it into an appropriate rule file rather than leaving it here indefinitely.

## Show templates in full; don't compress them

When reviewing or designing a skill, "don't restate what Claude already knows" (the standard knowledge-delta rubric) applies to *concepts and procedures*, not to *templates and reference artifacts*. A template is the artifact the model is supposed to produce — showing it in full is what makes the output reliable. Compressing it to "you know the standard shape, right?" risks drift in exactly the parts that matter (heading capitalization, status vocabulary, section ordering, project-specific overlays like a required prefix or label).

**Why:** Misapplied this on 2026-05-21 when reviewing the `adr` skill via `skill-judge`. Suggested cutting the Nygard template restatement as "Activation, Claude knows this" — but the template was the *artifact*, and the project-specific Consequences-valence prescription was baked into it inline. Cutting it would have undone work just done to make that prescription concrete. User caught it.

**How to apply:** When skill-judge or any similar review flags a section as "Claude already knows this," ask whether the section is a *template/example to copy* or *guidance to internalize*. If template/example, the right action is keep-and-tighten (drop redundant examples, keep the canonical one), not compress-to-pointer. If guidance, the standard compression rule applies.
