---
name: project-notes
description: "File a long-running project note in the right destination — cleanup debt, upstream feedback, or template/derived-project lessons. Trigger phrases include 'file this as cleanup debt', 'add a cleanup note', 'draft upstream feedback for <project>', 'capture this as a template lesson', or auto-fired by the project-notes rule when its recognition triggers match."
---

# Project Notes

Produce well-structured, persistent project notes for findings that surfaced during real work and would be lost otherwise. Three destination types are supported; a project declares which apply and where each lives.

For the *recognition* habit — knowing *when* to file — see `~/.claude/rules/project-notes.md`. This skill is the production workflow once a moment has been recognized.

Not for decisions — a decision and its rationale belong in an ADR (the `adr` skill). Project-notes captures debt, gaps, and lessons. A deferral that is both files its revisit-trigger here and its rationale as an ADR if it's ADR-worthy.

## Destination types

| Type | Audience | Typical location |
|---|---|---|
| **cleanup-debt** | A future maintainer of this codebase | A single running file, e.g. `docs/cleanup-notes.md` |
| **upstream-feedback** | Maintainers of a separate project (a gem, framework, service) | Per-target file, e.g. `docs/upstream-feedback/<project>-<issue>.md` |
| **derived-template** | The next person spinning up an app from a template this project was derived from | Integrated into existing template-related docs, e.g. `docs/template/analysis.md` |

A project may declare other destination types; treat the three above as the defaults.

## Workflow

### Step 1: Read project configuration

Look for declared destinations in:
- `CLAUDE.md` at project root
- `.claude/CLAUDE.md`
- Any rule files imported into either via `@path` references

The signal is a `## Project notes` heading containing a `Destinations:` block (or `Destinations the project-notes skill should use:`) — grep for one of these to make the search deterministic.

A project that uses this skill typically declares something like:

```
## Project notes

Destinations:
- cleanup-debt: docs/cleanup-notes.md
- upstream-feedback: docs/upstream-feedback/<project>-<issue>.md
- derived-template: docs/template/{analysis,applying}.md (integrate, don't append)
```

**If no destinations are declared**: don't invent paths. Surface the finding to the user with a one-line summary, and ask whether to declare destinations now or skip filing. If the user agrees to declare, follow *Declaring destinations* below.

### Step 2: Determine destination type

If invoked explicitly with a destination in the user's message ("file this as cleanup debt"), use that. Otherwise route based on audience:

- The note is about something *this codebase* needs to do (debt, deferred work, follow-ups within this repo) → **cleanup-debt**.
- The note is about something *another project* needs to fix or know (gem bug, framework gap, service quirk) → **upstream-feedback**.
- The note is a *generalizable lesson* for the upstream template/scaffold this project was derived from, written so a stranger spinning up a new app benefits → **derived-template**.

A single finding can map to multiple destinations — file in each that applies. Example: a Solid Queue scheduler limitation that the project worked around gets a cleanup-debt note here (the workaround can be removed when…), an upstream-feedback draft for the gem's issue tracker, and a derived-template caveat warning future apps not to rely on dynamic recurring task updates.

**If the finding doesn't fit any declared destination**: don't silently force-fit or auto-invent a new destination. Surface a three-way prompt:

- File under the closest declared destination, naming the stretch explicitly so the user accepts it consciously.
- Declare a new destination type for this kind of finding (e.g. `ops-runbook`, `deprecation-tracker`). On agreement, append the new entry to the existing destinations block — see *Declaring destinations* below.
- Skip filing for this finding.

The user makes the judgment call. The skill's job is to surface that the existing types don't fit, not to decide whether the finding warrants a new type.

### Step 3: Produce the entry

Use the per-destination template below. Three structural anchors are common across all three:

- **What it is** — a tight statement of the gap, gotcha, or debt.
- **Why it matters** — concrete consequence, ideally with a date or observed incident.
- **What to do next** — options (typically 2–3), or a "when to revisit" trigger, or both.

Avoid: vague observations without a follow-on action; abstract "we should think about X" without naming X concretely; entries that don't survive being read by someone who doesn't know the current conversation.

### Step 4: Write to the destination file

- **cleanup-debt** and **upstream-feedback**: append to the destination file as a new heading. Don't overwrite or rewrite adjacent entries.
- **derived-template**: integrate into the existing document structure rather than tacking on a new section. Template docs are read top-to-bottom; new lessons should land where they fit topically, often next to the recommendation they qualify.

After writing, summarize to the user: the destination, a one-line description of what was filed, and any follow-on (e.g. an upstream comment that was drafted but not posted).

## Declaring destinations

When destinations don't yet exist, or when a new destination type is being added to an existing block, the declaration needs a home. Pick by checking what the project already does:

