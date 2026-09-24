# Writing

User-specific writing preferences that supplement the `writing-clearly-and-concisely` skill. These apply to prose, commit messages, PR descriptions, comments, and any other written output.

These target durable output a reader will meet outside this session — sharpest for anything under the user's byline (a commit, a PR body, a ghostwritten message, a doc). The **marker-level** preferences below — punctuation, archaic abbreviations, individual flagged phrases — do not govern Claude's own conversational messages in-session. The user has said his own register is fine there, and a stray semicolon in a chat reply costs him nothing to read.

Length is the exception, and it runs the other way. *Say the fact and stop* below applies in chat too, because that cost lands on the reader rather than on the writer.

Failure mode this prevents: reading the chat exemption as blanket permission, so replies grow to whatever length comes naturally — which is the one part of this file the user is exposed to on every single turn.

## Say the fact and stop

State what is true and move on. One clause of reasoning per sentence. Where a consequence genuinely needs saying it gets its own sentence, and most of the time it does not, because a reader holding the fact already holds the consequence.

Three tells, all of them one habit — never stating a fact without also stating why it counts:

- **Words that announce importance.** "Load-bearing", "critical", "key", "the crux", "notably", "importantly", "it's worth noting that", "make no mistake", a bolded **this matters**. Each asks the reader to weight a claim instead of giving them the reason to. Say what the thing does: "the assertion the test turns on", "the only caller left".
- **A consequence clause appended to a fact.** "…and that bites", "…and it's a real one", "…which is exactly the problem", "…and that is what makes it worse". The fact carried it already. Cut the clause.
- **A semicolon.** The same move at the level of punctuation — it welds a claim to its justification inside one sentence. Use a full stop, an em-dash, or a comma with a linking word. This one has needed correcting more than once.

A ban list catches these three and not the next three. Cut the habit instead.

The rewrite is usually a deletion. "The tradeoff, and it's a real one: nvm's bin directory isn't on PATH until something loads it" becomes "nvm's bin directory isn't on PATH until something loads it" — the fact was always doing the persuading. A point that needs flagging is a point that wasn't stated strongly enough, so rewrite the point rather than decorating it.

Failure mode this prevents: padded prose reads as careful, because every added clause is individually defensible — it usually *is* true that the point matters. The volume shows only in aggregate, by which time it reads as the house style rather than as something to edit out. Under a byline it is worse than filler, because it is one of the few tells a reader can name on sight, and naming it discredits the prose around it.

## User slips don't redefine the rule

The "Avoid…" sections below name categories of phrases neither Claude nor the user should ship in writing. The user is steeped in industry usage and sometimes uses these phrases himself anyway. Do not read his usage as approval or license to mirror it. Flag it when he uses one in writing where the rule applies. Never adopt the phrase yourself because he did.

Failure mode this prevents: if Claude treats a user slip as an updated norm, the rule erodes from inside. The category is "phrases neither of us should ship in writing", not "phrases the user never uses".

## Avoid violent and military metaphors

Do not use phrases rooted in violence, weapons, war, or the military — even when the metaphorical meaning is benign and widely accepted in industry usage. The user has flagged this as a style preference. Treat it as firm, and pick a clearer literal equivalent.

Two traps carry prescribed replacements, not just a flag:

- **"In anger" specifically**: do not use "in anger" in any form — "fired in anger", "running in anger", "exercised in anger", "tested in anger". Prefer plainer alternatives: "on a real merge", "in production use", "with real traffic", "for the first real run", "exercised on real input".
- **"War story" specifically**: do not use "war story" for the dev-writing genre of "experienced practitioner sharing a tricky incident or hard-won lesson". Prefer "shop story" — workshop register, same shape (telling someone how the job went sideways), no militarism. "Field report", "build story", or just "story" also work when "shop story" reads too craft-flavored for the context.

When unsure whether a phrase qualifies, prefer the literal alternative. The category is broader than the obvious cases — idioms that sound neutral today often have violent or military origins. Example lists of the common offenders (overt-violence idioms, military/war-origin phrases) are catalogued in `rules/references/writing/catalogs.md` — pull it up to check a specific phrase.

Failure mode this prevents: these phrases pass casual review because they are industry-common, then ship in user-facing prose where they read as careless or aggressive.

## Prefer plain labels over jargon shorthand

When labeling phases, parts, or branches of a sequenced piece of work, use plain words and descriptive labels — not jargon shorthand, not bare numbers.

- **Plain words over jargon**: "phase" beats "arc". "Arc" is borderline corporate jargon and adds nothing over "phase".
- **Descriptive labels over numbered ones**: "the reads phase" / "the mutations phase" beats "Phase 1" / "Phase 2". A number forces the reader to remember which is which. A descriptive label is self-explanatory every time it appears.

