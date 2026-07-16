# Writing

User-specific writing preferences that supplement the `writing-clearly-and-concisely` skill. These apply to prose, commit messages, PR descriptions, comments, and any other written output.

These target durable output a reader will meet outside this session — sharpest for anything under the user's byline (a commit, a PR body, a ghostwritten message, a doc). They do **not** govern Claude's own conversational messages in-session, where the user has said his own register is fine and self-policing them wastes effort. So a semicolon (or any other flagged construct) in a chat reply is not a slip to correct — the same construct in durable prose is. Failure mode this prevents: treating an in-session chat message as if it were attributed output, and burning attention hunting flagged punctuation where the preference never applied.

## User slips don't redefine the rule

The "Avoid…" sections below name categories of phrases neither Claude nor the user should ship in writing. The user is steeped in industry usage and sometimes uses these phrases himself anyway. Do not read his usage as approval or license to mirror it. Flag it when he uses one in writing where the rule applies. Never adopt the phrase yourself because he did.

Failure mode this prevents: if Claude treats a user slip as an updated norm, the rule erodes from inside. The category isn't "phrases the user never uses" — it's "phrases neither of us should ship in writing". Mirroring his usage collapses the distinction.

## Avoid violent and military metaphors

Do not use phrases rooted in violence, weapons, war, or the military — even when the metaphorical meaning is benign and widely accepted in industry usage. The user has flagged this as a style preference. Treat it as firm, and pick a clearer literal equivalent.

Two traps carry prescribed replacements, not just a flag:

- **"In anger" specifically**: do not use "in anger" in any form — "fired in anger", "running in anger", "exercised in anger", "tested in anger". Prefer plainer alternatives: "on a real merge", "in production use", "with real traffic", "for the first real run", "exercised on real input".
- **"War story" specifically**: do not use "war story" for the dev-writing genre of "experienced practitioner sharing a tricky incident or hard-won lesson". Prefer "shop story" — workshop register, same shape (telling someone how the job went sideways), no militarism. "Field report", "build story", or just "story" also work when "shop story" reads too craft-flavored for the context.

When unsure whether a phrase qualifies, prefer the literal alternative. The category is broader than the obvious cases — idioms that sound neutral today often have violent or military origins. Example lists of the common offenders (overt-violence idioms, military/war-origin phrases) are catalogued in `rules/references/writing/catalogs.md` — pull it up to check a specific phrase.

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

Collisions come in three shapes:

- **Loose or metaphorical use vs. term of art** — a word in its plain or stretched sense that also names a specific technical operation, and the technical sense wins the parse (e.g. "rebase", "fork", "merge", "stash").
- **Term of art in one context vs. another** — a word that's technical in multiple sub-fields, and the reader's dominant sub-field wins (e.g. "branch", "thread", "kernel", "stream").
- **Named methodology or framework concept that imports a whole model** — a phrase that parses correctly as the words say but drags in a specific model the writer may not intend (e.g. "Definition of Done", "Sprint", "Epic").

Each shape's full example breakdown and remedies are in `rules/references/writing/catalogs.md` — pull it up when a word feels like it might collide and you want to check the pattern.

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

This is adjacent to "Do not mirror his prompting register" (in `rules/references/writing/voice.md`) — both correct for the wrong-audience tilt. That one says "the chat-prompting form isn't the writing form" — this one says "the agent-friendly form isn't a separate target from the human-readable form".

Failure mode this prevents: speculative restructuring for an imagined agent reader, producing prose that reads as ghostwritten to the human reader and saves no real effort for the agent reader (who would have done fine with the prose).

## Emulating the user's voice

When writing in the user's voice — drafting a message *from* him, ghostwriting a comment he'll post, or any output where the goal is to sound like Yossef rather than to serve a broader audience — match the register described below. This also governs anything under his byline that serves a reader (a commit message, a PR description, a doc), which is most sessions.

### Register

Precise, slightly antiquarian, unhedged. He likes phrasings that name things honestly without apologizing for them — e.g. "archaic Latin abbreviations" rather than "old-fashioned shortenings" or "fancy Latin stuff". When in doubt between a plain word and a precise-but-old-fashioned one, lean toward the precise one. Do not hedge, soften, or add throat-clearing qualifiers.

This register is the *why* behind the specific markers, and the guide for picking new phrasings the rule doesn't explicitly cover. The markers themselves — the archaic Latin abbreviations (`&c.`, `viz.`, `cf.`), the valediction-not-summary ending, the concrete-behavior close, the audible-hedge habit, the comma/em-dash/parenthesis split, and the punctuation defaults (semicolon avoidance, em-dash over colon, quote-mark placement) — live in `rules/references/writing/voice.md`. Load it whenever drafting under his byline, most often a commit message or PR description.

Failure mode this prevents: the markers are individually small but collectively a strong LLM tell. Skipping them lets byline output default to model-habit punctuation and voice, which reads as ghostwritten even when the register is right.
