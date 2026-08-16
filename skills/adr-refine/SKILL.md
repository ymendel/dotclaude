---
name: adr-refine
description: "Critique a draft Architecture Decision Record: surface unclear context, missing tradeoffs, and codebase inconsistencies. Auto-invoked by the adr skill; also use when the user says \"review this ADR\", \"refine this ADR\", \"is this ADR good enough to commit?\", or \"re-refine after implementation\"."
allowed-tools: Read, Grep, Glob, Edit
metadata:
  publish: marketplace
---

# ADR Refiner

An ADR draft is not done when it's written — it's done when it survives a critique pass. This skill runs that pass. Its job is to make a future reader's life easier by catching the problems the author couldn't see while drafting.

This skill is the refinement half of the ADR workflow. The `adr` skill writes the draft; this skill interrogates it. Implementation work should not begin until both have run and the user has accepted the refined ADR.

## When this skill runs

- **Automatically after `adr`.** The `adr` skill's final step invokes this one on the file it just wrote. No user action required.
- **On explicit request.** "Review this ADR", "refine ADR NNNN", "is this ADR good enough to commit?", or any pointer to an existing ADR file paired with a request for critique.
- **Not for Accepted ADRs' original sections.** If the status line says `Accepted`, don't refine the original sections — propose a superseding ADR instead. The historical record matters, and `Accepted` ADRs are immutable except for the status, reference, and Amendment updates documented in the `adr` skill.
- **Amendment blocks on Accepted ADRs may be refined.** A newly appended `## Amendment — YYYY-MM-DD (ADR NNNN)` section is itself a written artifact. Scope the critique to the Amendment block only (clarity, accuracy of what shifted, completeness of the implementing-issue pointer); leave the original Accepted sections alone.
- **Backfill ADRs marked Accepted at creation are refinable until first commit.** When an ADR is drafted today with status `Accepted` because the *decision* it documents is historical (not because the *document* is), the immutability rule doesn't yet apply — the document hasn't entered the historical record yet. Refine in place until the ADR is committed for the first time; after that, the standard rule takes over and further changes route through supersede or amendment.
- **Re-refining a Proposed ADR is fine.** If implementation surfaced gaps or contradictions that fed back into a Proposed ADR, running this skill again on the updated draft is expected, not redundant.

## What to do

1. **Read the ADR file in full.** Don't skim. Note the title, status, date, and every section.
2. **Read the surrounding codebase where the ADR makes claims.** If the ADR says "we currently use X" or "the existing Y pattern", verify it. Use Grep and Read. An ADR that misdescribes the current state is worse than no ADR.
3. **Read 1-2 topically related ADRs** if any exist — neighboring by subject, not just by number. Use Grep to find ADRs that mention the same component, system, or decision area. Check for contradictions, supersession gaps, or unlinked prior decisions that should be referenced.
4. **Produce structured review notes** (format below) and print them to the chat. Do not edit the file yet.
5. **Wait for the user's responses** to the questions and proposed edits. Do not apply anything until they answer.
6. **Apply accepted edits** once the user has responded. Skip or revise the ones they rejected or modified. Before running another pass, check *When to stop refining* below.

## Review notes format

Print review notes in this exact structure. Omit a section only if it has genuinely nothing to flag — prefer saying "nothing flagged here" over silently dropping a heading, so the user knows you looked.

```markdown
## Review notes for ADR NNNN: {title}

### Unclear context
- {thing a future reader with only the code + ADR won't understand, and why}

### Missing tradeoffs
- {alternative not considered, or consequence not named, with a pointer to what's missing}

### Unlabeled consequences
- {file:line} `- Rollback is straightforward.` → `- **Positive:** Rollback is straightforward.`
- {file:line} `- **Positive:** Simpler to operate, but slower at p99.` → split: `- **Positive:** Simpler to operate.` and `- **Negative:** p99 latency regresses by ~Xms.`

### Unmarked options
- {file:line} option with no `(chosen)` marker on the winner, or no **`Rejected:`** line on a loser → which marker it needs, and (for a rejected option) the reason to put on the line, drawn from its own cons

### Duplicate options
- {file:line} two options that land the system in the same place and differ only in motivation → which one absorbs the other, and the pros to fold into the merged option

### Two axes in one list
- {file:line} options answering two questions that don't constrain each other → the two `### Options considered: {axis}` headings to split them under, and which options go under each

