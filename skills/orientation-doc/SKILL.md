---
name: orientation-doc
description: "Write an orientation doc — the 'read this first' map that helps someone arriving cold at a system navigate it without stepping on landmines. Use when onboarding a maintainer to an unfamiliar codebase, handing a system off, or capturing a system's entry map, soft spots, and the knowledge that isn't in the repo for a successor. Not for a usage or contributor README, and not for resuming an in-flight work session."
---

# Orientation Doc

The "read this first" map for someone who has to work *inside* a system they didn't build — a new
maintainer, a successor on a handoff, future-you after months away. A README tells that reader how to
*use or build* the thing. An orientation doc tells them what they need to know to *navigate* it
without getting hurt, and where everything else lives.

It is a map, not a manual. It points at the READMEs, ADRs, and code rather than restating them, and
spends its words on the tacit knowledge that has no other home: the terms that bite, the concepts
that drifted, the soft spots, the knowledge that isn't in the repo at all.

## The shape

Lead with the risk — everything after it is the map. Not every section fits every system. Drop any
with no real content rather than fill it — a manufactured *concept that moved* reads as real and
misleads, which is worse than an omitted section. The template, heading by heading:

```markdown
# Orientation: <system>

## If you read nothing else
The one load-bearing unknown or trap — the thing that, if missed, stalls or burns whoever
inherits this. From a knowledge-grill, this is the gap-as-risk. If there is no single dominant
one, list the two or three that come closest. Putting it first means the inheritor sees it
before anything else.

## What this is
One paragraph: what the system does, who it serves, its shape in a sentence or two. Enough to
orient, not a tutorial.

## Terms that bite
The project's landmine vocabulary. For each entry: the term → what it means *here* → why a
newcomer would read it wrong. Pay special attention to words that collide with a general term of
art (a plain word used for a project-specific thing, or a methodology term that drags in a model
the project doesn't mean).

## Concepts that moved
Where a name or model drifted from what it once meant. The current term, what the code or history
still calls it in places, and which is authoritative now. These are the splits that hide a real
conceptual mismatch behind a naming one — the most expensive kind to discover the hard way.

## Soft spots
The fragile and load-bearing areas: "don't touch X because Y", the workaround that looks wrong but
is deliberate, the assumption nothing enforces. Give each its *why* — a soft spot without its
reason just reads as a dare.

## Where the rest lives
The map outward: the README for setup, the ADRs for decisions and their why, recent handoffs for
in-flight work, the entry-point files a newcomer should open first. Point, don't duplicate. Link each
entry's pointer, not every sub-reference it names — those are reachable from the parent link. Make a
pointer a link when it names an in-repo file or directory (`[`README.md`](README.md)`), entry-point
files included, and leave conceptual pointers (`git log`, `:help plug`) as prose. When a class of
decision has no ADR home, say where its *why* lives instead (usually `git log`); that absence is
navigation information, not an omission.

## What's not in this repo
The knowledge the code can't hold — the people and relationships, the external systems, the things
that live in someone's head. When the repo may be client- or third-party-owned, the sensitive half
of this goes to a private artifact, not the committed doc (see Producing one, last bullet).
```

## Producing one

- **Explore before you ask.** Most of *What this is* and *Where the rest lives*, and many of the
  landmine terms, come straight from the code, the commit history, and the existing docs. Read those
  first. Spend any interview only on what they cannot tell you — the *why* behind a soft spot, the
  history behind a moved concept, the off-repo knowledge. This is the same explore-first discipline
  as `knowledge-grill`. When a grill is running, this doc is its entry-map output, and the grill has
  already gathered most of the tacit half.
- **Find landmines by their signals.** Terms that collide with a general meaning, names that appear
  in two forms across the code, comments that say "don't" or "HACK", workarounds with no obvious
  cause — each is a candidate for *Terms that bite*, *Concepts that moved*, or *Soft spots*.
- **Interview for the tacit half.** Soft-spot reasons, drifted-concept history, and off-repo
  knowledge usually aren't written anywhere. When this skill runs standalone (no grill), ask the
  holder one question at a time, offering your best guess rather than asking cold — a concrete claim
  they can correct pulls a better answer than an open question.
- **Keep it a map.** The discipline that keeps an orientation doc useful is restraint: it points
  outward and stays short. The moment it starts restating the README or inlining an ADR's reasoning,
  it stops being a fast read, and a reader who learns it can't be skimmed stops trusting it to be the
  first thing they read.
- **Code-format identifiers everywhere, not just in some sections.** File and path names, commands,
  flags, env vars, and binary or tool names are literal identifiers — render them in code font
  consistently across the whole doc. The tell that you've drifted is a bare name sitting next to a
  formatted one (a plain `fzf` beside `rg` and `proximity-sort`). A product name used descriptively
  stays prose (Homebrew, Postgres); the executable you'd type is code (`brew`, `psql`).
- **Split sensitive knowledge out of a repo you don't own.** *What's not in this repo* often holds
  people- and relationship-knowledge. When the repo may be client- or third-party-owned, commit the
  orientation doc but route that sensitive half to a private, gitignored artifact — the same split
  `knowledge-grill` applies to interview output.

## Where it goes

Default to `docs/ORIENTATION.md` (or a repo-root `ORIENTATION.md` for a small project). One per
system. A monorepo with genuinely separate systems can carry one per subtree, each scoped to its own.

## Deferred ideas

For per-project-type variants, a proactive firing rule, and this doc's slot in the wider record-artifact
toolkit, see [TODO.md](./TODO.md).
