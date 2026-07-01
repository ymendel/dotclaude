# Companion Infrastructure

What `project-notes` depends on beyond the skill directory itself. The skill produces well-structured notes once invoked, but the *recognition* — knowing when to file — lives in a rule the skill cannot carry. `SKILL.md` already cross-references this rule, but an adopter working from the skill alone won't have the rule itself.

## Why this file exists

A skill packages as a self-contained directory and can be installed in many ways — a personal config repo, a plugin, a marketplace install. But anything that integrates with the host — rules loaded passively each session, `settings.json` hooks, permission allowlist entries — lives *outside* the skill directory and doesn't ship with the package. This file is the manual half: when you install `project-notes` into a new environment, this is what to set up alongside it.

`project-notes` has no host config — no scripts, no hooks, no permission allowlist. The companion is one rule, optionally two.

## 1. The recognition rule (without it, the skill is invocation-only)

Without a rule, the model only invokes `project-notes` when the user explicitly asks. The skill's value is highest when the model *recognizes* the moment to file — when an upstream gap is worked around, when a debt is deferred with a "revisit when X" trigger, when a setup gotcha had to be discovered the hard way. The rule encodes those triggers.

### Sample wording

Paste this into your own rule file (e.g. `~/.claude/rules/project-notes.md`), or into a `CLAUDE.md`, and edit to taste.

> Some projects maintain long-running notes that don't belong in code, commit messages, memory, or session handoffs: cleanup-debt lists, drafted upstream feedback, lessons to roll back into a template the project was derived from. These notes outlive a single session, get appended across many sessions, and serve audiences different from the current commit reader.
>
> ### When to file
>
> Concrete triggers — act on these without waiting to be asked:
>
> - **An upstream gap or limitation surfaced** during real work and needed working around (a gem's missing pathway, a service's surprising behavior, an API's undocumented quirk). The reproduction and the workaround are vivid in working memory right now; in a week they won't be.
> - **A workaround was shipped that should be reverted when the upstream gap closes.** Capture the workaround, the gap it routes around, and the concrete condition under which the workaround can go away.
> - **A surprising setup or configuration step** had to be discovered the hard way — buildpack ordering, env-aware credentials, undocumented flags. The next person setting this up needs to know.
> - **A debt was consciously deferred** with a clear *when to revisit* trigger.
> - **A lesson generalizes beyond this project** — a default that bit, a gotcha the upstream template ships. File against the template or upstream, not this project's cleanup list.
>
> The bar: *would this be lost if I don't file it somewhere outside the code or commit?* If no, don't file. Over-firing dilutes the notes; under-firing loses them.
>
> ### What to do
>
> When a trigger fires:
>
> 1. Recognize the moment. Don't wait for the user to prompt.
> 2. Check project configuration for declared destinations (in `CLAUDE.md`, `.claude/CLAUDE.md`, or any rule files imported via `@path`).
> 3. If destinations are declared and the finding fits one: invoke the `project-notes` skill, or file directly if the destination and shape are obvious.
> 4. If destinations are declared but the finding doesn't fit any: don't force-fit. Surface a three-way choice (closest declared destination / declare a new destination type / skip).
> 5. If no destinations are declared at all: surface the recognition with a one-line summary and ask whether to declare destinations now or skip filing.

Without this rule, the skill remains invocation-only and most filing opportunities evaporate before the user thinks to ask.

## 2. Optional companion rule: cross-project notes

`project-notes` files findings against project-specific destinations (cleanup-debt, upstream-feedback, derived-template). When a finding *generalizes beyond any single project* and no upstream / template destination exists yet, it has nowhere to go. A second rule can declare a personal-config notes directory as the catch-all home.

Skip this section unless you maintain `~/.claude/`-level config and want a place for cross-project ecosystem quirks.

### Sample wording

> Some lessons outlive any single project and don't fit the project-specific destinations covered by the `project-notes` rule. For those, the durable home is `~/.claude/notes/` (or your equivalent personal-config directory).
>
> ### What lives there
>
> Cross-project, long-lived, non-behavioral knowledge:
>
> - Defaults to include in a future template (gems, linter config, migration tooling) before that template's repo exists.
> - Ecosystem quirks worth remembering — a Postgres / Rails / npm gotcha that bit once.
> - Tooling observations that apply broadly.
>
> ### What does NOT live there
>
> - **Behavioral guidance** — how the model should approach work. That goes in `~/.claude/rules/`.
> - **Project-specific context** — ongoing work, decisions, references for a single project. That goes in that project's memory or its declared destinations.
> - **Anything already covered by an existing skill or rule** — extend the skill or rule instead.
>
> ### When to file
>
> When the `project-notes` recognition triggers apply but the finding generalizes beyond the current project AND no upstream / template destination exists yet, file under `~/.claude/notes/`. Surface the filing briefly to the user — same one-line "filed under <path>" pattern as the `project-notes` skill uses.

If your `~/.claude/` directory is tracked in git, gitignore the notes directory — these are personal working notes, not configuration to ship.

## 3. Companion rule: sensitive knowledge (family-wide)

**Intent:** `project-notes` commits by design — findings land in declared destinations, some of them tracked. So the sensitive half of a note (people and relationship knowledge, not system knowledge) has to be routed out *before* it lands, not cleaned up after. This is a family-wide rule the whole knowledge-worker toolkit inherits, not specific to `project-notes`.

**Failure without it:** a candid note — how a client actually operates, who to route around, what "approved" really means — gets committed to a repo the client or a third party controls, where it can't be retracted.

### Sample wording

Paste into your rule file (the fuller version is `sensitive-knowledge.md` in the toolkit) and edit to taste.

> When filing a note, split the knowledge by kind, by default. Commit system knowledge (how things work, why decisions were made). Route people and relationship knowledge — how to work with a client, what "approved" really means, who holds authority, anything credentials-adjacent — to a private, gitignored file. Key the split on the *kind* of knowledge, which you can read from what you're writing, not on who owns the repo, which you can't reliably detect. Ownership sets the stakes — a leak into a repo you don't own can't be retracted.

## Adopting these in a new environment

Rough order:

1. Paste the recognition rule wording (section 1) into your rule file or `CLAUDE.md`.
2. (Optional) If you want a cross-project notes destination, paste section 2's wording and create the directory (`~/.claude/notes/` or your equivalent).
3. Paste the sensitive-knowledge wording (section 3) into your rule file — or adopt the toolkit's `sensitive-knowledge.md`, which states it family-wide.

The skill itself ships no host config — no permissions to add, no hooks to register.
