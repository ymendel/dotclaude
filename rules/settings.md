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

## TODO: Reconsider `Bash(rtk curl:*)`

`rtk curl:*` is currently in the allow list to support fetching documentation and web content. This is broad — it allows any curl command without URL restriction. Consider replacing with:

- `WebFetch` (built-in tool, domain-restrictable via `WebFetch(domain:example.com)`)
- `WebSearch` for search use cases

Before removing curl, verify whether `WebFetch` requires an explicit allow entry under `acceptEdits` mode, or prompts by default.
