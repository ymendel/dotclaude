---
name: session-doc
description: "Produce the narrative session document paired with `session-handoff` — title, why this happened, what was done, decisions worth revisiting, lessons, next moves; audience is a human re-reader weeks later. Invoke after a handoff when the project declares a `## Session docs` destination in `CLAUDE.md`. Also fires on 'write session doc', 'session narrative', 'document this session'. Suggest proactively at session wrap-up if a destination is declared and no doc was produced. Skip when no destination is declared and the user didn't ask."
---

# Session Doc

Produce a narrative meta-document capturing the *arc* of a working session: why it happened, what was decided, judgment calls worth re-examining, and what to carry forward. The audience is a human re-reader weeks later — a teammate joining the project, a collaborator catching up, or future-you. Pairs with `session-handoff`, which is the mechanical resume-for-next-agent document. The two are intentionally not collapsed: their audiences and shapes differ.

For the *invocation* habit — knowing *when* to produce one — see *When this fires* below. This skill is the production workflow once a session has earned a doc.

## Pairing with `session-handoff`

| Artifact | Audience | Optimized for | Where it lives |
|---|---|---|---|
| `session-handoff` (`.claude/handoffs/`) | The next Claude session | Cold-resume mechanics | Always |
| `session-doc` (project-declared path) | A human re-reader weeks later | Narrative judgment-capture | Only when the project declares a destination |

The handoff carries structured fields the resuming agent needs. The session doc carries *why this session happened*, *what judgment calls were made and why*, and *lessons worth carrying forward*. Overlap exists on the surface facts (commits, branch, ADR refs); divergence is on register and intent.

## When this fires

Three triggering shapes:

1. **Auto-fired by `session-handoff`** when the project declares a `## Session docs` destination. The handoff workflow ends with a step that checks for the declaration and invokes this skill if present. This is the common case.

2. **Explicitly requested** — phrases like "write session doc", "produce the session narrative", "document this session for the team". Fire on direct invocation even without a destination declared (then use *Declaring the destination* below).

3. **Proactive suggestion** at the end of a substantial session where a handoff has already been produced and a destination is declared, but the auto-fire wasn't taken. Suggest before the user signs off.

**Do not fire** when no destination is declared *and* the user didn't ask. A session-doc without a home is wasted output; surface the recognition and let the user decide whether to declare a destination.

## Workflow

### Step 1: Read the destination declaration

Look for a `## Session docs` heading in:

- `CLAUDE.md` at project root
- `.claude/CLAUDE.md`
- Any rule file imported into either via `@path` references

A typical declaration is a short prose block naming a path:

```markdown
## Session docs

Destination: `docs/sessions/` (one file per session, named `YYYY-MM-DD-<slug>.md`).

For a human re-reader weeks later — the *why*, the judgment calls, lessons worth carrying forward. Pairs with the mechanical handoff in `.claude/handoffs/`.
```

The format is intentionally loose; a path inside the block is enough. If multiple paths or formats appear, ask the user which applies before proceeding.

**If no `## Session docs` heading exists**: see *Declaring the destination* below.

### Step 2: Gather session material

Assemble the inputs the doc will draw from:

- **Commits on this branch** — `git log <base>..HEAD --oneline` (or equivalent for the relevant range). Capture exact hashes; the session doc records them. If the session produced no commits (investigation, spike, or work paused before committing), name what the session *did* produce — a finding, a reproduction, an investigation outcome — and skip the *Commits on `<branch>`* section.
- **The paired handoff**, if one exists — read it. The handoff's "Decisions Made", "Pending Work", and "Important Context" sections are starting material for *Inline decisions worth a look* and *Suggested next moves*.
- **Related artifacts** — any ADR, PR, upstream issue, or `.claude/handoffs/` companion file referenced by the work. Capture URLs and IDs for the header.
- **The session's arc** — what motivated this session, what surfaced mid-way, what was deferred. Most of this is reconstructable from the conversation; if anything is unclear, ask before drafting.

### Step 3: Pick sections by content, not template

Sections appear when they carry content. The menu is consistent but not rigid. See *Section menu* below for the tiers (required / encouraged / optional). Do not pad with empty headings.

### Step 4: Draft the doc