Failure mode this prevents: a bare number forces a glossary lookup on every appearance, and the reader carries it rather than the author.

## Avoid borrowed corporate-policy jargon

Phrases borrowed from corporate or policy contexts survive on familiarity, not clarity. Indicative examples — not exhaustive, extend by analogy: "shovel-ready", "low-hanging fruit", "move the needle", "boil the ocean", "blue-sky", "swim lanes", "north star", "table stakes". Prefer the plain equivalent — "closer to ready" beats "shovel-ready", "easy wins" beats "low-hanging fruit", "the priority" beats "the north star". If you can't find a plain version quickly the phrase might be load-bearing. Usually it isn't, and the plain form is shorter besides.

Failure mode this prevents: corporate-policy jargon ships in writing under the user's byline where it reads as ghostwritten or unconsidered.

## Don't treat a design property as currency — no spending, budgets, or capital

Never write that a decision "spends" a guarantee, that a recorded Positive is "spent", or that
a record has budget or capital to draw on. The metaphor casts a property of the system as money,
and the plain verbs are both shorter and more precise: a decision **gives up** a property, a
claim **no longer holds** or **stops describing the system**, a guarantee **ends**, a constraint
**is relaxed**, an invariant **is given up deliberately**.

Literal consumption stays literal. Time, memory, money, and tokens are genuinely paid out, so
"the time spent computing a checksum" or "a spawn spends the token budget" is description
rather than metaphor. The test is whether something is actually being paid. A design property
is not — nothing leaves an account when an ADR gives up "no object store".

ADRs are where this concentrates, because an ADR is *about* tradeoffs and the currency framing
feels apt there. It is the one place it does most damage: an ADR is read years later as a
record of what was decided, and "this Positive is now spent" makes a reader work out which
plain fact was meant. Say the fact.

Failure mode this prevents: the metaphor reads as a considered turn of phrase rather than as
jargon, so it survives a self-edit that would have caught "low-hanging fruit" — and because it
scales so easily (spend, budget, cost, capital, dividend, pay down) one use seeds a whole
register the next document inherits.

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

## Don't reframe an edit as what's no longer there

When you edit by removing or demoting something, don't leave prose that describes what's *not* happening or what the reader *doesn't* have to do. That framing is a reaction to the deleted content — it only parses for a reader who saw the prior version. A cold reader has no prior version, so "you don't have to name X up front" reads as answering a question nobody asked, and quietly signals the text was edited rather than written. State positively what *is* — the thing to do, the value on offer — and let the removed concern stay removed. If the positive form needs the old concept at all, define it in passing rather than negating it.

The tell: the sentence makes sense only against a version the reader never saw.

Failure mode this prevents: a removal-driven edit leaves a "here's what you no longer need to do" paragraph that reads as out-of-place throat-clearing to anyone reading fresh, and betrays the document as patched rather than composed.

## Don't state a count apart from the members it counts

When prose asserts how many of something there are, the count is the one part of the sentence a later edit silently falsifies, and it does so without any signal — the author's attention and the reader's eye are both on the members, never on the sentence tallying them.

What decides the risk is whether the count and the members sit in the same edit unit. A lead-in bound to its list by a colon — "Two caveats on trafilatura:" above two bullets — is one unit: adding a third means editing the very block the count introduces, with the number in view the whole time. That form is sound, and it is the house style throughout these rules. The shape that rots is a count *referring back* to members named elsewhere. "Those three are the live cases," sitting two sentences after the three were named in flowing prose, survives the edit that adds a fourth untouched, because nothing about revising the earlier sentence brings the later one into view. There, name the members again or say nothing.

The same split holds a level out: a comment directly above the block it annotates is one unit with it, while a comment counting things defined further down the file is not.

It is worst in a record that reads as present tense. An ADR or a design doc states facts about the repo that a reader has no reason to doubt, so a stale count survives review indefinitely and is caught only by someone who stops to count.

Where the number is genuinely load-bearing — "exactly two callers remain, both in the importer" — keep it and make it checkable: name them, or date the claim, so a reader can tell current from historical.

Failure mode this prevents: a count reads as verified precision, so it is trusted rather than checked, and it survives every review after the edit that falsified it. Nothing marks the tally as older than what it tallies, and the members it refers to are far enough off that no reader has reason to go and count — which discredits the surrounding claims they cannot check as easily either.

## Don't over-engineer for the secondary audience

