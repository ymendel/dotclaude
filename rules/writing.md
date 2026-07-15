# Writing

User-specific writing preferences that supplement the `writing-clearly-and-concisely` skill. These apply to prose, commit messages, PR descriptions, comments, and any other written output.

These target durable output a reader will meet outside this session — sharpest for anything under the user's byline (a commit, a PR body, a ghostwritten message, a doc). They do **not** govern Claude's own conversational messages in-session, where the user has said his own register is fine and self-policing them wastes effort. So a semicolon (or any other flagged construct) in a chat reply is not a slip to correct — the same construct in durable prose is. Failure mode this prevents: treating an in-session chat message as if it were attributed output, and burning attention hunting flagged punctuation where the preference never applied.

## User slips don't redefine the rule

The "Avoid…" sections below name categories of phrases neither Claude nor the user should ship in writing. The user is steeped in industry usage and sometimes uses these phrases himself anyway. Do not read his usage as approval or license to mirror it. Flag it when he uses one in writing where the rule applies. Never adopt the phrase yourself because he did.

Failure mode this prevents: if Claude treats a user slip as an updated norm, the rule erodes from inside. The category isn't "phrases the user never uses" — it's "phrases neither of us should ship in writing". Mirroring his usage collapses the distinction.

## Avoid violent and military metaphors

Do not use phrases rooted in violence, weapons, war, or the military — even when the metaphorical meaning is benign and widely accepted in industry usage. The user has flagged this as a style preference. Treat it as firm, and pick a clearer literal equivalent.

Categories and examples:

- **Overt violence**: "kill two birds with one stone", "take a stab at", "shoot down", "pull the trigger on", "bite the bullet".
- **Military or war origins**: "boots on the ground", "rally the troops", "in the trenches", "battle-tested", "war room", "scorched earth", "marching orders", "war story".
- **"In anger" specifically**: do not use "in anger" in any form — "fired in anger", "running in anger", "exercised in anger", "tested in anger". Prefer plainer alternatives: "on a real merge", "in production use", "with real traffic", "for the first real run", "exercised on real input".
- **"War story" specifically**: do not use "war story" for the dev-writing genre of "experienced practitioner sharing a tricky incident or hard-won lesson". Prefer "shop story" — workshop register, same shape (telling someone how the job went sideways), no militarism. "Field report", "build story", or just "story" also work when "shop story" reads too craft-flavored for the context.

When unsure whether a phrase qualifies, prefer the literal alternative. The category is broader than the obvious cases — idioms that sound neutral today often have violent or military origins.

Failure mode this prevents: these phrases pass casual review because they are industry-common, then ship in user-facing prose where they read as careless or aggressive. The point is not to debate any individual idiom. It is to default to plain language.

## Prefer plain labels over jargon shorthand

When labeling phases, parts, or branches of a sequenced piece of work, use plain words and descriptive labels — not jargon shorthand, not bare numbers.

- **Plain words over jargon**: "phase" beats "arc". "Arc" is borderline corporate jargon and adds nothing over "phase".
- **Descriptive labels over numbered ones**: "the reads phase" / "the mutations phase" beats "Phase 1" / "Phase 2". A number forces the reader to remember which is which. A descriptive label is self-explanatory every time it appears.

Failure mode this prevents: jargon labels and bare-numbered labels both push cognitive load onto the reader without adding information. Plain descriptive labels keep the structure of the work readable without a glossary lookup.

## Avoid borrowed corporate-policy jargon

Phrases borrowed from corporate or policy contexts survive on familiarity, not clarity. Indicative examples — not exhaustive, extend by analogy: "shovel-ready", "low-hanging fruit", "move the needle", "boil the ocean", "blue-sky", "swim lanes", "north star", "table stakes". Prefer the plain equivalent — "closer to ready" beats "shovel-ready", "easy wins" beats "low-hanging fruit", "the priority" beats "the north star". If you can't find a plain version quickly the phrase might be load-bearing. Usually it isn't, and the plain form is shorter besides.

This is the sibling case to "plain labels over jargon shorthand" above: that rule covers labels for phases or parts. This one covers descriptive phrases and metaphors. Same underlying principle — words that survive on familiarity rather than information aren't doing work.

