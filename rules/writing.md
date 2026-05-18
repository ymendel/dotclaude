# Writing

User-specific writing preferences that supplement the `writing-clearly-and-concisely` skill. These apply to prose, commit messages, PR descriptions, comments, and any other written output.

## Avoid violent and military metaphors

Do not use phrases rooted in violence, weapons, war, or the military — even when the metaphorical meaning is benign and widely accepted in industry usage. The user has flagged this as a style preference; treat it as firm, and pick a clearer literal equivalent.

Categories and examples:

- **Overt violence**: "kill two birds with one stone", "take a stab at", "shoot down", "pull the trigger on", "bite the bullet".
- **Military or war origins**: "boots on the ground", "rally the troops", "in the trenches", "battle-tested", "war room", "scorched earth", "marching orders".
- **"In anger" specifically**: do not use "in anger" in any form — "fired in anger", "running in anger", "exercised in anger", "tested in anger". Prefer plainer alternatives: "on a real merge", "in production use", "with real traffic", "for the first real run", "exercised on real input".

When unsure whether a phrase qualifies, prefer the literal alternative. The category is broader than the obvious cases — idioms that sound neutral today often have violent or military origins.

Failure mode this prevents: these phrases pass casual review because they are industry-common, then ship in user-facing prose where they read as careless or aggressive. The point is not to debate any individual idiom; it is to default to plain language.

## Prefer plain labels over jargon shorthand

When labeling phases, parts, or branches of a sequenced piece of work, use plain words and descriptive labels — not jargon shorthand, not bare numbers.

- **Plain words over jargon**: "phase" beats "arc". "Arc" is borderline corporate jargon and adds nothing over "phase".
- **Descriptive labels over numbered ones**: "the reads phase" / "the mutations phase" beats "Phase 1" / "Phase 2". A number forces the reader to remember which is which; a descriptive label is self-explanatory every time it appears.

Failure mode this prevents: jargon labels and bare-numbered labels both push cognitive load onto the reader without adding information. Plain descriptive labels keep the structure of the work readable without a glossary lookup.

## Emulating the user's voice

When writing in the user's voice — drafting a message *from* him, ghostwriting a comment he'll post, or any output where the goal is to sound like Yossef rather than to serve a broader audience — match the register described below.

### Register

Precise, slightly antiquarian, unhedged. He likes phrasings that name things honestly without apologizing for them — e.g. "archaic Latin abbreviations" rather than "old-fashioned shortenings" or "fancy Latin stuff". When in doubt between a plain word and a precise-but-old-fashioned one, lean toward the precise one. Do not hedge, soften, or add throat-clearing qualifiers.

This register is the *why* behind the specific markers below — and the guide for picking new phrasings the rule doesn't explicitly cover.

### Archaic Latin abbreviations

Use the ones he favors:

- `&c.` instead of `etc.` (et cetera)
- `viz.` for "namely" or "that is to say" (similar register to `i.e.` but more specific — used to introduce an exhaustive specification of what was just referred to generally)
- `cf.` for "compare" or "see also" (pointing the reader to a related-but-distinct reference)

These are distinctive markers of his written voice. `i.e.` and `e.g.` are common enough to use anywhere; `&c.`, `viz.`, and `cf.` are not — reserve them for voice-emulation contexts.

Do not use these in output intended for general or external audiences (READMEs, public documentation, PR descriptions on shared projects, anything a reader other than Yossef will see). In those contexts, prefer the common-English equivalent (`etc.`, `namely`, `compare`) or, better, restructure to avoid the abbreviation entirely.

Failure mode this prevents: defaulting to common forms in personal correspondence flattens the user's voice; defaulting to archaic forms in public docs imposes idiosyncratic style on readers who didn't ask for it.

### Do not mirror his prompting register

The user prompts in lowercase, with casual punctuation and no preamble or sign-off — "looks good to me", "look at the feedback.md diff. i can expand on that". This is his *prompting* shorthand, not his written voice. Do not carry it into output that has any audience beyond the immediate chat: commits, PR descriptions, comments, docs, ghostwritten messages.

For those, use standard capitalization and punctuation; keep his register (precise, unhedged, terse) but not his typing shortcuts.

Failure mode this prevents: a commit message or PR description that reads like a Slack message — flat, lowercase, lacking the precision his voice actually has when he's writing for a reader.
