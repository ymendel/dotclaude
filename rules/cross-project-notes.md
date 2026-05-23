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

When a finding could go in two places, prefer the more specific one. A note about "strong_migrations should be in our Rails template" goes here only because no template repo exists yet to file it against; once one exists, the note moves there.

## Structure

- One file per topic, named for the topic: `template-lessons.md`, `postgres-quirks.md`, `rails-defaults.md`, etc.
- Free-form within each file. Append new entries at the bottom unless related material exists to group with.
- Subdirectories are fine if a topic grows large enough to warrant them.

The directory is intentionally outside version control (the allowlist `.gitignore` in `dotclaude/` excludes anything not explicitly added). These are personal working notes, not configuration to ship.

## When to check

When a question or task has plausibly accumulated cross-project wisdom — defaults for a new project of type X, a known quirk of tool Y, a pattern that's bit you before — check the relevant file in `~/.claude/notes/` before answering. Don't read the whole directory preemptively; reach for it the same way you'd reach for a skill or rule when the topic is relevant.

## When to file

When the project-notes recognition triggers fire (see `project-notes.md`) but the finding generalizes beyond the current project AND no upstream / template / external destination exists yet, file under `~/.claude/notes/`. Surface the filing briefly to the user — same one-line "filed under <path>" pattern as the project-notes skill uses.

## Failure mode this prevents

Without this destination, cross-project lessons either (a) get force-fit into project memory where they die with the project, (b) get force-fit into rules where they pollute behavioral guidance with topical content, or (c) evaporate. The notes directory is the explicit "this is durable, non-behavioral, cross-project knowledge" slot that those three failure modes route around.