When output is human-primary but machine-secondary — issue bodies, PR descriptions, ADRs, docs that other agents will read later for context — don't add bulleted or sectioned structure beyond what the human form naturally wants. Agents handle prose. The voice rule and the clarity rule already produce text both audiences can use. The temptation to "make it easier for an LLM to parse later" almost always produces listicle ceremony that the human form didn't need, which then has to be scrubbed during the voice pass.

Failure mode this prevents: speculative restructuring for an imagined agent reader, producing prose that reads as ghostwritten to the human reader and saves no real effort for the agent reader (who would have done fine with the prose).

## Don't borrow these rules' register

The always-loaded rule set is the largest body of prose in any session and the most recently read, and it has a house style: state the directive, give the failure mode it prevents, name the sibling rule it sits beside. That style is right *here*. Always-loaded text competes for attention against everything else loaded, so it has to say what goes wrong without it and how it relates to its neighbors, or it cannot be weighed against them at all. None of that holds for a code comment, a commit body, or a PR description, whose reader arrived looking for something specific and wants the fact rather than the case for the fact.

What lets the register travel is that *capture the why, not the how* sets no limit. A how ends where the code says it. A why does not — every reason can be given a reason, and every rejected alternative can be given the argument that rejected it — so guidance that reads as a filter turns out to be a license, and this register is what fills the space it opens.

Tells, all of them borrowed from this rule set:

- a commit body that argues for the change rather than saying what it does and why
- a `Failure mode:` clause, or a "Sibling:" cross-reference, anywhere that is not a rule
- a paragraph on why the rejected alternative lost, when nobody proposed it
- bolded lead-in phrases opening successive paragraphs of a commit body or PR description
- section headings in a PR description for a change with a single concern

Write the plain version instead, per *Say the fact and stop* above. Where reasoning genuinely needs an argument made at length, it has destinations — an ADR, a note — and a pointer left where the reader will meet it.

Failure mode this prevents: the density gets imitated by default and each instance reads as careful work, because it matches the house style of the most authoritative prose in context. `code-style.md` asks for consistency with the nearest examples when in doubt, and in a session the nearest examples of *prose* are these files, so the instinct that is normally right argues for the wrong register here. Nothing in a self-edit flags it, because the output is consistent with the surrounding configuration.

## Say it once, and pick where it lives

One fact about one change clears several independent gates, each of them honestly. *Would a competent reader know this from the code?* — no, so it becomes a comment. *Do the subject and the diff convey the reason?* — no, so it becomes a commit body. *Is this current and useful to a reviewer?* — yes, so it goes in the PR description as well. Every gate is answered correctly on its own terms and none of them can see the other two, so the reader meets the same paragraph three times without any single decision having been wrong.

Assign the fact to the reader who hits it, and leave the other artifacts a pointer or nothing:

- A constraint that will trip whoever next edits a line goes in the comment beside it. That reader is not reading the history.
- Why this approach rather than the one it displaced goes in the commit body, or in an ADR when the decision outlives the commit.
- What to look at and in what order, and what was deliberately left out, goes in the PR description. A reviewer reads it once and then reads the diff.
- Reasoning that several sites depend on goes in an ADR or a note, with a pointer from each site.

The test for a second copy is whether a reader plausibly reaches the second artifact without passing the first. A comment's reader may never open the log, so a comment restating a commit body can be right. A reviewer reads the PR description and the commits both, which makes that the copy that most reliably fails — reasoning already carried by the commit bodies does not want restating above them.

Point by stable identity when pointing at all: an ADR number, a tracked path, a heading. A comment pointing at a bare SHA is worse than the copy it replaced, per `development-workflow.md`'s durable references.

Failure mode this prevents: each artifact is defensible alone and the aggregate is what the reader actually meets, so reviewing any one of them never surfaces the volume — and the repetition reads as thoroughness rather than as three copies of one paragraph. The copies then age at different rates, leaving a later reader who notices them disagreeing with no way to tell which is current.

## Keep the methodology out of the durable record

A measurement's *result* belongs in a commit message, an ADR, or a PR body. How it was arrived at — "five runs each way", "measured back to back", "median of three", "verified with a positive control" — belongs in the chat where the work happened. The reader of the artifact wants the number and whether to trust it, and an honest hedge already carries that: "about 4.1s to about 2.7s" says the figure is approximate without narrating the procedure that made it so.

This is not license to drop provenance where provenance is the claim. `honesty.md` still governs: a number a reader must be able to check keeps its citation, and an estimate is still labeled as one. The distinction is between *what a reader needs in order to judge the claim* and *what shows the author did the work*. The second is self-justification, and it reads as such.

