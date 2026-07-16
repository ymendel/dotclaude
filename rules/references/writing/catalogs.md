# Writing Catalogs — Metaphor Offenders and Term-of-Art Collisions

> Not loaded in context by default. See `rules/writing.md` for the directives, heuristics, and failure modes.

## Violent and military metaphor examples

Categories and examples for the "Avoid violent and military metaphors" rule:

- **Overt violence**: "kill two birds with one stone", "take a stab at", "shoot down", "pull the trigger on", "bite the bullet".
- **Military or war origins**: "boots on the ground", "rally the troops", "in the trenches", "battle-tested", "war room", "scorched earth", "marching orders", "war story".

The "in anger" and "war story" specific-replacement directives stay in `writing.md` — they name particular high-frequency traps with prescribed alternatives, not just examples to check against.

## Term-of-art collision examples

The three shapes named in `writing.md`'s "Avoid words that collide with terms of art" rule, with their full example breakdowns and remedies:

- **Loose or metaphorical use vs. term of art.** A word used in its plain sense, or stretched metaphorically, that also names a specific technical operation in the reader's domain. The technical sense wins the parse. Examples in software contexts: "rebase" (metaphorical: re-anchor onto a different foundation; git: replay commits onto a new base), "fork" (lay: a branch in a path; git/process: copy a repo or process), "merge" (lay: combine; git: combine branches), "stash" (lay: hide away; git: shelve working changes), "amend" (lay: edit/improve; git: rewrite the most recent commit), "rollback" (lay: undo; databases: revert a transaction). When the looser sense is what you want, pick a word that doesn't collide — "re-anchor", "split", "combine", "park", "edit", "undo".
- **Term of art in one context vs. another.** A word that's technical in multiple sub-fields, distinguished only by surrounding cues. The dominant sub-field for the immediate reader wins. Examples: "branch" (git vs. AST traversal vs. control flow), "thread" (concurrency vs. message thread vs. textile), "kernel" (OS vs. linear algebra vs. ML), "argument" (function parameter vs. rhetoric), "tree" (data structure vs. file system vs. UI vs. botany), "stream" (Turbo/HTTP vs. functional iterators vs. video), "lock" (concurrency vs. cryptography vs. file system). If two sub-fields are both plausible from the surrounding text, disambiguate explicitly or pick a non-colliding word.
- **Named methodology or framework concept that imports a whole model.** A multi-word capitalized concept from a methodology (Scrum/Agile, ITIL, Six Sigma, &c.) that parses *correctly* as the words say but drags in a specific model the writer may not intend. Here the collision isn't a mis-parsed word — it's an imported connotation. Examples: "Definition of Done" (Scrum: a pre-release quality gate — work isn't done until a checklist is met, *before* release; you may mean the plain finish line — shipped and settled, *after* release), "Sprint", "Epic", "WIP limit". A reader fluent in the methodology reaches for its model first. This shape is easy to miss precisely because the words are right — the single-word examples above trip recognition, a phrase that reads plainly does not. Remedy is the same: define the term explicitly on first use, or frame it so the methodology model isn't invoked ("what 'done' means on our board" rather than "our Definition of Done").
