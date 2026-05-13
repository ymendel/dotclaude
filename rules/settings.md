---
paths: ["**/settings.json", "**/settings.local.json"]
---

# settings.json

Gotchas and conventions for Claude Code's `settings.json`.

## Path Fields vs. Hook Commands

Path fields (e.g. `additionalDirectories`) support `~/` tilde expansion but **not** `$HOME` variable expansion. Use `~/.claude`, not `$HOME/.claude`.

Hook `command` strings are executed by bash, so `$HOME` works fine there.

## Permission Glob Patterns

`*` in permission patterns (e.g. `Edit(~/.claude/*)`) does **not** match subdirectories. Use `**` to match recursively: `Edit(~/.claude/**)`. Failing to do so leaves subdirectory edits unmatched, causing unexpected permission prompts.

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