Failure mode this prevents: the durable artifact accretes evidence of diligence in place of statements of fact, a register shift the author then has to edit out by hand.

## Label consecutive images rather than running them together

When a document places one image directly after another — a before/after pair, a set of screenshots,
anything a reader is meant to compare — put a short label line above each one. `Before:` and
`After:` on their own lines is enough. Leave them unlabeled only when they genuinely are one thing,
like frames of a single sequence.

Whatever separation the renderer supplies is a gap and nothing more. A break between two images says
they are two images, never which is which. Nor is the direction they run in a property of the
markdown — the same pair can stack on one surface and sit side by side on another.

Sharpest for animated GIFs, which play whether or not they are being looked at, so two of them
adjacent compete for attention and neither gets read.

Failure mode this prevents: the images are the right images in the right order, so nothing about the
output looks wrong to whoever assembled it — the whole cost lands on the reader, who has no way to
tell which image is which, and the author is the one person who cannot see the problem because they
already know.

## Use American spellings

American spellings in durable output — `behavior`, `color`, `recognize`, `center`, `labeled`,
`judgment`. This is a marker-level preference, so the preamble's scope governs it: anything under
the user's byline, and not conversational replies.

`licence` is worth naming apart from the rest. British splits it by part of speech — noun `licence`,
verb `license` — where American uses `license` for both, so the British noun reads to an American
reader as a misspelling rather than as a locale choice. That is a worse failure than `behaviour` or
`colour` produce, which read as merely foreign. `defence`/`defense` is a plain variant carrying no
such split.

Sweeping for these is a different job from writing them. A stem match hits words that are already
American — `organis` catches `organism`, `generalis` catches `generalist`, `enrol` catches
`enrollment`, `realis` catches `realistic`. A quoted passage keeps its source's spelling, so an
external quote is not yours to correct. And `analyses` is the noun plural in both, so changing it
fixes no spelling and can break an anchor link into a heading that uses it.

Failure mode this prevents: each instance is invisible in place, because nothing about `behaviour`
in a sentence looks like a decision. The drift is noticed only when some word happens to look wrong
in isolation, by which point it is spread across files — and whatever has landed in an accepted ADR
or a pushed commit message cannot be swept at all.

## Markdown authoring mechanics

When producing markdown for a strict renderer — a committed doc, a README, a PR body, an IDE preview — a small set of fragile constructs (fenced code inside a list item, an inline fence marker in prose, tables holding block content, &c.) render differently across implementations or break outright, and markdown never errors to warn you. The full list, the why, and the formatting discipline are in `rules/references/writing/markdown-authoring.md`. Load it when generating markdown bound for a durable deliverable.

## Emulating the user's voice

When writing in the user's voice — drafting a message *from* him, ghostwriting a comment he'll post, or any output where the goal is to sound like Yossef rather than to serve a broader audience — match the register described below. This also governs anything under his byline that serves a reader (a commit message, a PR description, a doc), which is most sessions.

Never refer to him in the third person in output carrying his byline. "…which Yossef flagged as close but not final" is correct in a project note recording who decided what, and wrong in a PR description he is signing. The slip happens moving material *between* those two documents: a fact arrives attributed by name, because that is how it was said and how a note rightly records it, so the identical sentence is right in the source and wrong in the destination. That makes it a transcription error at a document boundary rather than a lapse of register, which is why none of the markers below catch it.

Grep for his name over anything about to go out under it — one command covers the whole class, where re-reading for voice does not. The cost is asymmetric by destination: a PR body stays editable, a commit body cannot be amended once pushed.

### Register

Precise, slightly antiquarian, unhedged. He likes phrasings that name things honestly without apologizing for them — e.g. "archaic Latin abbreviations" rather than "old-fashioned shortenings" or "fancy Latin stuff". When in doubt between a plain word and a precise-but-old-fashioned one, lean toward the precise one. Do not hedge, soften, or add throat-clearing qualifiers.

This register is the *why* behind the specific markers, and the guide for picking new phrasings the rule doesn't explicitly cover. The markers themselves — the archaic Latin abbreviations (`&c.`, `viz.`, `cf.`), the valediction-not-summary ending, the concrete-behavior close, the audible-hedge habit, the comma/em-dash/parenthesis split, and the punctuation defaults (semicolon avoidance, em-dash over colon, quote-mark placement) — live in `rules/references/writing/voice.md`. Load it whenever drafting under his byline, most often a commit message or PR description.

Failure mode this prevents: the markers are individually small but collectively a strong LLM tell. Skipping them lets byline output default to model-habit punctuation and voice, which reads as ghostwritten even when the register is right.
