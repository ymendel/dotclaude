# ADR 0005: Separate Repository for Private Skills

**Date:** 2026-07-11
**Status:** Accepted — amended 2026-07-13 and 2026-07-21 (see Amendments below)

## Context

This repo is the author's public Claude Code configuration, symlinked to
`~/.claude` (ADR 0001, ADR 0003). Its tracked tree is public on GitHub. The
allowlist `.gitignore` (ADR 0003) means only explicitly re-included paths are
tracked, but everything that *is* tracked — and its whole history — is
world-visible.

That is the right default for configuration meant to be shared and for skills
judged stable enough to publish. It leaves a gap: a skill under active
development, or one that may never be appropriate to publish at all, has
nowhere to live except the public tree. Working on such a skill in `skills/`
means either committing it publicly before it is ready, or leaving it
uncommitted — no history, no backup, no cross-machine sync. Distribution of
*ready* skills is already handled by the parallel team repo (ADR 0001); this
decision is about the opposite end of the lifecycle — incubating skills that
are not ready to be seen.

Three facts about how Claude Code loads skills shape the options, verified
against the skills documentation when this ADR was written:

- Skills load automatically from `.claude/skills/` in the user config
  directory, in the project, and in any directory added with `--add-dir`.
- `permissions.additionalDirectories` in `settings.json` grants file access
  only — it explicitly does *not* load skills.
- Skill discovery within any one `skills/` root is flat: `skills/<name>/SKILL.md`.
  A subdirectory such as `skills/private/` is read as a skill *named* `private`,
  not as a namespace holding more skills.

### Options

**1. Separate private repository, loaded via `--add-dir` (chosen).** Keep
in-development and private skills in their own git repo, cloned *outside*
`~/.claude`, with the `.claude/skills/<name>/SKILL.md` substructure that
`--add-dir` looks for. Start Claude with that directory added; the private
skills then load alongside the public ones for that session only.

- *Pros:* Hard separation — private skills are physically in a different repo
  with its own history and backup, and cannot leak into the public repo via a
  stray `git add` or an allowlist tweak. Loading is opt-in per session. The
  private repo carries the same skill-directory shape as this one, so promoting
  a skill to public is a copy, not a rewrite.
- *Cons:* Requires the `.claude/skills/` nesting inside the added directory
  (documented and fixed, if not loved). Loading is manual — a session started
  without adding the directory does not see the private skills. The `--add-dir`
  path auto-loads skills only; agents and commands do not come along it, and
  CLAUDE.md only with an extra environment variable.

**2. Keep private skills in this tree, gitignored per skill.** Leave the skill
at `skills/<name>/` and add a re-deny line to the allowlist `.gitignore` so it
is not tracked.

- *Pros:* No second repo and no launcher; the skill loads normally because it
  already sits in `~/.claude/skills/`.
- *Cons:* The private skill sits one `git add` away from the public repo. The
  allowlist's whole purpose (ADR 0003) is safety-by-default; a per-skill
  re-deny is exactly the hand-maintained exception it exists to avoid. The
  skill also gets no independent history or backup, and the re-deny line names
  the private skill inside the tracked `.gitignore`, partially advertising what
  was meant to be hidden.
- **Rejected:** puts private content in the public tree and leans on a
  hand-maintained exception to keep it out — the failure mode is silent and
  public.

**3. Point `permissions.additionalDirectories` at an external directory.** Use
the settings field instead of the `--add-dir` flag.

- *Pros:* Persists across sessions without a launcher flag.
- *Cons:* Grants file access only. The skills documentation is explicit that
  this setting does *not* load skills, so it cannot do the one thing required.
- **Rejected:** does not load skills at all; it is not a substitute for
  `--add-dir`.

**4. Symlink a subdirectory of this repo's `skills/` to an external directory**
— e.g. `skills/private -> <private-root>/skills`.

- *Pros:* Would keep the private source external while surfacing it through the
  normal user skills directory.
- *Cons:* Skill discovery inside a `skills/` root is flat, so `skills/private/`
  is read as a skill named `private` with no top-level `SKILL.md`; the skills
  nested under it are never found.