Write to `<destination-path>/YYYY-MM-DD-<slug>.md`. Use today's date and a slug describing the session's center of gravity (the work that defined the arc, not the last commit).

Apply the *Register* notes below — narrative prose with bullets (not pure bullet lists), high specificity, length proportional to session richness.

### Step 5: Cross-link

In the doc's header (when applicable), link related ADRs, PRs, upstream issues. In *Suggested next moves* (when present), reference the paired handoff explicitly so a future reader can pick up either path — re-read the narrative here, or resume the work from the handoff.

After writing, summarize to the user: the destination file, a one-line description of what's in it, and whether the paired handoff was also produced this session.

## Section menu

The session doc has three tiers of sections, parallel to ADR shape: required for the artifact to make sense, strongly encouraged when applicable, and optional. Within each section, format is flexible — pick the shape that best fits the session's texture.

### Required

- **Header** — title, date, branch. See *Header shape* below.
- **What was done** (sometimes phrased *What was implemented*) — narrative with bullets, covering the work the session produced. Subheadings when the work was phased (e.g., *Morning: scaffolding* / *Afternoon: integration*).
- **Commits on `<branch>`** — short list of hashes and one-line subjects. Traceability anchor for the rest of the doc.

### Strongly encouraged when applicable

- **Why this happened** — what triggered the session, what state the project was in beforehand, what the goal was. Without this, a future reader can't reconstruct the motivation. Skip only if the session was a pure continuation and the prior session's doc already covers the motivation.
- **Inline decisions worth a look** — the doc's load-bearing section. Bold-lead bullets (or whatever variant fits, see *Within-section flexibility*) on judgment calls that a future reader could reasonably re-litigate. Each entry names the choice, the alternative considered, and the reasoning. The bar is: *if a future reader could plausibly disagree with this call, surface it; if not, leave it out*.

  *Passes the bar:* **Refactored auth middleware before adding 2FA, not after.** Could have layered 2FA on the existing middleware and refactored later, but the middleware's session-handling was already the unclear part — doing it the other way means re-doing the 2FA wiring once the refactor lands.

  *Fails the bar (do not file):* **Used `dig` instead of `host` to check DNS.** Either works; the choice has no downstream consequences a future reader would re-litigate.
- **Suggested next moves** — explicitly framed as "these belong in the next session, not this one." Carries the work that surfaced but was deferred. Different from the handoff's "Immediate Next Steps": the handoff says what to do *right now*; this says what came up *but was set aside*.

### Optional

- **Open questions** — unresolved or unverified. Include the reproduction or the uncertainty, not just the question.
- **Live validation / Empirical verification** — end-of-session coda when the work included testing predictions against observations. Often a table.
- **Lessons worth carrying forward** — meta-lessons that generalize beyond this session. Sometimes explicit pointers like "this belongs in `~/.claude/rules`" or "file this against the template."
- **Related ADR / PR / upstream refs** — when not already captured in the header. A standalone section is fine if the refs are numerous.

## Header shape

```markdown
# Session: <descriptive title>

**Date:** YYYY-MM-DD                          # optionally "(morning)", "(continuation of …)"
**Branch:** <branch name>
**Related ADR:** [NNNN — Title](../adr/NNNN-…)   # when applicable
**Related PR:** [#N](url)                          # when applicable
**Related upstream:** [org/repo#N](url)            # when applicable
**Paired handoff:** [.claude/handoffs/...](…)      # when a handoff was produced
```

Drop any line that doesn't apply. Don't render an empty `**Related ADR:** —` placeholder.

## Within-section flexibility

The section *titles* are stable; the *shape inside each section* is not. Pick the form that fits the session's texture.

**Inline decisions worth a look** can be:

- **Bold-lead bullets** — `- **Chose X over Y because Z.** <one paragraph of reasoning>`. The default; works when most decisions are single-sentence.
- **Sub-sectioned by category** — `### Approach decisions` / `### Scope decisions` / `### Trade-off decisions`. Use when the doc has 6+ decisions and category structure helps the reader navigate.
- **Verdict-line variant** — each bullet ends with `→ <verdict>` (e.g. `→ stand by it`, `→ revisit if X`, `→ regretted, document the alternative`). Use when several decisions are explicitly tentative.

