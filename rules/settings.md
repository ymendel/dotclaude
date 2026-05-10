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