- **Rejected:** flat skill discovery means a symlinked subdirectory does not
  work for skills. This is precisely why `--add-dir` — which looks for a
  `.claude/skills/` under the added root — is the mechanism for skills.

**5. Private skills on a local-only, never-pushed branch of this repo.** Keep
the private skills on a git branch that is never pushed to the public remote.
Options 2–4 hide private content at the filesystem level (gitignore, settings,
symlink); this one hides it at the git level.

- *Pros:* No second repo and no launcher. Checking the branch out loads public
  and private skills together, because the tree is still `~/.claude`.
- *Cons:* The only thing keeping the skills private is not having pushed the
  branch yet — a single `git push` (or a `git push --all`) publishes them, from
  the same object store the public branch lives in. The private work is also
  entangled with public history: keeping the branch usable means continuously
  merging or rebasing `main` into it, and any promotion or public commit has to
  be untangled from the private commits by hand.
- **Rejected:** hides private work behind an unpushed branch in the same repo,
  so one push publishes it and the branch must be continuously reconciled with
  `main` to stay current. There is no separation of substance — only of what has
  been pushed so far.

## Decision

Maintain in-development and private skills in a separate git repository, cloned
outside `~/.claude`, structured as `<private-root>/.claude/skills/<name>/SKILL.md`,
and load them by adding that directory with `--add-dir`. The public dotclaude
repo remains the home for shared and published configuration; the private repo
is the incubator for skills that are not ready — or may never be — public.
Promotion to public is a copy into `skills/` here plus a commit; retirement is
deletion from the private repo. Either way there is no trace in public history.

The ergonomics of the `--add-dir` invocation — a shell alias or function and
how it is installed — are deliberately left as an implementation detail. This
decision is about *where private skills live and how they load*, not about the
launcher.

### Forward-looking: not only skills

`--add-dir` auto-loads skills but not rules, agents, or commands. That does not
confine the private repo to skills, because this repo *is* `~/.claude` (the
ADR 0001 symlink). A subdirectory here can itself be a symlink into the private
repo to surface other kinds of configuration — for example
`rules/private -> <private-root>/rules` or `agents/private -> <private-root>/agents`
— so private rules and agents live in the private repo yet appear in the loaded
configuration through the symlink. This is the inverse of option 4's failure:
it works *because* rules and agents do not carry skills' flat-discovery
constraint. The exact loading behavior for a symlinked rules or agents
subdirectory — recursive discovery, and whether rules need explicit `@`-import —
has not been checked and would need validation before relying on it; it is noted
here as a direction, not a validated mechanism.

Any such symlink would be local-only. A committed symlink stores a
machine-specific absolute path, which both breaks for anyone else and advertises
the private repo's location, so each one takes a re-deny in the allowlist
`.gitignore` (the ADR 0003 mechanism) and is created by the private repo's setup
rather than tracked here.

## Consequences

- **Positive:** Private and in-development skills get a real home — their own
  history, backup, and cross-machine sync — with no risk of leaking into the
  public repo, because they live in a physically separate tree.
- **Positive:** Loading is opt-in. A session started the ordinary way sees only
  public configuration; the private skills appear only when the directory is
  added, so nothing private surfaces in an ordinary screenshare or shared
  session.
- **Positive:** Promotion and retirement are clean — copy into public `skills/`
  to publish, delete from the private repo to retire — with no orphaned history
  on either side.
- **Positive:** The same `--add-dir` grant that loads the private skills also
  grants file access to the added tree, so a single session rooted in this repo
  (or in any project) can read, edit, and run git in the private repo as well.
  The two trees are worked as one workspace even though they remain separate
  repos — which is what keeps the split tolerable in daily use, rather than
  forcing a second session just to touch a private skill.
- **Neutral:** The private repo mirrors this repo's `.claude/skills/` shape.
  That is a small amount of structure to carry, but it is the same shape, so
  there is nothing new to learn.
