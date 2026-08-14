# Cross-Project Notes

Some lessons, observations, and references outlive any single project and don't fit the project-specific notes destinations (cleanup-debt, upstream-feedback, derived-template) covered by `project-notes.md`. For those, the durable home is `~/.claude/notes/`.

## What lives there

Cross-project, long-lived, non-behavioral knowledge:

- Defaults to include in a future template (e.g., gems to bundle, migration safety tooling, linter config) before that template's repo exists or is reachable.
- Ecosystem quirks worth remembering — a specific Postgres / Rails / Heroku / npm gotcha that bit once and would help any future project.
- Tooling observations that apply broadly (CLI behaviors, build-system surprises).
- Drafts of writeups that haven't found a home yet.

## What does NOT live there

- **Behavioral guidance** — how Claude should approach work. That goes in `~/.claude/rules/`.
- **Project-specific context** — ongoing work, decisions, references for a single project. That goes in that project's memory or its declared `project-notes` destinations.
- **Anything already covered by an existing skill or rule** — extend the skill or rule instead.

When a finding could go in two places, prefer the more specific one. A note about "strong_migrations should be in our Rails template" goes here only because no template repo exists yet to file it against. Once one exists, the note moves there.

## Structure

- One file per topic, named for the topic: `template-lessons.md`, `postgres-quirks.md`, `rails-defaults.md`, etc.
- Free-form within each file. Append new entries at the bottom unless related material exists to group with.
- Subdirectories are fine if a topic grows large enough to warrant them. This applies to any working-doc directory, not just `notes/` — when a topic in `ideas/`, `notes/`, or similar accumulates more than a couple of files, group them in a named subdirectory with a `README.md` frame rather than letting the flat directory sprawl.

The directory is tracked, but not here. It lives in the private repo and is surfaced into this tree as `dotclaude/notes` → `<private-root>/notes`, a symlink that stays gitignored because dotclaude's allowlist `.gitignore` re-includes nothing that would cover it. So the notes get version history and cross-machine sync without unpublished personal material entering a public tree. See [ADR 0005](../docs/adr/0005-private-skills-separate-repo.md), whose 2026-07-13 amendment moved them there.

The consequence worth carrying: these are personal working notes rather than configuration to ship, and the destination they are tracked in may itself gain a remote later. Sensitive material therefore does not belong in a note — it goes under a `private/` subdir, which that repo's `.gitignore` excludes wherever it appears. `sensitive-knowledge.md` governs the split.

## When to check

When a question or task has plausibly accumulated cross-project wisdom — defaults for a new project of type X, a known quirk of tool Y, a pattern that's bit you before — read `~/.claude/notes/README.md` before answering. It is a one-line-per-note index, so the whole directory's contents cost one read. Open the linked file only when the topic matches. Don't read the notes themselves preemptively. Reach for the index the same way you'd reach for a skill or rule when the topic is relevant.

The index makes the *look* cheap — it cannot make the look happen. Like `parked-ideas.md`, this still depends on noticing that a topic might have accumulated something — the same recognition failure that hooks exist to route around. It is strictly better than judging 25-odd filenames from a directory listing, and it is not a structural guarantee.

## When to file

When the project-notes recognition triggers fire (see `project-notes.md`) but the finding generalizes beyond the current project AND no upstream / template / external destination exists yet, file under `~/.claude/notes/`. Surface the filing briefly to the user — same one-line "filed under <path>" pattern as the project-notes skill uses.

**Filing a new note means adding its line to `notes/README.md` in the same edit** — name plus a one-line hook, in the matching group. A note absent from the index is a note the *When to check* step above will not find, which defeats the filing. Adding to an existing note needs an index line only if the hook no longer covers what the file holds. Keep content out of the index — the note file is where substance lives.

## Failure mode this prevents

Without this destination, cross-project lessons either (a) get force-fit into project memory where they die with the project, (b) get force-fit into rules where they pollute behavioral guidance with topical content, or (c) evaporate. The notes directory is the explicit "this is durable, non-behavioral, cross-project knowledge" slot that those three failure modes route around.
