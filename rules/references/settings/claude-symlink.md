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
`skills/` or `handoffs/` directory in any project, broader than the intent. The standing default is to
accept the prompts as the cost.

> **PreToolUse hook — future option.** When the prompt cost becomes load-bearing (the live case is
> session handoffs being interrupted mid-departure), a hook can intercept Edit/Write under specific
> paths, validate narrowly, and exit 0 to skip the prompt without broadening the global allow list.
> Sketch: check that the path is under `~/.claude/handoffs/` (or the canonical
> `dotclaude/.claude/handoffs/`), exit 0 to allow. Design properly when picked up.

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
