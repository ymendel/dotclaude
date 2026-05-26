# ADR 0003: Allowlist-Based .gitignore

**Date:** 2026-04-08
**Status:** Accepted

## Context

This ADR is a historical record written 2026-05-26 of a decision made at the
repo's first commit on 2026-04-08 (commit `b2e97b7`, "start simple, with
.gitignore"). The decision has been in force unchanged since then; this
backfill exists because the strategy is structurally load-bearing for the
whole repo and deserves an explicit record.

This `dotclaude` repo is symlinked to `~/.claude`. That directory holds
the configuration this repo exists to track, plus a much larger set of
content the repo should *not* track: runtime state Claude Code generates
as it runs, the user's own working notes and drafts, state from adjacent
tools that also live in `~/.claude/`, and whatever else lands in the
directory over time. The non-tracked content is open-ended — Claude Code
adds new state directories as features ship, other tools drop state
alongside, and the user creates working directories as needed.

The configuration side is what the repo exists to version-control: rules,
skills, agents, hooks, scripts, docs, `settings.json`, `CLAUDE.md`, and a
small set of supporting files (`README.md`, `Makefile`,
`statusline-command.sh`). This is the actual content of the repo and what
the user wants tracked, shareable, and synced across machines.

The non-tracked content currently includes Claude Code runtime state
(`sessions/`, `telemetry/`, `projects/`, `file-history/`, `cache/`,
`plans/`, `tasks/`, `paste-cache/`, `shell-snapshots/`, `usage-data/`,
`session-env/`, `backups/`, `plugins/`), adjacent tools' local state
(`.rtk/`), and user-curated working directories (`ideas/`, `notes/`).
None of it should be tracked: most is environment-specific or
machine-local, some is large, some can contain secrets (auth tokens,
OAuth state, machine-specific paths embedded in session files), and
some — the user's working notes — is intentionally personal. The repo
has no advance notice of what will appear next.

The decision was how to enforce the boundary between tracked configuration
and everything else. The choice is between an *implicit-allow,
explicit-deny* (denylist) `.gitignore` and an *implicit-deny, explicit-allow*
(allowlist) `.gitignore`. The two patterns invert which kind of failure is
silent and which is loud — and for a directory where new content appears
from multiple sources without advance notice, the difference matters.

### Options

