# Companion Infrastructure

What `session-doc` depends on beyond the skill directory itself. The skill works standalone — it
produces the narrative session document on demand. But one behavior that keeps its output safe lives
in a rule the skill cannot carry.

## Why this file exists

A skill packages as a self-contained directory and can be installed many ways — a personal config
repo, a plugin, a marketplace install. But a rule loaded passively each session integrates with the
host config and does **not** ship with the skill package — skill-only distributions can't carry
`CLAUDE.md` or `rules/*.md` content. This file is the manual half — what to set up alongside the
skill when the passively-loaded behavior matters.

This file currently documents one companion. It can grow as others surface.

## Companion rule: sensitive knowledge

**Intent:** a session doc is a narrative for a human collaborator, so it's the toolkit member most
likely to carry people and relationship knowledge — how a client actually operates, what "approved"
really means, who holds authority. When that narrative is committed to a repo you don't own, the
sensitive half has to be routed out first.

**Failure without it:** candid people-knowledge lands in a client- or third-party-controlled repo,
where it can't be retracted — `git` history persists and the tree isn't yours to rewrite. The doc
that was meant to help a collaborator becomes a liability.

**Where it lives:** a rule in your own `~/.claude/rules/` (this repo keeps it at
`rules/sensitive-knowledge.md`), `@`-imported into `CLAUDE.md`. It is the family-wide statement the
whole knowledge-worker toolkit inherits; it is not part of the skill package and does not sync with
it.

**Sample wording** (paste into your own rule file and adjust — the fuller version is
`sensitive-knowledge.md` in the toolkit):

> When producing a session doc, split the knowledge by kind, by default. Commit the system knowledge
> (how things work, why decisions were made). Route people and relationship knowledge — how to work
> with a client, what "approved" really means, who holds authority, anything credentials-adjacent —
> to a private, gitignored file. Key the split on the *kind* of knowledge, which you can read from
> what you're writing, not on who owns the repo, which you can't reliably detect. Ownership sets the
> stakes — a leak into a repo you don't own can't be retracted.

## Adopting this in a new environment

Paste the sample wording into your rule file (`~/.claude/rules/<something>.md`, or your project's
`CLAUDE.md`) and edit to taste. The skill itself ships no host config — no scripts, no hooks, no
permission allowlist.