### Hand-wavy language
- {quoted phrase} → {why it's vague and what concrete version would look like}

### Codebase inconsistencies
- {claim in the ADR} vs {what the code actually shows, with file:line reference}

### House-style divergences
- {draft's formatting or voice} vs {the neighboring ADR's, with its path} → {the fix}

### Questions for you
1. {direct question about an ambiguity — do not guess}
2. ...

### Suggested edits
{cross-cutting rewrites that don't belong to a single category above — e.g., a reframing of the Context section, or a consolidation that affects multiple bullets. Single-category fixes belong inline with their category bullet, not here.}

### Overall
{one or two sentences: is this close to commit-ready, or does it need a structural rework? Be direct.}
```

## What to look for

**Unclear context.** Will a reader five years from now, who has only the code and this ADR, understand *why a decision had to be made at all*? Context that describes the world as it will be ("we use Rails 8") rather than the world as it was ("at the time, we were choosing a framework") ages badly.

**Missing tradeoffs.** A decision with no negative consequences is suspicious. So is a decision that names only one alternative. Push on: what did we *not* pick, and why? What does this make harder or impossible?

**Unlabeled consequences.** Every bullet under `## Consequences` must begin with **`Positive:`**, **`Neutral:`**, or **`Negative:`** (bold prefix, colon, then the body). Flag any bullet that doesn't — report it with file:line and a suggested rewrite that picks the right label. If a bullet mixes polarities ("simpler to operate, but slower at p99"), the rewrite splits it into two bullets, one per valence. Topical-only labels like "Rollback", "Privacy", or "Cost" hide whether the consequence is good news or bad news; rewrite them into the valence-first form with the topic named in the body.

**Unmarked options.** In an `### Options` subsection, the chosen option must carry `(chosen)` after its name and every other option must carry a **`Rejected:`** line naming why it lost. Flag any option missing its marker — report it with file:line and, for a rejected option, the reason the line should give (drawn from that option's own cons). An options list where nothing is marked chosen, or where the rejected options don't say why, forces the reader to re-derive the outcome the author already knew.

**Duplicate options.** Flag an options list only when two of its options are near-duplicates of the same choice — not for its length alone. Three is the normal ceiling and it is soft: a 4th or 5th is fine where it is a genuinely distinct answer to the *same* question, and wrong where it restates an option already listed or varies one in a way that belongs in that option's cons. The sharpest tell: two options that produce the **same technical end state** and differ only in **motivation** (one framed as a deliberate choice, the other as do-nothing inertia) are one option, not two — their differing justifications are two pros of the same option. Test each option against the others by end state, not by the story told about it; if two land the system in the same place, flag them to be merged, with each rationale folded into the merged option's pros. This is easy to miss precisely because the two read as distinct — a motivation-only distinction has the shape of a real alternative, so check for it deliberately rather than trusting that distinct-sounding options are distinct.

**Two axes in one list.** The mirror of the check above: that one flags a list with too many members, this one a list answering too many questions. Where the options answer two questions that do not constrain each other — how a thing is distributed, and how far its first version goes — the fix is to split the list rather than trim it, giving each axis its own `### Options considered: <axis>` heading and its own lettering from A. Two tells, either one enough: a `(chosen)` marker appearing twice in one list, or an option a reader could adopt *alongside* another rather than instead of it. Options on one axis are mutually exclusive, so if two could both be taken they were never alternatives to each other.

**Hand-wavy language.** Flag hedging ("we might", "consider", "probably"), vague decisions ("use a background job system" without naming the library), and non-consequences ("more complex", "some risk"). Quote the phrase and suggest a concrete replacement.

**Codebase inconsistencies.** This is the highest-value check and the one most likely to be skipped. If the ADR says "the existing auth middleware does X", actually read the middleware. If it says "there are no background jobs today", actually grep for `ActiveJob` and `perform_later`. An ADR built on a wrong premise is worse than no ADR.

**Questions you shouldn't paper over.** If something is ambiguous, ask. Do not guess and do not fabricate context. A short list of direct questions is more valuable than a long draft that hides its assumptions.

**Link hygiene.** If this ADR supersedes or builds on a prior one, is it linked? If another ADR in the repo covers overlapping ground, flag the overlap.

**House-style divergences.** The presence checks above (labeled consequences, marked options) verify *that* the markers exist — this verifies the draft's *formatting* matches neighboring ADRs. Actually open one existing ADR in the same directory and compare: are Pros/Cons rendered as bulleted lists or crammed into a prose line? Are options headed `**Option A: … (chosen).**` or `#### Option 1`? Lettered or numbered? A draft that carries every required marker but formats them differently from its neighbors still reads as foreign. Match the neighbor, or flag the divergence. When the existing ADRs **disagree** — a house-style migration underway — match the most recent, not the majority, and flag a draft that reverts to the older form. When there is **no** neighbor — this is the first ADR in the repo — there is no house style to match yet, so the draft *sets* it: check that Pros/Cons are bulleted lists with the `**Rejected:**` line after them (the default the `adr` skill prescribes), and flag prose-line pros/cons for conversion rather than letting the first ADR bake in the cramped form. Sweep the prose voice too — punctuation and phrasing the author avoids in durable byline output (an ADR is byline output). Do this against a neighbor actually read this pass, not from memory of the house style.

## Applying edits after the user responds

- Only apply edits the user accepted. If they revised your suggestion, use their version.
- Preserve the repo's existing ADR house style (heading levels, date format, status vocabulary) — don't let your edits drift from neighboring ADRs.
- Do not silently change the status line. Status changes are a decision the user makes.
- After applying, report back with a brief summary: what changed, what was left open, and whether any of the questions are still unanswered.

### When to stop refining

Refinement converges when the remaining items are *polish* — wording, link hygiene, formatting consistency — rather than *substance* (missing tradeoff, unverified claim, wrong premise, ambiguous decision). At that point the ADR is done refining; say so and stop, even if minor improvements are still imaginable.

If substantive issues — wrong framing, wrong scope, wrong decision, unverified premises — are still surfacing *after* the user has already revised the ADR in response to a prior round of refinement, the problem is structural, not refinable. Stop running passes and flag it as needing a rethink — see the "Infinite refinement" anti-pattern.

## Anti-patterns to avoid

- **Rubber-stamping.** If the review notes are all "looks good", you didn't look hard enough. There is almost always a missing tradeoff or an unverified claim.
- **Rewriting the ADR unprompted.** The user drafted it (possibly via the `adr` skill) for a reason. Critique and propose — don't overwrite.
- **Fabricating codebase claims.** If you didn't actually read the file, don't say "the existing X does Y". Say "I didn't verify this — can you confirm?"
- **Burying the lede.** If the ADR has a structural problem (wrong decision, wrong framing, wrong scope), say so in **Overall** first. Don't hide it under line-level nitpicks.
- **Infinite refinement.** Multiple rounds are normal — substantive ADRs typically take a few passes to converge, and re-refinement after implementation surfaces new information is expected. What's *not* normal is structural questions (wrong framing, wrong scope, wrong decision) still surfacing after the user has already revised in response to a prior round: that's a signal the ADR needs a rethink, not another polish pass. Say so plainly when you see it. See *When to stop refining* above.

## Attribution

Adapted from Flagrant's `adr-refine` skill (MIT). Full notice: [ATTRIBUTION.md](./ATTRIBUTION.md).
