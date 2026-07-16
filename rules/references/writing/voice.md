# Emulating the User's Voice — Specific Markers

> Not loaded in context by default. See `rules/writing.md` for the trigger and the Register directive.

## Archaic Latin abbreviations

Use the ones he favors:

- `&c.` instead of `etc.` (et cetera)
- `viz.` for "namely" or "that is to say" (similar register to `i.e.` but more specific — used to introduce an exhaustive specification of what was just referred to generally)
- `cf.` for "compare" or "see also" (pointing the reader to a related-but-distinct reference)

These are distinctive markers of his written voice. `i.e.` and `e.g.` are common enough to use anywhere. `&c.`, `viz.`, and `cf.` are not — reserve them for voice-emulation contexts.

Do not use these in output intended for general or external audiences (READMEs, public documentation, PR descriptions on shared projects, anything a reader other than Yossef will see). In those contexts, prefer the common-English equivalent (`etc.`, `namely`, `compare`) or, better, restructure to avoid the abbreviation entirely.

Failure mode this prevents: defaulting to common forms in personal correspondence flattens the user's voice. Defaulting to archaic forms in public docs imposes idiosyncratic style on readers who didn't ask for it.

## Do not mirror his prompting register

The user prompts in lowercase, with casual punctuation and no preamble or sign-off — "looks good to me", "look at the feedback.md diff. i can expand on that". This is his *prompting* shorthand, not his written voice. Do not carry it into output that has any audience beyond the immediate chat: commits, PR descriptions, comments, docs, ghostwritten messages.

For those, use standard capitalization and punctuation. Keep his register (precise, unhedged, terse) but not his typing shortcuts.

Failure mode this prevents: a commit message or PR description that reads like a Slack message — flat, lowercase, lacking the precision his voice actually has when he's writing for a reader.

## End with a valediction, not a summary

For longer prose under his byline — blog posts, essays, any piece with a closing paragraph — close by sending the reader off, not by recapping. Examples from his corpus: "Go forth and look around. And enjoy the patterns." / "Just try to do better next time. It's all we can really hope for." / "Looking forward to more, for all of it." Not "in conclusion", not a restatement of the thesis, not a bulleted recap.

The valediction can be short — "Go forth" is allowed. It can also be quiet rather than grand: a forward-looking sentence about the next thing, or a small wish for the reader.

Failure mode this prevents: the recap-summary is the default LLM ending and he almost never uses one. A draft that ends "in summary, X, Y, and Z" reads as ghostwritten on contact, even if the rest of the piece is in voice.

## Close on concrete behavior, not abstract appeal

When a chain of reasoning lands, name the concrete behavior rather than gesturing at an abstract principle. "Returns `nil`, and the rest is just Ruby" lands, "follows from Ruby semantics over this path" doesn't. The abstract version reads as ghostwritten because it gestures at the *category* of the thing rather than the *thing*. Same pattern with "follows from the type system", "consistent with the contract", "by the framework's semantics" — all categories, none of them the actual behavior.

This sits next to "End with a valediction, not a summary" above. The valediction rule covers the closing *paragraph* of longer prose. This one covers the closing *sentence* of any chain of reasoning, regardless of document length. Same underlying principle — don't end on ceremony.

Failure mode this prevents: confident-sounding closing sentences that don't actually say what happens. The reader gets a smooth landing that's an abstract restatement of what they already inferred, instead of the concrete fact that would make the chain feel finished.

## Keep factual-uncertainty hedges audible

Where a claim about a framework, history, library, or external concept isn't fully verified, leave the hedge on the page — typically as an em-dash aside, a parenthetical, or an asterisked footnote. Examples from his corpus: "(as much as I've been able to determine)", "(Anecdotally,…)", "I'm not 100% sure because I don't use 'plan mode'".

This is distinct from throat-clearing softeners ("kind of", "sort of", "I guess") — those should still be cut, per the Register rule in `writing.md`. The distinction: throat-clearing apologizes for the *claim*. An honest hedge flags the *limit of evidence* behind it. Cut the former, keep the latter.

This is the voice-level expression of `honesty.md`. The provenance rule says don't fabricate confidence. This rule says when the hedge is honest, leave it audible.

Failure mode this prevents: sanding the hedge off to sound more authoritative produces prose that's both less honest and less his. A confident-sounding sentence over an unverified claim is the exact failure `honesty.md` is trying to prevent, expressed at the level of voice.

## Comma for integrated asides, em-dash for interruptions, parenthesis for fourth-wall breaks

Three distinct tools, all heavily used, on a volume axis from light to off-stage. Commas hold integrated asides that ride with the sentence's rhythm — appositives, mild qualifiers, brief restatements. The reader barely perceives the break. Em-dashes hold asides that interrupt on purpose — restatements, mid-thought turns, strong qualifiers, or any aside that contains internal commas (where bracketing commas would be ambiguous). Parentheses hold stage whispers and direct address to the reader — hedges, winks, "no promises", source asides. The reader can skip them without losing the sentence.

When editing a draft, ask of each aside: is it part of the sentence's flow (comma), a deliberate interruption (em-dash), or something the reader could skip (parens)? Convert as needed.

Failure mode this prevents: LLM drafts default to one tool for all three roles — usually parens, sometimes em-dashes, rarely commas. The conversational pacing the three-tool habit produces flattens to monotone.

## Punctuation defaults

A few habits the user has that LLM drafts tend to violate:

- **Avoid semicolons in prose.** Use a full stop and a new sentence, a comma with a linking word (and, but, so, &c.), or a comma splice. The comma splice is intentional — it's a pacing tool, not an error to correct. The super-comma case (semicolons separating list items that contain internal commas) is a different convention and not what "in prose" covers here. Don't dodge the ban by reaching for a colon instead — a mid-sentence colon is the same disfavored join. Recast as two sentences or use an em-dash.
- **Em-dash over colon for an in-sentence reveal or aside.** "Top-level kwargs don't care — `**args` binds either way" reads as his. The LLM default would write "don't care: `**args` binds either way". Reserve colons for headings, labels, and list intros, not mid-sentence reveals.
- **Linking verb over colon for a definitional follow-on.** "The two parses that set the contract are X and Y" reads as his. The LLM default would write "The two parses that set the contract: X and Y".
- **Em-dash in titles when the second half qualifies the first, comma otherwise.** "Code Style — Ruby & Rails" and "Project vs. Global Settings — Match Scope to Use" both use the em-dash for "concept — clarifier" structure, and the em-dash carries the structural weight. For parallel imperatives, appositives, or simple list-style titles, prefer the comma. Case the two halves consistently — title-case throughout, or sentence-case throughout ("Project vs. global settings — match scope to use"). The em-dash separates structure, not case convention.
- **Punctuation outside quotes unless it belongs to the quoted material.** A period or comma that ends the surrounding sentence sits outside the closing quote — "the load-bearing claim". Punctuation that's part of the quoted text itself stays inside ("Stop!" she said). The LLM default puts ending periods and commas inside regardless ("the load-bearing claim.") — that's the case to avoid.

Failure mode this prevents: each of these is small on its own, but together they're a strong LLM tell. A draft that reads as his in voice and register can still read as ghostwritten if the punctuation defaults toward the model's habits instead of the user's.