1. **If the project's root `CLAUDE.md` exists and is monolithic** (no `@path` imports of rule files): append a `## Project notes` section directly to it. This is the default — most discoverable, always loaded, no new convention introduced.

2. **If the project already uses a split pattern** (thin `CLAUDE.md` that `@imports` rule files from `.claude/rules/` or similar): match that pattern. Create or extend `.claude/rules/project-notes.md` and add `@.claude/rules/project-notes.md` to `CLAUDE.md` if not already imported. Don't introduce a second pattern alongside an existing one.

3. **If the project has no `CLAUDE.md` at all**: create one at the project root with the `## Project notes` section. Don't reach for `.claude/CLAUDE.md` first — root `CLAUDE.md` is the conventional location.

The first-time prompt should default to option 1 (or 2 if split is detected) and only offer alternatives if the user pushes back. Don't present a multi-option menu by default.

The destinations block follows this shape:

```markdown
## Project notes

Destinations the `project-notes` skill should use:

- **cleanup-debt** → `<path>` (append as new heading)
- **upstream-feedback** → `<path-pattern with placeholders>` (one file per upstream issue)
- **derived-template** → `<path(s)>` (integrate, do not append; lessons go next to the recommendation they qualify)
```

When **adding a new destination type to an existing block**, append to the same list — don't create a parallel block elsewhere. Use the same `**type** → path` shape. If the new type needs structural conventions different from the three built-ins (e.g. a single-file append vs. a per-target file), include a parenthetical note like the existing ones.

After declaring (or extending) destinations, proceed with filing the finding that triggered this in the first place.

## Templates

### cleanup-debt

```markdown
### <Short, specific title>

<1–3 paragraphs: what the gap or debt is, what surfaced it, why it matters. Include a date or commit ref if the finding is recent.>

**Options:**
- <Option 1: concrete path forward>
- <Option 2: alternative>
- <(Optional) Option 3>

**When to revisit:** <Concrete trigger — "when X happens", not "eventually".>
```

Rules of thumb:
- Title is a noun phrase, not a verb ("Identifier durability across environments" rather than "Fix identifier durability").
- Options should be genuine alternatives, not a single path padded out. If there's only one option, drop the heading and state the path forward in prose.
- *When to revisit* makes the deferral honest. "Eventually" or "someday" is a signal the bar wasn't met for filing.

### upstream-feedback

```markdown
# Draft <comment | issue | PR description> for <upstream-project>#<issue or PR>

Filed at: <URL, or "not yet filed">

**Status:** drafted <YYYY-MM-DD>; <posted | not yet posted>. Post via:

\`\`\`sh
<exact command to post, e.g. gh issue comment …>
\`\`\`

(Remove these top lines before posting — body below is the comment text proper.)

---

<Comment body, written for the upstream audience:>

<Reproduction details a stranger can use — versions, exact reproduction steps, what was observed vs. expected.>

<If a workaround exists, describe it cleanly enough that other affected users can apply it.>

<If a fix shape is clear, suggest it; offer to PR if useful.>
```

Rules of thumb:
- Write for the upstream audience, not for internal readers. Don't reference internal code or jargon.
- Keep the top-of-file metadata (filed-at URL, status, post command) separate from the body so the body can be sent verbatim.
- Reproduction details belong in the body; the *reason this matters to our project* belongs in cleanup-debt (file both).
- Update the *Status* line when the comment is posted, so the file's state matches reality.

### derived-template

Integrate into the existing template docs structure rather than creating a new section. Identify the recommendation or section the lesson qualifies, and add the caveat or gotcha next to it.

Per-lesson shape (whether 1 paragraph or a subsection):

- **Lead with the lesson**: "The template recommends X" or "Apps using X on platform Y need…".
- **Concrete failure mode**: what breaks, with the symptom the next person will see.
- **Fix or workaround**: in enough detail that a stranger applying the template can act on it without reverse-engineering the original incident.

Avoid: writing template lessons as "we did Y in this project" — strip references to this specific app. Generalize to the template's audience.

## When invoked without enough context

If the user invokes the skill without specifying the finding, ask one focused question:

> What's the finding, and is it about this codebase, an upstream project, or a lesson for the derived template?

Don't ask multiple questions in a long preamble — the recognition is usually fresh.

## Failure modes this skill prevents

- **Notes shaped like prose dumps**: long paragraphs with no options and no revisit trigger. A future reader doesn't know what to do.
- **Workarounds with no removal condition**: the workaround becomes load-bearing forever because no one knows when it can go.
- **Upstream-feedback drafts that stay drafts**: file with a clear post command and status line; the act of writing the post command often pushes the actual posting.
- **Derived-template lessons that reference the current project**: the lesson doesn't generalize and gets ignored by the next reader.
