---
paths: ["**/settings.json", "**/settings.local.json"]
---

# settings.json

Gotchas and conventions for Claude Code's `settings.json`.

## Path Fields vs. Hook Commands

Path fields (e.g. `additionalDirectories`) support `~/` tilde expansion but **not** `$HOME` variable expansion. Use `~/.claude`, not `$HOME/.claude`.

Hook `command` strings are executed by bash, so `$HOME` works fine there.

## Permission Glob Patterns

Per the [official docs](https://code.claude.com/docs/en/permissions), `Read` and `Edit` permission rules follow gitignore semantics with four pattern anchors:

| Pattern            | Meaning                                | Example                          | Matches                        |
| :----------------- | :------------------------------------- | :------------------------------- | :----------------------------- |
| `//path`           | **Absolute** path from filesystem root | `Read(//Users/alice/secrets/**)` | `/Users/alice/secrets/**`      |
| `~/path`           | Path from **home** directory           | `Read(~/Documents/*.pdf)`        | `/Users/alice/Documents/*.pdf` |
| `/path`            | Path **relative to project root**      | `Edit(/src/**/*.ts)`             | `<project root>/src/**/*.ts`   |
| `path` or `./path` | Path **relative to current directory** | `Read(*.env)`                    | `<cwd>/*.env`                  |

Two pattern-shape gotchas the docs flag explicitly:

- **`/Users/alice/file` is NOT absolute** — it's project-root-relative. Use `//Users/alice/file` for absolute paths.
- **`*` matches a single directory; `**` matches recursively.** `Edit(~/.claude/*)` does not match subdirectory files; use `Edit(~/.claude/**)`. Failure mode: subdirectory edits prompt unexpectedly because the rule that looks correct doesn't actually match.

### Symlinks: rules check both paths

Per the docs, verbatim:

> When Claude accesses a symlink, permission rules check two paths: the symlink itself and the file it resolves to. Allow and deny rules treat that pair differently: allow rules fall back to prompting you, while deny rules block outright.
>
> - **Allow rules**: apply only when both the symlink path and its target match. A symlink inside an allowed directory that points outside it still prompts you.
> - **Deny rules**: apply when either the symlink path or its target matches. A symlink that points to a denied file is itself denied.

For a path reached via a symlink, every allow rule is checked against both the symlink and the target — the rule applies only if both match. Failure mode: a rule that names only the symlink path (or only the canonical target) silently produces prompts for every edit, with no signal that the rule "didn't fire" because of the symlink.

### Special case: `~/.claude → dotclaude/` on this machine

The dotclaude repo is the target of the `~/.claude` symlink. An edit reached as `~/.claude/skills/foo/SKILL.md` resolves to two paths:

- Symlink path: `/Users/yossef/.claude/skills/foo/SKILL.md`
- Target path: `/Users/yossef/dev/projects/mine/dotclaude/skills/foo/SKILL.md`

The currently-loaded rules each match only one of these:

- `Edit(**/.claude/**)` — symlink path only (the target has no `.claude` segment).
- `Edit(**/dotclaude/**)` — target path only (the symlink has no `dotclaude` segment).
- `Edit(/.claude/**)` — project-root-anchored in dotclaude expands to `dotclaude/.claude/**` and matches neither.

For a single rule to cover both paths, the pattern needs a segment common to both — e.g. `Edit(**/skills/**)` for skill edits, `Edit(**/handoffs/*.md)` for handoffs. This is the docs' plain reading of "both must match" (same single rule).

> **Pending empirical test (2026-05-21):** add `Edit(~/.claude/**)` persistently to `settings.json` and restart. If prompts still fire on edits via `~/.claude/...`, the same-single-rule interpretation is confirmed and the symlinked case needs cross-path patterns. If prompts go silent, "both must match" means any allow rule matches each side independently — and `Edit(~/.claude/**)` + `Edit(**/dotclaude/**)` would be the working pair. Until tested, write rules under the same-rule assumption.

## Project vs. Global Settings — Match Scope to Use

When adding a permission, choose the file by **scope of use**, not by which settings file happens to be open:

- **`~/.claude/settings.json`** (global) — for tools used across projects: skills, common scripts, shared CLI tools (`gh`, `heroku`, `jq`). The fact that the tool happens to live in one repo today doesn't change this if it's invoked from many.
- **`<project>/.claude/settings.json`** (project, committed) — for permissions other contributors should inherit (the project's build tooling, its CI invocations).
- **`<project>/.claude/settings.local.json`** (project, local-only) — for permissions only this user needs in this project (one-off experimentation, personal CLI shortcuts).

Failure mode: dropping skill-related permissions into a project's `.claude/settings.local.json` because that file already exists. The permission only kicks in when working inside *that* project, not when the same skill is used elsewhere — so the prompts return as soon as the skill is invoked in another repo. Default to global for anything skill-related or cross-cutting.

For paths in skill-related permissions, leading `**` lets a single global rule cover any project: `Write(**/.claude/handoffs/*.md)` matches a handoffs directory in every project the skill is used from.

## Paths With Spaces

When constructing shell commands that reference paths containing spaces (e.g. `~/Library/Application Support/`), use `$HOME` with proper quoting instead of backslash-escaping. Claude Code's permission system triggers a separate confirmation dialog for any command containing backslash-escaped whitespace, regardless of allow-list rules.

```bash
# ❌ Triggers backslash-escaped whitespace warning
rtk read "$(ls -t ~/Library/Application\ Support/rtk/tee/*.log | head -1)"

# ✅ No warning — $HOME + quoted path
rtk read "$(ls -t "$HOME/Library/Application Support/rtk/tee/"*.log | head -1)"
```

## Hook Output Semantics Vary By Hook Type

**Do not assume stdout from one hook type behaves like another.** Each hook type has its own output mechanism, and a hook that emits the wrong shape of output will silently do nothing useful — the failure mode is invisible.

- **`SessionStart`, `UserPromptSubmit`**: stdout is injected as a system reminder the model sees. Plain-text echo works.
- **`PreToolUse`, `PostToolUse`**: support JSON output with `hookSpecificOutput.additionalContext` to inject context for the model.
- **`PreCompact`**: JSON output only. Supports `decision` (block / not block) and `systemMessage` (user-facing). **Cannot inject context for the model to react to.** If the goal is to prompt the model to take action before compaction, PreCompact is the wrong tool — by hook semantics, the only intervention available is blocking compaction outright. (Storybloq's PreCompact hook works only because their MCP server has the model writing structured state to `.story/` *throughout* the session; the hook just snapshots already-written state. Without an incremental-write substrate, a DIY PreCompact hook can't replicate this.)

**Verify hook output semantics from the official docs (https://code.claude.com/docs/en/hooks) before designing a hook that depends on the model seeing the output.** Don't generalize from one hook type to another.

## TODO: Reconsider `Bash(rtk curl:*)`

`rtk curl:*` is currently in the allow list to support fetching documentation and web content. This is broad — it allows any curl command without URL restriction. Consider replacing with:

- `WebFetch` (built-in tool, domain-restrictable via `WebFetch(domain:example.com)`)
- `WebSearch` for search use cases

Before removing curl, verify whether `WebFetch` requires an explicit allow entry under `acceptEdits` mode, or prompts by default.