**1. Allowlist `.gitignore` (chosen).** Start with `*` to deny everything,
then add `!/<path>` lines re-including each tracked top-level directory and
file. Append `**/__pycache__/` and `**/*.pyc` re-denies after the allowlist
to keep Python build artifacts out of allowlisted directories (a real case
that surfaces when the `session-handoff` skill's tests run).

- *Pros:* Safe by default. Whatever new content appears in the directory
  next month — Claude Code state, another tool's data, the user's own new
  working directory — is automatically untracked, no `.gitignore` update
  needed and no risk of accidental commits. Secrets that might be written
  into `~/.claude/` are never tracked regardless of where they end up.
  The `.gitignore` itself functions as an inventory of what the repo is:
  reading the ~13 allowlist entries is reading the manifest.
- *Cons:* Adding a new top-level tracked path requires a `.gitignore` update
  in the same commit — easy to forget. `git status` shows fewer untracked
  files than actually exist on disk, which can mask work-in-progress when a
  new file lands in a non-allowlisted directory. The pattern fights the
  default `git add .` mental model: stage-everything silently drops changes
  in non-allowlisted paths. The allowlist is also coarse — `!/agents/**/*`
  re-includes everything under that directory, including artifacts the
  shape wasn't meant to track, so each new artifact type that appears
  inside an allowlisted directory may need its own trailing re-deny.

**2. Standard denylist `.gitignore`.** Implicit-allow, with explicit deny
patterns for known transient directories (`cache/`, `sessions/`,
`telemetry/`, `file-history/`, &c.).

- *Pros:* Standard pattern; matches how every other repo works. Adding new
  tracked content needs no `.gitignore` change. `git status` truthfully
  reflects every untracked file on disk. Familiar to any collaborator.
- *Cons:* New non-tracked content from any source — Claude Code state
  directories, other tools, user-created working directories — defaults
  to tracked. The maintainer has to know about every transient directory
  in advance, including ones that don't exist yet. A single missed entry
  can result in shipping secrets or large machine-local state. The
  deny-pattern list accumulates over time as new content types appear,
  and there is no signal when a new directory has been silently picked
  up vs. when it has been explicitly deny-listed — the difference only
  shows up when someone notices a wrong file in a diff.

**3. No `.gitignore`, curated `git add`.** Track nothing automatically;
rely on the user explicitly `git add`-ing each file per commit.

- *Pros:* Maximum control. Nothing enters the repo without an explicit
  user action. No `.gitignore` to maintain.
- *Cons:* No enforcement — relies entirely on the user remembering not
  to `git add .`. Doesn't survive multi-file changes ergonomically.
  Doesn't catch the case where a tool or script runs `git add`
  programmatically. Tools that respect `.gitignore` (editors, search
  tools, build tools) lose that signal entirely, which means they index
  or scan runtime-state directories they shouldn't touch.

## Decision

Use an allowlist `.gitignore`: deny everything with `*`, then explicit
`!/<path>` re-includes for each tracked top-level directory and file. After
the allowlist, append `**/__pycache__/` and `**/*.pyc` re-denies to keep
Python build artifacts out of allowlisted directories that recursive globs
would otherwise pick up.

The allowlist currently covers `settings.json`, `agents/`, `skills/`,
`commands/`, `rules/`, `hooks/`, `CLAUDE.md`, `scripts/`, `docs/`,
`README.md`, `Makefile`, and `statusline-command.sh`. Adding a new
top-level tracked location requires updating `.gitignore` in the same
commit that introduces it.

The `commands/` allowlist is retained "at least temporarily" per the
in-file comment, because commands are deprecated in favor of skills but
the existing ones haven't been migrated out yet.

## Consequences

- **Positive:** New content from any source — Claude Code state
  directories, other tools dropping state in `~/.claude/`, user-created
  working directories — never accidentally enters the repo. The safety
  is structural, not vigilance-based: it does not depend on the
  maintainer having heard about the new path in advance.

- **Positive:** Secrets that Claude Code might write into `~/.claude/`
  (auth tokens, OAuth state, machine-specific paths in session files) are
  never tracked, regardless of where the tool decides to put them. The
  default is safe.

- **Positive:** The `.gitignore` doubles as an inventory of what the repo
  is. A reader who wants to know "what does dotclaude actually contain?"
  reads the ~13 allowlist entries and has the answer — no spelunking
  required.

- **Neutral:** Adding a new top-level tracked path requires a `.gitignore`
  update in the same commit. This is friction, but visible friction — the
  alternative (denylist) inverts the visibility, hiding the friction until
  a wrong file shows up in a diff.

- **Negative:** `git status` shows fewer untracked files than actually
  exist on disk. A file landing in a non-allowlisted directory is invisible
  to default git commands, which can mask work-in-progress.

- **Negative:** The pattern fights the natural `git add .` workflow.
  Anyone (or any tool) used to "stage everything" finds their changes
  silently dropped when the files are in non-allowlisted paths. There is
  no warning; the staging is just empty.

- **Negative:** The allowlist is coarse. `!/agents/**/*` re-includes
  everything under that directory, including build artifacts that the
  directory shape was not intended to track. The Python pycache re-deny
  is the workaround for one specific case; each new artifact type that
  appears inside an allowlisted directory may need its own trailing
  re-deny. The pattern does not compose perfectly.

- **Negative:** The allowlist pattern is uncommon enough that a reader
  coming to the `.gitignore` cold has to parse the `*` + `!/<path>`
  semantics to understand what's tracked, and the order of patterns
  matters (the trailing `**/__pycache__/` re-deny works because it comes
  *after* the directory re-includes that would otherwise pick up
  `__pycache__/` recursively). This is a small one-time cost for any
  new collaborator and a slightly heavier cognitive load when editing
  the `.gitignore` itself.

## References

- `.gitignore` — the allowlist itself
- [ADR 0001](0001-skill-maintenance-via-parallel-repos.md) — Skill Maintenance via Parallel Git Repos; describes the `Makefile`-managed symlink that makes `~/.claude` resolve to this repo's working tree
- [ADR 0002](0002-notes-destinations-and-routing.md) — Notes Destinations and Routing; the `notes/` destination is gitignored precisely because of this allowlist
- First commit: `b2e97b7` (2026-04-08, "start simple, with .gitignore")