- **Negative:** Private skills do not load unless the session is started with
  the directory added. Forgetting to add it means the skills silently are not
  there — a quiet failure, not a loud one.
- **Negative:** The `--add-dir` path covers skills only. Extending to rules and
  agents needs the symlink approach above, which carries its own unvalidated
  loading questions and per-symlink `.gitignore` upkeep. The private repo is not
  a drop-in second `~/.claude`.
- **Negative:** Two repos to keep straight, with no drift tooling. Unlike
  ADR 0001's `compare-skills.sh` / `sync-skill.sh`, nothing here surfaces when a
  promoted skill and a copy left behind have diverged; the maintainer tracks
  that by hand.

## References

- [ADR 0001](0001-skill-maintenance-via-parallel-repos.md) — Skill Maintenance
  via Parallel Git Repos; the sibling decision, covering distribution of skills
  that *are* ready to share. This ADR covers the opposite end: incubation of
  skills that are not.
- [ADR 0003](0003-allowlist-gitignore.md) — Allowlist-Based .gitignore; the
  re-deny mechanism the forward-looking symlinks would rely on, and the
  safety-by-default property option 2 would undercut.
- [Claude Code skills documentation](https://code.claude.com/docs/en/skills) —
  the `--add-dir` skill-loading exception and the
  `permissions.additionalDirectories` carve-out.

## Amendment — 2026-07-13

The "not only skills" section above anticipated surfacing other *configuration*
(rules, agents) through local-only symlinks. This extends the same direction to
material that is not configuration at all: the author's working documents —
`dotclaude/ideas/` and `~/.claude/notes/`. Both were gitignored and
single-machine, with no history or backup, only because the public dotclaude
tree (ADR 0003) is no place for unpublished personal material. The private repo
is, so those directories now live there and are tracked.

The core decision is unchanged: the private repo is still the separate,
outside-`~/.claude`, `--add-dir`-loaded tree. This only widens what it
holds — from a private-skills incubator (and, per the section above, other
loadable config) to also a store for non-config working docs that need version
history and cross-machine sync. Skill loading is untouched — ideas and notes are
tracked, not loaded. The premise the original Decision rests on — that a real
private skill loads cleanly from here — is still what would validate the repo as
a skills incubator. This amendment concerns only its second role, as a store,
whose own validation follows the migration below.

**Mechanism.** The private repo adopts ADR 0003's allowlist `.gitignore` pattern:
ignore everything, re-include only what should be tracked (`.claude/`, `ideas/`,
`notes/`, and the repo's own support files), then re-ignore two classes of
content wherever they appear in the tree — build artifacts (`*.zip`, `*.tar`, and
the like) and anything under a `private/` directory. The `private/` rule is a
convention, not a per-directory special case: sensitive material — the people-
and client-knowledge captured during real runs (see `sensitive-knowledge.md`)
that must not enter a tree which may later gain a remote — lives under a
`private/` subdir and is never tracked. The run material from real runs (both the
raw capture and a partially-sanitized "cleaned" copy) moves under `private/` to
adopt it. This is the same safety-by-default move ADR 0003 makes for build
artifacts, generalized: rather than naming each sensitive directory, one
convention marks them all, and new sensitive material has a defined home from the
start.

**Preserving references.** The directories move into the private repo with
local-only symlinks left behind (`dotclaude/ideas` → `<private-root>/ideas`,
`dotclaude/notes` → `<private-root>/notes`), so existing paths —
`dotclaude/ideas/…` in memories and docs, and `~/.claude/notes/` via the ADR 0001
symlink — still resolve. Like the config symlinks in the section above, these
stay gitignored in dotclaude (nothing re-includes them) and are created by
the private repo's `make install`, not tracked.

**Tradeoffs.** The extension is not free:

- **Neutral:** setup on a new machine now includes cloning and `make`-installing
  the private repo — one more step in the existing dotfiles → dotclaude
  clone-and-install chain. The dependency is local only: the `ideas`/`notes`
  symlinks are gitignored in dotclaude, so the public template is unaffected, and
  the private repo's own `make` (not dotclaude's) creates them, keeping the public
  repo free of any dependency on it.
- **Negative:** the repo's purpose splits. The private repo is no longer only a
  private-skills incubator but also a general working-doc store — a deliberate
  widening, but one that gives up the single-purpose framing the original decision
  had.
- **Neutral:** the `private/` convention gives sensitive material a defined,
  always-ignored home, but it does not classify the rest of `ideas/`
  automatically. Some of that content is people-adjacent (the exit-kit material),
  so what belongs under `private/` versus tracked in the open stays a per-content
  judgment — and the stakes rise if the private repo ever gains a remote.

## Amendment — 2026-07-21

The "Forward-looking: not only skills" section above proposed surfacing private
*rules* through a `rules/private -> <private-root>/rules` symlink, but flagged the
loading behavior — recursive discovery, and whether rules need an explicit
`@`-import — as unchecked: "a direction, not a validated mechanism." That direction
is now built and validated.

A private rule now lives in the private repo at `rules/<name>.md`, surfaced through
`dotclaude/rules/private -> <private-root>/rules`. A fresh session's `/context`
confirms the rule in the loaded set: native memory-directory discovery follows the
symlink into the private tree and loads the rule with no `@`-import — the same
passive discovery that loads this repo's own `rules/*.md` (there is no `@`-import in
the root `CLAUDE.md`). The first such rule is
the proactive-firing companion to a private skill — the half a skill package cannot
carry. In a session with the private directory added, the skill it companions loads
too, making this also the first real private *skill* proven to load from the private
repo, which validates the original Decision's core premise (a real private skill
loads cleanly from here), independent of this amendment's rules extension.

