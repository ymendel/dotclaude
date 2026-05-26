# Writing

User-specific writing preferences that supplement the `writing-clearly-and-concisely` skill. These apply to prose, commit messages, PR descriptions, comments, and any other written output.

## Avoid violent and military metaphors

Do not use phrases rooted in violence, weapons, war, or the military — even when the metaphorical meaning is benign and widely accepted in industry usage. The user has flagged this as a style preference; treat it as firm, and pick a clearer literal equivalent.

Categories and examples:

- **Overt violence**: "kill two birds with one stone", "take a stab at", "shoot down", "pull the trigger on", "bite the bullet".
- **Military or war origins**: "boots on the ground", "rally the troops", "in the trenches", "battle-tested", "war room", "scorched earth", "marching orders", "war story".
- **"In anger" specifically**: do not use "in anger" in any form — "fired in anger", "running in anger", "exercised in anger", "tested in anger". Prefer plainer alternatives: "on a real merge", "in production use", "with real traffic", "for the first real run", "exercised on real input".
- **"War story" specifically**: do not use "war story" for the dev-writing genre of "experienced practitioner sharing a tricky incident or hard-won lesson". Prefer "shop story" — workshop register, same shape (telling someone how the job went sideways), no militarism. "Field report", "build story", or just "story" also work when "shop story" reads too craft-flavored for the context.

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

### End with a valediction, not a summary

For longer prose under his byline — blog posts, essays, any piece with a closing paragraph — close by sending the reader off, not by recapping. Examples from his corpus: "Go forth and look around. And enjoy the patterns." / "Just try to do better next time. It's all we can really hope for." / "Looking forward to more, for all of it." Not "in conclusion", not a restatement of the thesis, not a bulleted recap.

The valediction can be short — "Go forth" is allowed. It can also be quiet rather than grand: a forward-looking sentence about the next thing, or a small wish for the reader.

Failure mode this prevents: the recap-summary is the default LLM ending and he almost never uses one. A draft that ends "in summary, X, Y, and Z" reads as ghostwritten on contact, even if the rest of the piece is in voice.

### Keep factual-uncertainty hedges audible

Where a claim about a framework, history, library, or external concept isn't fully verified, leave the hedge on the page — typically as an em-dash aside, a parenthetical, or an asterisked footnote. Examples from his corpus: "(as much as I've been able to determine)", "(Anecdotally,…)", "I'm not 100% sure because I don't use 'plan mode'".

This is distinct from throat-clearing softeners ("kind of", "sort of", "I guess") — those should still be cut, per the Register rule above. The distinction: throat-clearing apologizes for the *claim*; an honest hedge flags the *limit of evidence* behind it. Cut the former; keep the latter.

This is the voice-level expression of `honesty.md`. The provenance rule says don't fabricate confidence; this rule says when the hedge is honest, leave it audible.

Failure mode this prevents: sanding the hedge off to sound more authoritative produces prose that's both less honest and less his. A confident-sounding sentence over an unverified claim is the exact failure `honesty.md` is trying to prevent, expressed at the level of voice.

### Em-dash for asides, parenthesis for fourth-wall breaks

Two distinct tools, both heavily used. Em-dashes hold clausal asides that belong inside the sentence's flow — qualifications, restatements, mid-thought turns. Parentheses hold stage whispers and direct address to the reader: hedges, winks, "no promises", "this story has been compressed for your benefit".

When editing a draft, ask of each parenthetical: is this an aside within the sentence, or a wink to the reader? Convert as needed.

Failure mode this prevents: LLM drafts tend to default to parentheses for everything (or em-dashes for everything). Either monoculture loses the conversational pacing the two-tool habit produces.
