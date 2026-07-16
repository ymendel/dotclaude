# ADR 0007: Progressive Disclosure for Eagerly-Loaded Rules

**Date:** 2026-07-16
**Status:** Accepted

## Context

This `dotclaude` repo is the author's Claude Code configuration, and a large
share of it is behavioral guidance loaded passively into context every session.
The `rules/*.md` files auto-load via Claude Code's native memory-directory
discovery — the root `CLAUDE.md` has no `@import` lines; the harness discovers
the `rules/` directory on its own. As [ADR 0004](0004-rule-vs-hook-enforcement-split.md)
observed, this set grows over time: each correction or lesson tends to add
another rule or another bullet, and the growth is one-directional.

That growth has a measurable cost. In a fresh session, `/context`
reported the loaded memory files (the 19 always-loaded rule files plus
`CLAUDE.md` and the auto-memory index) at **~52.6k tokens** — the single
largest category of the session's context floor, larger than system tools
(~16.9k) and every other slice, and the biggest part the author actually
writes. The four heaviest by measured token count are `writing.md` (7.1k),
`development-workflow.md` (6.7k), `feedback.md` (6.6k), and `RTK.md` (3.7k). A
session pays that whole floor before any work begins.

Not all of that content earns its place in every session. Reading the rule
files, the loaded prose is a mix of three distinct kinds: **actionable
directives** (do X, never Y, and the failure mode that justifies the rule);
**dated incident records** ("Confirmed 2026-07-15: …", "On 2026-XX-XX I did Y")
that document *what happened* rather than *what to do*; and **consult-on-demand
reference material** (command tables, extended worked examples, edge-case
catalogs) that a reader pulls up when a specific situation arises but doesn't
need resident the rest of the time. Only the first kind needs to be in context
at all times. The other two load every session but are consulted only when a
specific situation calls for them — dated incidents rarely or never, reference
material on a recognizable trigger.

The config already demonstrates that a rule file need not be always-loaded.
Three mechanisms exist in the repo today, discovered while scoping this
decision:

- **`claudeMdExcludes`** (in `settings.json`) hard-excludes a file from
  loading. It currently lists `README.md` and `rtk-commands.md`. The latter is
  the working precedent for a *consult-on-demand reference*: `RTK.md` ends with
  "Full command reference: `rules/rtk-commands.md` (excluded from context)."
- **`paths:` frontmatter** conditionally loads a file only when the session's
  working paths match its globs. `settings.md` (19.6 KB by bytes — the largest
  rule file on disk) carries `paths: ["**/settings.json", "**/settings.local.json"]`
  and so does *not* load in a general session; `code-style-ruby.md` carries
  Ruby globs (`**/*.rb`, `**/Gemfile`, &c.) and loads only in Ruby contexts.
  This is already a working progressive-disclosure mechanism — it is why
  `settings.md`, despite being the biggest file, does not appear in the loaded
  set.
- **Git history** already holds the removed-content case: because this is a git
  repo, every rule file's history is durable and searchable, and the author's
  standing call is that dated observations belong in the commit that introduces
  or changes a rule, not in the always-loaded prose.

So the raw materials for progressive disclosure are all present and proven;
what is missing is a *policy* — a single answer to "when a new piece of rule
content is added, where does it go?" Without one, the path of least resistance
is always to append to an always-loaded file (it is one Edit), so every kind of
content drifts into the always-loaded set by inertia, exactly the way [ADR 0004](0004-rule-vs-hook-enforcement-split.md)
described mechanical constraints drifting into prose. The result is a context
floor that only grows.

This is the sibling problem to [ADR 0004](0004-rule-vs-hook-enforcement-split.md).
That ADR asked *where behavioral
guidance is enforced* (prose vs. gate); this one asks *whether a given piece of
guidance needs to be resident to be enforced at all*. The realization is
parallel: not every rule needs to be in context at every moment, any more than
every constraint needs to run on the model's attention.

### Options

**1. A four-destination routing policy, classified by content kind (chosen).**
Every piece of rule content is routed to one of four destinations by what kind
of content it is:

1. **Actionable directive + the failure-mode it prevents** → stays
   always-loaded. This is the rule proper.
2. **Context-specific directive** (guidance that only applies while working in
   a recognizable file context) → path-scoped via `paths:` frontmatter.