**Mechanism.** The private repo's allowlist `.gitignore` re-includes `rules/`,
alongside the `.claude/`, `ideas/`, and `notes/` it already tracked. The
`rules/private` symlink is created by the private repo's `make install` — the same
install path that creates the `ideas` and `notes` symlinks — and is not tracked in
dotclaude. Because dotclaude's own allowlist re-includes `rules/**`, the symlink
takes one explicit re-ignore (`/rules/private`) so it is not swept into the public
tree. That is a single re-ignore for the one symlink, not one per rule: further
private rules are just files under the already-surfaced directory.

**What this resolves, and what it doesn't.** The Consequences section listed as a
negative that extending beyond skills "carries its own unvalidated loading
questions." For rules those questions are answered: recursive discovery works and no
`@`-import is required. The question the first draft left open — whether a private
rule loads in a *plain* session with no `--add-dir` — is now settled: it does. A
plain-`claude` session's `/context` lists the private rule, because the symlink is a
filesystem fact under `~/.claude` and native discovery follows it regardless of
`--add-dir` (the file-access grant `--add-dir` adds is not needed to read across it).
That resolves the privacy question below — not in the reassuring direction. One thing
does remain open: agents are still unexercised — the same symlink shape is expected
to work for `agents/private`, but has not been tried.

**Tradeoffs.**

- **Positive:** private behavioral rules gain what the 2026-07-13 amendment gave the
  working docs — version history, backup, and cross-machine sync — and load
  automatically once `make install` has run. Before, a private rule had nowhere to
  live but the public tree or an untracked, single-machine local file.
- **Neutral:** the private repo's purpose widens once more — from skills incubator
  (original) to working-doc store (2026-07-13) to now also a home for private
  behavioral rules. This is consistent with the prior widening, and the same single
  `make install` carries it.
- **Negative:** the opt-in property the Decision claims as a Positive — "nothing
  private surfaces in an ordinary screenshare or shared session" — does *not* hold
  for symlinked rules the way it holds for skills. Confirmed by a plain-`claude`
  session: the private rule is in context every session, screenshare included,
  whether or not the private directory was added. This is accepted as inherent to the
  symlink mechanism rather than a defect to fix — the mitigation is that rules are
  behavioral guidance, not the people-knowledge the `private/` convention
  quarantines, so keeping sensitive specifics out of rule prose bounds the exposure.
  Private *skills* keep their opt-in loading; private *rules* do not.
