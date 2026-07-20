# Naming

Names leak into code, docs, ADRs, commit messages, Slack, and stakeholder conversations. Inconsistency across those surfaces costs every future reader a translation step.

This rule covers *consistency* of names across surfaces. The `naming-analyzer` skill covers *quality* of an individual name (intention-revealing, right level of abstraction, &c.) — different axis.

## Single name per concept

Give one name to each concept and use it everywhere — class, method, column, test, comment, ADR, doc, commit message, chat. When extending an existing concept, use the established name. Don't invent a synonym.

**How to apply:** before naming a new thing, check the codebase, ADRs, and recent docs for the concept. If a name exists, use it. If a near-synonym exists, decide deliberately — same concept (use the existing name) or genuinely different (introduce a new name and document the distinction). Slipping a new synonym in without a decision creates split vocabulary that lingers.

This applies to extension as well as introduction. A new column on an existing model, a new method on an existing class, a new section in an existing doc — all default to the established vocabulary of the thing they're extending, unless the new thing is genuinely a different concept.

**Why:** two names for one concept means every reader learns the mapping. Worse, the names drift apart in meaning over time, creating an actual conceptual split hidden behind a naming split — the code ships with two terms that *describe* mismatched things, and the mismatch hides until something breaks.

## Adopt the domain expert's term

When a stakeholder or domain expert uses a term for a concept, that term becomes the name in code — not an engineer-flavored synonym. If the operations team calls something "the work order", the class is `WorkOrder`, not `ServiceRequest` or `JobTicket`. If they use an acronym (BoL, SOW, PO), the code uses it too — possibly expanded if the abbreviation collides with something else, but the acronym stays primary.

Companion: `stakeholder-questions.md` covers this on the *question-asking* side ("Match the stakeholder's vocabulary"). This section is the naming-side application of the same discipline — adopt their term, let them push back on it if it's off, evolve the vocabulary jointly.

**Why:** code that uses the domain expert's vocabulary reduces translation friction across every conversation that involves it. It also keeps the engineering team's mental model aligned with the people they serve, instead of drifting into engineer-internal jargon that the stakeholder has to translate every time.

## Serialization vocabulary

For a transformation between a runtime object and its persisted or wire form, default to **serialize / deserialize**. The directionality is unambiguous — serialize always means runtime object → persistable form, regardless of which form ends up more readable. Reserve **encode / decode** for transformations that aren't about runtime-vs-storage (Base64, URL encoding, character encoding). Avoid **hydrate / dehydrate** (frontend jargon) and **inflate / deflate** (collides with compression) in writing — both trip `writing.md`'s jargon and term-of-art-collision rules.

The full mental model — why serialize/deserialize sidesteps the readability-gradient collision that encode/decode carries, the `dump`/`load` idiom exception, and the when-to-reach-for-which test — is in `rules/references/naming/serialization-vocabulary.md`. Load it when choosing vocabulary for a serializer, storage coder, or wire format.

**Why:** without a default, every new context produces a fresh small decision and the same operation drifts across "encoding" here, "inflating" there, "hydrating" elsewhere — none wrong, none the same. That breaks single-name-per-concept at the vocabulary level.

## Failure mode this prevents

The same concept ends up under multiple names — class `Block`, column `inventory_block_id`, ADR "Inventory Block", Slack "the load", code comment "the carry-out unit" — and the reader pays a translation cost every time. Worse, the variants drift apart in meaning over time. The codebase ends up with names that *describe* mismatched things, hiding an actual conceptual mismatch until something breaks or a stakeholder catches the disconnect.
