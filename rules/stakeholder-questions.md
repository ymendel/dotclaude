# Stakeholder Questions

When drafting a question to a stakeholder, client, or non-engineer collaborator, ask about **behavior**, not about **implementation**. The stakeholder's job is to tell us what they need to be able to do and see. Deciding how to store, structure, or validate the data behind that is ours.

The split underneath is what matters: *behavior* belongs to whoever owns the requirement, *implementation* to engineering. It runs both directions — **asking** about behavior when someone else owns the requirement (most of this rule), and **telling** implementers the behavior you want when you own it (*Communicating a requirement you own*, below).

This applies any time the answer will feed into engineering work — disambiguation messages on Slack, follow-up questions in a meeting recap, "before we build this, can you confirm…" notes, ADR Context-section research. Whenever the question is going *out* to someone whose role is to describe the work, not to implement it, this rule fires.

Sibling: the `requirements-clarity` skill governs *what to clarify* when requirements are vague (Why? / Simpler? against YAGNI/KISS). This rule governs *how to phrase* a clarification when the audience is external. They compose — clarity work that produces an outward question runs through both.

## Behavior vs. implementation

A behavior question asks what the stakeholder needs to be able to do, see, or rely on. An implementation question asks the stakeholder to choose between technical options or weigh storage/validation costs — choices they aren't positioned to make and shouldn't have to.

Implementation-flavored phrasing leaks even when it sounds plain. "Do you want the system to save both numbers separately, or is the most recent count the only one we need to remember?" is asking about *storage*. The behavior version is "do you need visibility into both?" — same decision-tree on our end, but framed as something the stakeholder can actually answer from their own work.

The pattern: rephrase the question until the words *the stakeholder uses to answer it* describe their work, not ours.

## Communicating a requirement you own to implementers

The rest of this rule covers *asking* a stakeholder about behavior when *they* own the requirements. The mirror image is just as load-bearing: when *you* own the requirement and are communicating it *down* to whoever implements (contractors, a vendor team, another engineer), specify the **behavior you want** and leave the **implementation** for them to work out. Same behavior-vs-implementation line, opposite direction — there it's a question going out, here it's a directive going out.

Why the discipline matters in this direction too: the behavior is the durable interface, the implementation is downstream of it. If you hand implementers a mechanism ("set up a Heroku pipeline to promote staging to production"), you've made a technical choice that may not fit their stack, and you've coupled the outcome you actually want to one particular way of getting there. State the outcome instead ("a change is done when it's live in production and confirmed working") and let them propose the mechanism that fits. You keep ownership of *what* and *why*. They own *how*. This is the same split as a good ADR — Decision and Context are yours, the implementation detail is negotiable.

This composes with **Match the stakeholder's vocabulary** below and with `naming.md`'s *Adopt the domain expert's term*: when you state the desired behavior, use the words the implementers already use for the concept, so the requirement lands in their vocabulary rather than imposing yours.

Concrete tells that you've slipped into dictating implementation: naming a specific tool, service, or pipeline; prescribing a data structure or storage scheme; specifying *the steps* rather than *the end state*. When you catch one, rewrite to the behavior it was meant to produce and add — if useful — "here are options we could consider, for you to weigh," explicitly provisional.

Failure mode this prevents: handing implementers a solution dressed as a requirement. They either follow it even though a better fit exists in their context, or they push back and the conversation re-litigates the mechanism instead of confirming the behavior — when the behavior was the only thing you actually needed to pin down.

## Turn internal insights into assumption checks

When you have an implementation idea that depends on a behavioral fact being true, the question to ask the stakeholder is whether the fact is true in their work — not whether to do the implementation.

Worked example: the implementation idea was "we could carry the prior period's closing value forward as the default for the next period's opening, so users only enter a value when something has actually changed". The behavioral premise underneath it: "the value doesn't change between periods in ways the user doesn't already capture elsewhere". The question to ask is the premise, framed as an assumption-check: "Can we assume the opening value at period N is the same as the closing value at period N-1 unless told otherwise?"

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

Pay particular attention to verbs like "save", "store", "remember", "track" — these almost always smuggle in implementation framing. "Do you need to see…" or "is it ever important to know…" usually clears it up.

When you can't see the behavior framing from where you sit, that's a signal to investigate the work the stakeholder actually does before composing the question, rather than asking them to do the translation.

## Offer a correctable best guess, not an open question

When you need a fact, preference, or decision from someone who holds the answer and an open question isn't getting it, put your genuine best guess in front of them plainly and let them correct it. A concrete claim someone can disagree with pulls a correction where an open question pulls silence — "we're treating weekend orders as next-business-day fulfillment, correct?" gets fixed fast if it's wrong, where "how should we handle weekend orders?" gets a shrug. This is [Cunningham's Law](https://en.wikipedia.org/wiki/Cunningham%27s_Law) in its good-faith form — not stating something false to provoke, but floating a real best guess as bait for the right answer.

Keep it honest. The guess is offered in good faith, and the audible-hedge habit (`rules/references/writing/voice.md`, "Keep factual-uncertainty hedges audible") still rides along — it reads as a guess, not a settled fact. The edge to watch is strawman drift: don't sharpen the guess into something you know is wrong to force a reaction. That tips the technique into the dishonest version of itself.

Bound it to claims aimed at someone who can correct them — a stakeholder, client, or teammate who owns the ground truth. It does not license confident-wrong claims in analysis, numbers, or any output with no corrector on the other end, where a wrong claim just ships as wrong (that's honesty.md's territory).

Companion to "Match the stakeholder's vocabulary" above — the "what we're currently calling X" hedge is the same instinct applied to terminology, where this applies it to facts and decisions.

Failure mode this prevents: hedging a question into an abstraction that asserts nothing — "how should we handle X, where applicable?" — safe, answerable with a shrug, surfacing no correction. The open question feels more honest, but it extracts less. A plainly-stated best guess gets the right answer faster precisely because it's disagreeable.
