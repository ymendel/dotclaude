# Stakeholder Questions

When drafting a question to a stakeholder, client, or non-engineer collaborator, ask about **behavior**, not about **implementation**. The stakeholder's job is to tell us what they need to be able to do and see; deciding how to store, structure, or validate the data behind that is ours.

This applies any time the answer will feed into engineering work — disambiguation messages on Slack, follow-up questions in a meeting recap, "before we build this, can you confirm…" notes, ADR Context-section research. Whenever the question is going *out* to someone whose role is to describe the work, not to implement it, this rule fires.

Sibling: the `requirements-clarity` skill governs *what to clarify* when requirements are vague (Why? / Simpler? against YAGNI/KISS). This rule governs *how to phrase* a clarification when the audience is external. They compose — clarity work that produces an outward question runs through both.

## Behavior vs. implementation

A behavior question asks what the stakeholder needs to be able to do, see, or rely on. An implementation question asks the stakeholder to choose between technical options or weigh storage/validation costs — choices they aren't positioned to make and shouldn't have to.

Implementation-flavored phrasing leaks even when it sounds plain. "Do you want the system to save both numbers separately, or is the most recent count the only one we need to remember?" is asking about *storage*. The behavior version is "do you need visibility into both?" — same decision-tree on our end, but framed as something the stakeholder can actually answer from their own work.

The pattern: rephrase the question until the words *the stakeholder uses to answer it* describe their work, not ours.

## Turn internal insights into assumption checks

When you have an implementation idea that depends on a behavioral fact being true, the question to ask the stakeholder is whether the fact is true in their work — not whether to do the implementation.

Worked example: the implementation idea was "we could carry the prior period's closing value forward as the default for the next period's opening, so users only enter a value when something has actually changed." The behavioral premise underneath it: "the value doesn't change between periods in ways the user doesn't already capture elsewhere." The question to ask is the premise, framed as an assumption-check: "Can we assume the opening value at period N is the same as the closing value at period N-1 unless told otherwise?"

The stakeholder answers from their experience of how the work actually flows. We get either confirmation (implementation idea is safe to pursue) or a counter-example we needed to know about (the implementation idea was unsafe in a way we hadn't seen). Either way, the question stays in their domain.

This is distinct from leading with the implementation — "should we auto-fill?" — which asks them to evaluate a technical choice. Same insight, different question shape, different answer quality.

## Match the stakeholder's vocabulary

When the question touches a concept that has both a project-internal name and an external one, use the internal name and let the stakeholder push back on it if it's off. "What we're currently calling the work order" beats describing what a work order is from first principles — it uses vocabulary they already use, and the "currently calling" hedge leaves room for them to disagree with the term. (This is Ubiquitous Language in the DDD sense — the model and its vocabulary are provisional, evolved jointly with the domain expert, not imposed from our side.)

This is small but compounds. Describing concepts from scratch when the stakeholder already has a word for them reads as either condescending (you're explaining their own work back to them) or as missing the existing shared vocabulary (in which case the rest of the question is built on uncertain ground).

## Worked example: temporal information on records

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

## Failure mode this prevents

A question phrased in implementation terms produces one of two failure modes:

- The stakeholder picks an option to be helpful, anchored on the framing we offered, and we lock in a model based on a choice they weren't equipped to make. The model later turns out wrong because the *behavior* it was supposed to support wasn't ever named.
- The stakeholder answers the implementation question correctly under one set of assumptions about cost and complexity, and we then discover the cost was different than the question implied (e.g., "save both" is cheap if we can auto-derive the start from prior state). The original answer no longer reflects what they'd actually have chosen if asked about behavior.

Either way, the engineering decision ends up anchored on the wrong axis. Asking about behavior keeps the engineering trade-off where it belongs — on our side — and lets the stakeholder answer from their own work.

## How to apply

Before sending a question outward, read it once and ask: *if I read this aloud to a non-engineer, would the answer be about what they need, or about a technical option I'm offering them?* If it's the latter, rewrite.

Pay particular attention to verbs like "save," "store," "remember," "track" — these almost always smuggle in implementation framing. "Do you need to see…" or "is it ever important to know…" usually clears it up.

When you can't see the behavior framing from where you sit, that's a signal to investigate the work the stakeholder actually does before composing the question, rather than asking them to do the translation.