3. **Dated incident / verification record** ("Confirmed on DATE", "On DATE I
   observed…") → git history, in the commit body that introduces or changes the
   rule.
4. **Consult-on-demand reference material** (command tables, extended worked
   examples, edge-case catalogs) → an excluded reference file, pointed at from
   the loaded rule.

- *Pros:* Lowers the always-loaded floor without losing anything — the content
  moves, it isn't deleted. Each content kind gets a clear home, so a new
  addition no longer defaults to always-loaded by inertia. Two of the four
  destinations already have working precedents in the repo (`settings.md` /
  `code-style-ruby.md` for path-scoping; `rtk-commands.md` for the reference
  file), so the policy formalizes proven mechanisms rather than inventing new
  ones. The convention scales with the rule set's one-directional growth.
- *Cons:* The routing is a judgment call per content item, not a mechanical
  test — deciding whether a "Why: On DATE…" aside is load-bearing rationale or
  disposable history requires reading it. Moved content is less discoverable
  than always-loaded prose (see Consequences). Adds convention surface a future
  reader must learn.

**2. Keep everything always-loaded (the inertial status quo).** Every rule
file loads every session; the floor grows as the rule set grows.

- *Pros:* One uniform place to look; every rule is found by reading `rules/`.
  Adding content is always one Edit. No convention to learn.
- *Cons:* This is the status quo whose cost prompted the ADR — a context floor
  that only climbs, dominated by content (incident history, reference tables)
  that is consulted rarely or never.

**Rejected:** it leaves a free reduction on the table and gets worse
monotonically as rules accrete.

**3. A separate evolution-log for historical content.** Move dated incidents
and verification records into a dedicated log file (or files) rather than into
git history.

- *Pros:* Keeps the "here's what we saw" narrative in one browsable place
  rather than scattered across commit messages.
- *Cons:* Duplicates what git history already is. The author has rejected a
  separate evolution-log twice; the standing framing is "git *is* the log."
  A separate log is another always-loaded (or at least maintained) artifact
  that itself accretes.

**Rejected:** git history already provides durable, searchable, per-change
provenance; a parallel log is redundant maintenance.

### Reference-file mechanism (sub-decision)

Destination 4 (consult-on-demand reference) needs a concrete exclusion
mechanism. This sits on a distinct axis from the routing policy above — it is
*how* the reference-file destination is implemented, not *which* content routes
there.

**A. Per-file `claudeMdExcludes` entries (the current approach).** Each
reference file is listed by name in `settings.json`, as `rtk-commands.md` is
today.

- *Pros:* Already in use and understood. Explicit — the exclude list doubles as
  an inventory of what's excluded. Fine-grained: each file is an independent
  decision.
- *Cons:* Every new reference file requires a `settings.json` edit in addition
  to creating the file. The exclusion lives far from the file it governs, so
  the connection is non-obvious. The list grows one entry per reference file.

**Rejected:** the per-file settings edit and the split between a file and its
distant exclusion entry cost more than the per-file granularity is worth.

**B. A conventional `rules/references/` subdirectory, excluded by one glob
(chosen).** Add a single `**/rules/references/**` entry to `claudeMdExcludes`;
any file placed in `rules/references/` is automatically not-loaded.
`rtk-commands.md` moves there; `README.md` stays excluded by name.

- *Pros:* One convention to learn ("anything in `rules/references/` isn't
  loaded"), one exclude pattern regardless of how many reference files exist.
  A file's location declares its status — no split between the file and a
  distant settings entry. New reference files need no `settings.json` edit, and
  because `!/rules/**/*` already re-includes everything under `rules/`
  recursively ([ADR 0003](0003-allowlist-gitignore.md)), a `references/` subdir
  is tracked with no `.gitignore` change either. The exclude glob
  `**/rules/references/**` is likewise recursive, so `references/` can be
  subdivided per-rule (`references/rtk/…`) at zero config cost — nesting a
  per-file exclude list cannot absorb without an entry each.
- *Cons:* Coarser — the glob can't selectively load one reference file while
  excluding its neighbors, though selective loading is not a current need.

## Decision

Adopt a routing policy for rule content with four destinations, chosen by the
kind of content:

1. **Actionable directive + the failure-mode it prevents** stays
   always-loaded. This is the rule, and the failure-mode line is part of it —
   per the rules-writing convention, the failure mode justifies the rule and
   belongs in prose.
2. **Context-specific directive** — guidance that applies only while working in
   a recognizable file context — is path-scoped via `paths:` frontmatter, the
   mechanism `settings.md` and `code-style-ruby.md` already use.
3. **Dated incident and verification records** go to git history, in the commit
   body that introduces or changes the rule. This formalizes the author's
   standing call; it is not a new artifact.
4. **Consult-on-demand reference material** goes to an excluded reference file
   under a new `rules/references/` subdirectory, excluded by a single
   `**/rules/references/**` glob in `claudeMdExcludes`. Each rule's reference
   material lives in a subdirectory named for the rule it serves — even when
   that holds a single file — so `RTK.md`'s command reference moves from
   `rtk-commands.md` to `rules/references/rtk/commands.md`. Every subdirectory
   maps to one rule, which keeps the directory legible as it grows.

Three guards constrain destinations 3 and 4:

- **Delete-by-default.** Because git history preserves everything removed,
  trimming loses nothing recoverable. A reference file is *only* for content a
  reader would actively pull up ("I'd go look this up"), not content that is
  merely hard to throw away. Absent that active-consultation test, content that
  would otherwise become a reference file should simply be deleted — the
  reference subdirectory must not become an unmaintained junk drawer of
  content no one loads. The test is *triggered* consultation, not *rare*
  consultation. The extracted voice markers (`references/writing/voice.md`) are
  pulled up nearly every session that drafts under the user's byline, yet still
  belong in a reference because they load only on a recognizable trigger and are
  bulky. Frequency does not disqualify content from a reference file — the absence
  of a recognizable load trigger does.
- **Triggered pointers.** A loaded rule that points at a reference file must say
  *when* to load it, not merely "see `rtk-commands.md`". An untriggered pointer leaves
  the excluded file effectively dead — nothing tells the model the situation in
  which pulling it up is worthwhile. This is the same discoverability gap
  already flagged for skill reference lists.
- **Lean reference files.** A reference file carries content, not provenance. The
  record of *why* it was extracted — the ADR reference, the "destination 4" label —
  belongs in the commit that creates the file (destination 3 applied to the
  extraction itself), not in a header inside the file. A provenance header would
  load every time the file is consulted, duplicating git history into context for a
  reader who arrived via a pointer that already carried the context. Keep the file's
  own header to a one-line "not loaded by default. See `<rule>.md`" note, matching
  the `references/rtk/commands.md` precedent.

The trimming pass that applies this policy is **not mechanical**. The nuance to
preserve: keep the actionable "Failure mode this prevents" lines in always-loaded
prose (they justify their rules); move only the dated incident detail to
history. Many `feedback.md` entries interleave a "**Why:** On <date>…" incident
with a "**How to apply**" directive — deciding how aggressively to move the
dated `Why` incidents into history versus keeping a compressed rationale in
prose is a judgment call for the author to drive during the pass, per entry, not
a bulk strip.

The four destinations compose; they are not mutually exclusive per file. A
single rule file can route different parts of itself to different destinations —
a path-scoped directive in its frontmatter-loaded body, its dated incidents to
history, and its heavy consult-on-demand tables to a reference file.
`settings.md` is the case that makes this concrete. It is already path-scoped
(the precedent for destination 2), but its `paths:` glob matches `settings.json`
— a file inspected often enough that path-scoping alone buys little; in practice
`settings.md` is close to always-loaded. So its bulky consult-on-demand content
(the extended pattern-matching tables and edge-case catalogs) is still a
candidate for destination 4, extracted to a reference file even though the file
itself stays path-scoped.

The initial always-loaded targets are the genuine heavies that load every
session: `writing.md`, `development-workflow.md`, and `feedback.md`. `settings.md`
is a secondary, compositional target per the paragraph above — not because it
loads every session (it doesn't), but because its path is hit often enough that
its reference-extractable bulk still matters. Lean rule files (`naming.md`,
`self-improvement.md`) have nothing to split and are left alone. The
loaded-token floor should be measured before and after the pass via `/context`,
so the reduction is a measurement rather than an estimate.

This policy moved from Proposed to **Accepted** once the trimming pass validated
it: the classification held against real content in `feedback.md`, `writing.md`,
and `development-workflow.md`; the moved content was not missed in a normal
session; and the measured memory floor dropped from ~52.6k to ~48.1k tokens
(both figures from `/context` in a fresh session, so a small part of the delta
may be incidental auto-memory-index drift — but the magnitude matches the
byte-ratio estimate). "The convention reads well" was not the bar — exercising it
and re-measuring was.

## Consequences

- **Positive:** The always-loaded context floor drops by moving
  triggered-consultation content (incident history, reference tables, voice
  markers) out of every session, and the convention keeps it from climbing as
  the rule set grows one-directionally. The first pass — trimming `feedback.md`
  and extracting reference material from `writing.md` and
  `development-workflow.md` — lowered the measured memory floor from ~52.6k to
  ~48.1k tokens (a ~4.5k drop, ~8.6%), matching the byte-ratio estimate. The
  reduction is real but modest, so the near-term value is as much the
  *convention against future drift* as the immediate cut.

- **Positive:** Each kind of rule content gets a clear home, so a new addition
  is routed by what it is rather than defaulting to always-loaded because
  appending is the easy Edit. This is the direct analogue of [ADR 0004](0004-rule-vs-hook-enforcement-split.md)'s
  "each new constraint has a clear home" benefit.

- **Positive:** No new artifact type is introduced for history. Git history —
  durable and searchable because this is a git repo — absorbs the incident
  records, so there is no separate evolution-log to maintain.

- **Neutral:** Two of the four destinations already exist and are proven in the
  repo (`paths:` frontmatter, the `rtk-commands.md` exclude). The policy mostly
  formalizes and names existing practice rather than building new mechanism; the
  new construction is the `rules/references/` subdirectory and its single
  exclude glob.

- **Neutral:** The routing is a judgment call, not a mechanical test — unlike
  [ADR 0004](0004-rule-vs-hook-enforcement-split.md)'s checkability test, no
  script decides where content goes. Applying
  the policy requires reading each piece of content and classifying it, and the
  trimming pass is author-driven per entry.

- **Negative:** Moved content is less discoverable than always-loaded prose. A
  reference file is found only if a triggered pointer sends the reader to it;
  an incident record in git history is found only by someone who runs `git log`/
  `git blame` on the rule. The triggered-pointer guard mitigates the reference
  case but adds a maintenance burden — the "when to load this" cue has to stay
  accurate as the reference file evolves, or the pointer rots.

- **Negative:** Path-scoping can under-fire. A rule scoped to `**/settings.json`
  does not load when its guidance is relevant but no settings file is in the
  working set (e.g. reasoning about a settings change without having opened the
  file yet). Destination 2 trades always-available for loads-when-the-path-matches,
  and the match is on file paths, not on topic — so genuinely cross-cutting
  guidance is a poor fit for path-scoping and should stay always-loaded.

- **Negative:** The `rules/references/` glob is coarse — it cannot selectively
  load one reference file while excluding its neighbors. This is acceptable only
  as long as selective loading isn't needed; if it ever is, the per-file
  `claudeMdExcludes` approach (Option A) would have to come back for that file.

- **Negative:** The convention is one more thing a reader — or a future
  maintainer of this config — must learn. "Why isn't this rule loading?" now has
  three possible answers (`claudeMdExcludes`, `paths:` frontmatter, or the
  `references/` subdir) instead of "all rules load." The mitigation is two
  tracked, traveling artifacts: this ADR records *why* the mechanisms exist, and
  a short "How rules load" note in the always-loaded `rule-maintenance.md` states
  *what* they are, so the mechanism is visible in every session rather than
  re-derived each time. (A per-machine memory note was tried and rejected — it
  neither travels with the repo nor reliably surfaces.)

## References

- [ADR 0004](0004-rule-vs-hook-enforcement-split.md) — Rule vs. Hook
  Enforcement Split; the closest sibling. That ADR asks *where* behavioral
  guidance is enforced (prose vs. gate); this one asks *whether* a given piece
  needs to be resident to be enforced. Both respond to the same
  one-directional growth of the rule set.
- [ADR 0003](0003-allowlist-gitignore.md) — Allowlist-Based `.gitignore`; its
  recursive `!/rules/**/*` re-include is why the `rules/references/`
  subdirectory is tracked with no new allowlist entry.
- `settings.json` — the `claudeMdExcludes` key; the exclusion mechanism this
  decision builds on.
- `rules/rtk-commands.md` — the existing excluded-reference precedent, pointed
  at from `rules/RTK.md`; the first file to move into `rules/references/`.
- `rules/settings.md`, `rules/code-style-ruby.md` — the existing `paths:`
  frontmatter precedents for destination 2.
- `rules/rule-maintenance.md` — where the git-history-not-prose convention for
  dated observations is expected to be recorded as a maintenance clause.