Failure mode this prevents: corporate-policy jargon ships in writing under the user's byline where it reads as ghostwritten or unconsidered. The phrases are cheap to write because they don't require precision, which is exactly why they're worth catching.

## Avoid words that collide with terms of art

A word's meaning is decided by the reader's nearest context, not by the writer's intent. A word with a strong term-of-art meaning will be parsed as that term of art first, even when the surrounding sentence makes another sense structurally possible. The reader pays a cost: either spotting the collision (one re-parse) or missing it (silent misread). Either way, the word is wrong even if the dictionary defines what you meant.

Three shapes to watch for:

- **Loose or metaphorical use vs. term of art.** A word used in its plain sense, or stretched metaphorically, that also names a specific technical operation in the reader's domain. The technical sense wins the parse. Examples in software contexts: "rebase" (metaphorical: re-anchor onto a different foundation; git: replay commits onto a new base), "fork" (lay: a branch in a path; git/process: copy a repo or process), "merge" (lay: combine; git: combine branches), "stash" (lay: hide away; git: shelve working changes), "amend" (lay: edit/improve; git: rewrite the most recent commit), "rollback" (lay: undo; databases: revert a transaction). When the looser sense is what you want, pick a word that doesn't collide — "re-anchor", "split", "combine", "park", "edit", "undo".
- **Term of art in one context vs. another.** A word that's technical in multiple sub-fields, distinguished only by surrounding cues. The dominant sub-field for the immediate reader wins. Examples: "branch" (git vs. AST traversal vs. control flow), "thread" (concurrency vs. message thread vs. textile), "kernel" (OS vs. linear algebra vs. ML), "argument" (function parameter vs. rhetoric), "tree" (data structure vs. file system vs. UI vs. botany), "stream" (Turbo/HTTP vs. functional iterators vs. video), "lock" (concurrency vs. cryptography vs. file system). If two sub-fields are both plausible from the surrounding text, disambiguate explicitly or pick a non-colliding word.
- **Named methodology or framework concept that imports a whole model.** A multi-word capitalized concept from a methodology (Scrum/Agile, ITIL, Six Sigma, &c.) that parses *correctly* as the words say but drags in a specific model the writer may not intend. Here the collision isn't a mis-parsed word — it's an imported connotation. Examples: "Definition of Done" (Scrum: a pre-release quality gate — work isn't done until a checklist is met, *before* release; you may mean the plain finish line — shipped and settled, *after* release), "Sprint", "Epic", "WIP limit". A reader fluent in the methodology reaches for its model first. This shape is easy to miss precisely because the words are right — the single-word examples above trip recognition, a phrase that reads plainly does not. Remedy is the same: define the term explicitly on first use, or frame it so the methodology model isn't invoked ("what 'done' means on our board" rather than "our Definition of Done").

When in doubt, ask: in this paragraph, which sense will the reader reach for *first*? If that isn't the sense you mean, the word is wrong — even if it's a defensible synonym of what you mean.

Failure mode this prevents: a word chosen for its loose or metaphorical sense (or for the wrong sub-field's term of art, or a methodology phrase that reads plainly but imports a model) gets parsed as the dominant local sense, producing a confident-sounding sentence that means something other than what you wrote.

## Sweep prose when you rename a code example

When you rename or restructure a code example in a document, sweep the surrounding prose for stale references. Names in the code — variables, method arguments, class names — appear in adjacent prose too: workaround sections, verification notes, follow-up paragraphs that picked up the old name. A rename in the code without a sweep leaves a reader confused about where the new name suddenly appeared from.

Failure mode this prevents: a reader sees one name in the code example and a different name in the next section's prose, and either backtracks to find out where the second name came from or assumes it's a different production case. Either way, the document has silently asked the reader to do reconciliation work the author should have done.

Sibling: honesty.md's *Rewrite the Prose When Verification Disagrees* covers the same shape on the verification side — when a check reveals the original was wrong, edit the prose rather than appending the correction. The shared discipline: when something in the document is now wrong, update the document. Don't layer the correction next to it.

## Don't reframe an edit as what's no longer there

When you edit by removing or demoting something, don't leave prose that describes what's *not* happening or what the reader *doesn't* have to do. That framing is a reaction to the deleted content — it only parses for a reader who saw the prior version. A cold reader has no prior version, so "you don't have to name X up front" reads as answering a question nobody asked, and quietly signals the text was edited rather than written. State positively what *is* — the thing to do, the value on offer — and let the removed concern stay removed. If the positive form needs the old concept at all, define it in passing rather than negating it.

This is the edit-artifact sibling of the two rules above: they catch stale *names* and stale *claims* left behind by an edit; this one catches stale *framing* — prose shaped by what used to be on the page. The shared tell: the sentence makes sense only against a version the reader never saw.

Failure mode this prevents: a removal-driven edit leaves a "here's what you no longer need to do" paragraph that reads as out-of-place throat-clearing to anyone reading fresh, and betrays the document as patched rather than composed.

## Don't over-engineer for the secondary audience

When output is human-primary but machine-secondary — issue bodies, PR descriptions, ADRs, docs that other agents will read later for context — don't add bulleted or sectioned structure beyond what the human form naturally wants. Agents handle prose. The voice rule and the clarity rule already produce text both audiences can use. The temptation to "make it easier for an LLM to parse later" almost always produces listicle ceremony that the human form didn't need, which then has to be scrubbed during the voice pass.

This is adjacent to "Do not mirror his prompting register" in the voice section below — both correct for the wrong-audience tilt. That one says "the chat-prompting form isn't the writing form"; this one says "the agent-friendly form isn't a separate target from the human-readable form".

Failure mode this prevents: speculative restructuring for an imagined agent reader, producing prose that reads as ghostwritten to the human reader and saves no real effort for the agent reader (who would have done fine with the prose).

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

These are distinctive markers of his written voice. `i.e.` and `e.g.` are common enough to use anywhere. `&c.`, `viz.`, and `cf.` are not — reserve them for voice-emulation contexts.

Do not use these in output intended for general or external audiences (READMEs, public documentation, PR descriptions on shared projects, anything a reader other than Yossef will see). In those contexts, prefer the common-English equivalent (`etc.`, `namely`, `compare`) or, better, restructure to avoid the abbreviation entirely.

Failure mode this prevents: defaulting to common forms in personal correspondence flattens the user's voice. Defaulting to archaic forms in public docs imposes idiosyncratic style on readers who didn't ask for it.

### Do not mirror his prompting register

The user prompts in lowercase, with casual punctuation and no preamble or sign-off — "looks good to me", "look at the feedback.md diff. i can expand on that". This is his *prompting* shorthand, not his written voice. Do not carry it into output that has any audience beyond the immediate chat: commits, PR descriptions, comments, docs, ghostwritten messages.

For those, use standard capitalization and punctuation. Keep his register (precise, unhedged, terse) but not his typing shortcuts.

Failure mode this prevents: a commit message or PR description that reads like a Slack message — flat, lowercase, lacking the precision his voice actually has when he's writing for a reader.

### End with a valediction, not a summary

For longer prose under his byline — blog posts, essays, any piece with a closing paragraph — close by sending the reader off, not by recapping. Examples from his corpus: "Go forth and look around. And enjoy the patterns." / "Just try to do better next time. It's all we can really hope for." / "Looking forward to more, for all of it." Not "in conclusion", not a restatement of the thesis, not a bulleted recap.

The valediction can be short — "Go forth" is allowed. It can also be quiet rather than grand: a forward-looking sentence about the next thing, or a small wish for the reader.

Failure mode this prevents: the recap-summary is the default LLM ending and he almost never uses one. A draft that ends "in summary, X, Y, and Z" reads as ghostwritten on contact, even if the rest of the piece is in voice.

### Close on concrete behavior, not abstract appeal

When a chain of reasoning lands, name the concrete behavior rather than gesturing at an abstract principle. "Returns `nil`, and the rest is just Ruby" lands, "follows from Ruby semantics over this path" doesn't. The abstract version reads as ghostwritten because it gestures at the *category* of the thing rather than the *thing*. Same pattern with "follows from the type system", "consistent with the contract", "by the framework's semantics" — all categories, none of them the actual behavior.

This sits next to "End with a valediction, not a summary" above. The valediction rule covers the closing *paragraph* of longer prose. This one covers the closing *sentence* of any chain of reasoning, regardless of document length. Same underlying principle — don't end on ceremony.

Failure mode this prevents: confident-sounding closing sentences that don't actually say what happens. The reader gets a smooth landing that's an abstract restatement of what they already inferred, instead of the concrete fact that would make the chain feel finished.

### Keep factual-uncertainty hedges audible

Where a claim about a framework, history, library, or external concept isn't fully verified, leave the hedge on the page — typically as an em-dash aside, a parenthetical, or an asterisked footnote. Examples from his corpus: "(as much as I've been able to determine)", "(Anecdotally,…)", "I'm not 100% sure because I don't use 'plan mode'".

This is distinct from throat-clearing softeners ("kind of", "sort of", "I guess") — those should still be cut, per the Register rule above. The distinction: throat-clearing apologizes for the *claim*. An honest hedge flags the *limit of evidence* behind it. Cut the former, keep the latter.

This is the voice-level expression of `honesty.md`. The provenance rule says don't fabricate confidence. This rule says when the hedge is honest, leave it audible.

Failure mode this prevents: sanding the hedge off to sound more authoritative produces prose that's both less honest and less his. A confident-sounding sentence over an unverified claim is the exact failure `honesty.md` is trying to prevent, expressed at the level of voice.

### Comma for integrated asides, em-dash for interruptions, parenthesis for fourth-wall breaks

Three distinct tools, all heavily used, on a volume axis from light to off-stage. Commas hold integrated asides that ride with the sentence's rhythm — appositives, mild qualifiers, brief restatements. The reader barely perceives the break. Em-dashes hold asides that interrupt on purpose — restatements, mid-thought turns, strong qualifiers, or any aside that contains internal commas (where bracketing commas would be ambiguous). Parentheses hold stage whispers and direct address to the reader — hedges, winks, "no promises", source asides. The reader can skip them without losing the sentence.

When editing a draft, ask of each aside: is it part of the sentence's flow (comma), a deliberate interruption (em-dash), or something the reader could skip (parens)? Convert as needed.

Failure mode this prevents: LLM drafts default to one tool for all three roles — usually parens, sometimes em-dashes, rarely commas. The conversational pacing the three-tool habit produces flattens to monotone.

### Punctuation defaults

A few habits the user has that LLM drafts tend to violate:

- **Avoid semicolons in prose.** Use a full stop and a new sentence, a comma with a linking word (and, but, so, &c.), or a comma splice. The comma splice is intentional — it's a pacing tool, not an error to correct. The super-comma case (semicolons separating list items that contain internal commas) is a different convention and not what "in prose" covers here. Don't dodge the ban by reaching for a colon instead — a mid-sentence colon is the same disfavored join. Recast as two sentences or use an em-dash.
- **Em-dash over colon for an in-sentence reveal or aside.** "Top-level kwargs don't care — `**args` binds either way" reads as his. The LLM default would write "don't care: `**args` binds either way". Reserve colons for headings, labels, and list intros, not mid-sentence reveals.
- **Linking verb over colon for a definitional follow-on.** "The two parses that set the contract are X and Y" reads as his. The LLM default would write "The two parses that set the contract: X and Y".
- **Em-dash in titles when the second half qualifies the first, comma otherwise.** "Code Style — Ruby & Rails" and "Project vs. Global Settings — Match Scope to Use" both use the em-dash for "concept — clarifier" structure, and the em-dash carries the structural weight. For parallel imperatives, appositives, or simple list-style titles, prefer the comma. Case the two halves consistently — title-case throughout, or sentence-case throughout ("Project vs. global settings — match scope to use"). The em-dash separates structure, not case convention.
- **Punctuation outside quotes unless it belongs to the quoted material.** A period or comma that ends the surrounding sentence sits outside the closing quote — "the load-bearing claim". Punctuation that's part of the quoted text itself stays inside ("Stop!" she said). The LLM default puts ending periods and commas inside regardless ("the load-bearing claim.") — that's the case to avoid.

Failure mode this prevents: each of these is small on its own, but together they're a strong LLM tell. A draft that reads as his in voice and register can still read as ghostwritten if the punctuation defaults toward the model's habits instead of the user's.