**Lessons worth carrying forward** can be:

- A flat bulleted list.
- Grouped by destination (`### Belongs in ~/.claude/rules` / `### Belongs in the project template` / `### Belongs in CLAUDE.md`) — useful when several lessons fan out to different homes.

**What was done** can be:

- A single narrative section.
- Phased subheadings when the work was discrete (`### Phase 1: API extraction` / `### Phase 2: caller migration`). Prefer descriptive labels over numbered ones — *Phase 1* and *Phase 2* force the reader to remember which is which; *Extraction* and *Migration* are self-explanatory each time they appear.

Same principle as ADR consequences-by-valence: the section's *purpose* is fixed, the section's *internal form* tracks the content.

## Register

- **Narrative prose with bullets**, not pure bullet lists. Reasoning belongs inline, not bracketed off into a separate "rationale" subsection.
- **High specificity.** Name gem versions, exact method names, identifier prefixes, release numbers, file paths. The reader weeks later needs the specifics to recognize what was touched.
- **Negative-evidence reasoning is welcome.** "Why pause/unpause was fine" — explaining why a finding *didn't* fire in adjacent cases is what makes a finding solid. The doc has room for this; the handoff often doesn't.
- **Tables for state comparison** — before/after, run-by-run, prediction vs. observation. Useful in *Live validation* especially.
- **Length proportional to session richness.** No fixed target. A light session gets a short doc; a five-hour multi-decision session gets a long one. Resist padding to look thorough.
- **Explicit deferral framing.** "These belong in the next session, not this one" carries weight in *Suggested next moves* — it's the difference between a parking lot and a forget-about-this-for-now.

## Declaring the destination

If invoked when no `## Session docs` block exists, surface a one-line summary of what would be filed and ask whether to declare a destination now or skip filing. If the user agrees to declare:

1. **If the root `CLAUDE.md` exists and is monolithic** (no `@path` imports): append a `## Session docs` section directly to it. This is the default.
2. **If the project already uses a split pattern** (thin `CLAUDE.md` that `@imports` rule files): match that pattern. Add `## Session docs` to an appropriate rule file or `.claude/CLAUDE.md`.
3. **If no `CLAUDE.md` exists**: create one at the project root with the `## Session docs` section.

Default to option 1 (or 2 if split is detected). Don't present a multi-option menu by default.

After declaring, proceed with the workflow.

## Naming and same-day collisions

The default filename is `YYYY-MM-DD-<slug>.md`. The slug describes the session's center of gravity, not the last commit.

If a session doc with the same date and a similar slug already exists, the work likely belongs in the existing doc (same-day continuation) — read it first and decide whether to extend it or branch a new file. When clearly distinct sessions land on the same day, discriminate by slug (`2026-05-30-auth-rewrite.md` and `2026-05-30-billing-bugfix.md`) rather than appending `-am`/`-pm`. If discrimination by content fails, fall back to a time qualifier in the title (`**Date:** 2026-05-30 (afternoon)`).

## Validation

A formal validation rubric — checking that *Inline decisions worth a look* meets the bar, that specifics aren't hand-wavy, that lessons aren't repackaged "things that happened" — is deferred to a future sibling skill (`session-doc-refine`, parallel to `adr-refine`). The producer skill does not enforce a rubric; it produces the doc according to the menu and register above. When a refiner exists, it will critique drafts after writing.

## Failure modes this skill prevents

- **Handoff content forced into the wrong register.** Without a separate skill, the *why this happened* and *lessons worth carrying forward* either bend the handoff template out of shape or never get captured. Both artifacts coexist because their audiences differ.
- **Empty *Inline decisions* sections.** The bar ("a future reader could plausibly disagree with this call") makes the section's threshold concrete. Without it, the section becomes either a dumping ground for routine choices or an empty placeholder.
- **Padded docs.** Length proportional to session richness keeps a light session's doc short — three paragraphs and a commit list — instead of expanding to fill a template.
- **Lost cross-references.** A session doc with no paired-handoff link strands the reader at the narrative without a path back to the resume mechanics, and vice versa. The header and *Suggested next moves* keep both paths open.
