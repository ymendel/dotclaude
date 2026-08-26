# Permission Rules Through the `~/.claude → dotclaude` Symlink

> Not loaded in context by default. See `rules/settings.md` for behavioral guidance.

## What the docs say

Verbatim, from the [permissions docs](https://code.claude.com/docs/en/permissions):

> When Claude accesses a symlink, permission rules check two paths: the symlink itself and the file it resolves to. Allow and deny rules treat that pair differently: allow rules fall back to prompting you, while deny rules block outright.
>
> - **Allow rules**: apply only when both the symlink path and its target match. A symlink inside an allowed directory that points outside it still prompts you.
> - **Deny rules**: apply when either the symlink path or its target matches. A symlink that points to a denied file is itself denied.

Failure mode: a rule that names only the symlink path, or only the canonical target, silently produces
prompts for every edit, with no signal that the rule "didn't fire" because of the symlink.

## Why it bites on this machine

The dotclaude repo is the target of the `~/.claude` symlink. An edit reached as
`~/.claude/skills/adr/SKILL.md` resolves to two paths whose only common segments are below the
`skills/` (or `handoffs/`, &c.) directory — the symlink side anchors under `.claude/`, the target side
under `dotclaude/`. A rule anchored on either of those top-level segments matches one path only, so
the allow rule fails and the prompt fires.

**Two rules do not compose.** Pairing `Edit(~/.claude/**)` with `Edit(**/dotclaude/**)` does *not*
silence the prompt. A *single* pattern has to match both paths.

For one rule to cover both, the pattern needs a segment present in both — `Edit(**/skills/**)` for
skill edits, `Edit(**/handoffs/*.md)` for handoffs. The trade-off is that these also auto-match any
`skills/` or `handoffs/` directory in any project, broader than the intent.

**Neither that rule nor its trade-off is needed, because the symlink is optional.** The repo *is* the
working directory, so every file in it has a canonical path with no link in it. Write
`dotclaude/rules/settings.md` and the pair never arises. Confirmed in both directions: an edit reached
through `~/.claude/notes/…` prompts, the same edit reached as `<private-root>/notes/…` does not, and
no allow rule changed between them — so this is not a gap in the allow list to be patched but a choice
about how the path gets written. The standing default recorded here used to be to accept the prompts
as the cost, which quietly assumed the link path was the only way in.

> **PreToolUse hook — superseded, kept for the reasoning.** This block proposed a hook intercepting
> Edit/Write under specific paths and exiting 0, motivated by session handoffs being interrupted
> mid-departure. Handoffs in this repo are reachable as `dotclaude/.claude/handoffs/`, which carries no
> symlink, so the prompt it was designed around never fires. It also never addressed handoffs in *other*
> projects: there `.claude/` is an ordinary directory and the prompt is the sensitive-directory gate, a
> different mechanism that `notes/claude-code-quirks.md` records a hook as having been measured against
> and failed to beat.

## Resolving a path under `~/.claude`

The symlink points at the repo *root*, so `~/.claude/projects` is `dotclaude/projects`, not
`dotclaude/.claude/projects`. The repo separately carries an ordinary project-local `.claude/`
(`handoffs/`, `reviews/`, `audits/`, `scratch/`, `settings.json`, `settings.local.json`), so both
spellings can exist and look plausible. Resolve `~/.claude/X` by *dropping* the `.claude` segment,
never by appending one.

Inside `projects/`, each per-project directory is named by replacing every `/` in the project's
absolute path with `-`, which is lossy: `-Users-alice-dev-shipping-tracker` is ambiguous between
`…/dev/shipping/tracker` and `…/dev/shipping-tracker`. Encode a known path to find its directory,
never decode a directory name into a path you then assert exists. To identify a directory's project,
read the `cwd` field in its session `.jsonl` files.

Failure mode: both mistakes return something plausible rather than erroring — a wrong-tree search
comes back empty and reads as "no match", and a wrongly-decoded path reads as "the project moved and
these transcripts are orphaned".
