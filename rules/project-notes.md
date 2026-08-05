# Project Notes

Some projects maintain long-running notes that don't belong in code, commit messages, memory, or session handoffs: cleanup-debt lists for an MVP, drafted feedback to upstream projects, lessons to roll back into a template the project was derived from. These notes outlive any single session, get appended across many sessions, and serve audiences different from the current commit reader.

This rule covers the *recognition* habit — noticing mid-work that something just learned is filing-worthy, and acting on it before it evaporates. Structural conventions and the production workflow live in the `project-notes` skill. The destinations themselves are project-specific config (see *Project configuration* below).

## When to file

Concrete triggers — act on these without waiting to be asked:

- **An upstream gap or limitation surfaced** during real work and needed working around (a gem's missing pathway, a service's surprising behavior, a framework's silent no-op, an API's undocumented quirk). The reproduction and the workaround are vivid in working memory right now. In a week they won't be.
- **A workaround was shipped that should be reverted when the upstream gap closes.** Capture the workaround, the gap it routes around, and the concrete condition under which the workaround can go away. Without this, the workaround becomes load-bearing forever.
- **A surprising setup or configuration step** had to be discovered the hard way — a multi-buildpack ordering, an env-aware credentials gotcha, an undocumented flag, a buildpack/dependency interaction. The next person setting this up (a teammate, a future self, a stranger spinning up the template) needs to know.
- **A debt was consciously deferred** with a clear *when to revisit* trigger (when the second deploy target is added; when the multi-dev collision bites in practice; when user count crosses N). The deferral is fine, losing track of it isn't.
- **A lesson generalizes beyond this project** — a default that bit, a gotcha the upstream template ships, anything that would help the next template-derived app avoid the same pit. File against the template or upstream, not this project's cleanup list.

The bar is *would this be lost if I don't file it somewhere outside the code or commit?* If the answer is no — it'll survive in a code comment, in the commit message, or because it's obvious from the diff — don't file. Over-firing dilutes the notes, under-firing loses them.

## What to do

When a trigger fires:

1. **Recognize the moment** using the list above. Don't wait for the user to prompt.
2. **Check project configuration** for declared notes destinations. Look in `CLAUDE.md`, `.claude/CLAUDE.md`, or any rule files imported from them via `@path` references. **Then read the destination files themselves**, not only the declaration naming them. A destination's name says what it collects; only its contents say whether this finding already has a home there. An existing entry may frame the same problem, hold the exact slot the finding belongs in (a candidate section awaiting instances, a proposed reference with a trap list), or record a prior decision that changes the routing.
3. **If destinations are declared and the finding fits one**: invoke the `project-notes` skill, or — if the destination and shape are obvious — file directly and mention it.
4. **If destinations are declared but the finding doesn't fit any of them**: read each candidate file before concluding that. A "doesn't fit" reported from a destination's name alone is an unverified claim about a file's contents, and it reads to the user as though the files were checked. Once the files have actually been read and the finding genuinely fits none of them, don't silently force-fit. Surface a three-way choice to the user:
    - File under the closest declared destination, naming it explicitly so the stretch is visible.
    - Declare a new destination type for this kind of finding (and append it to the existing destinations block — see step 5).
    - Skip filing for this finding.
5. **If no destinations are declared at all**: surface the recognition to the user with a one-line summary of what would be filed. Ask whether to declare destinations now or skip filing. If the user agrees, invoke the `project-notes` skill — it owns the declaration shape and the location choice (root `CLAUDE.md` vs split-pattern vs `.claude/CLAUDE.md`).

The skill carries the detail of how each step writes its output (file shape, append vs. integrate, prompts). The rule's job is recognition and routing decisions.

Failure mode the read-the-destination step prevents: a routing question gets answered from the destinations' *names* plus whatever else is at hand — git history, the code, an earlier read of one destination — and the unread destination gets ruled out. The answer arrives as a confident "this one, not that one," or worse as a manufactured "it doesn't fit anywhere," when the unread file already proposed the very thing the finding belongs to. The user then has to supply from memory what reading the file would have shown, which is the opposite of what these files exist for. This is `honesty.md`'s *Do Not Assert Absence Without Verifying* applied to the notes destinations specifically — absence in what has been read is not absence in the file.

## Relation to `self-improvement.md`

Both rules watch the same broad terrain — moments mid-work where something is worth capturing — but they file different artifacts:

- `self-improvement.md` files an update to a rule or skill: the *model's defaults* were too lax, contradictory, or missing somewhere.
- This rule files a note in the project: the *codebase or its upstreams* have a gap, debt, or lesson that needs to live somewhere external to the code.

The same moment often fires both. A workaround the model fell back to during a task might be *both* a rule that should be tightened *and* an upstream limitation that should be documented for the codebase. File in both places — the audiences are different.

## Project configuration

This rule is general, the destinations are project-specific. A project that uses this rule declares its notes destinations somewhere always-loaded — typically `CLAUDE.md` or a rule file imported from it. See the `project-notes` skill for the destination types it understands (cleanup-debt, upstream-feedback, derived-template lessons) and the per-destination structures.

A project with no declared destinations falls through to step 5 above — the recognition still fires, but filing requires confirming a destination first.

## Failure mode this prevents

Findings that surface during real work — gotchas, gaps, deferred debt, generalizable lessons — evaporate into commit messages no one re-reads, or into model working memory which gets compacted. Without an explicit "file this" recognition, the loop is: discover, work around, ship, forget. The cost shows up later as the same discovery being made twice, as upstream feedback never reaching the project that needed it, or as a "we'll revisit it when X happens" condition that no one was watching for when X happened.
