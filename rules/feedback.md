# Feedback

Overflow for rules and feedback that don't fit an existing rule file. Periodically review this file — if an entry has grown into a pattern or belongs with a coherent topic, extract it into an appropriate rule file rather than leaving it here indefinitely.

## Diagnose before retrying

When a command fails **or gives unexpected output**, diagnose why before trying again. Retrying the same command (or minor variants) without understanding is a loop, not debugging. This applies equally to unexpected output — if a command succeeds but the output isn't what was expected, reason about why rather than issuing variations hoping for different results.

Specific case: `fatal: bad revision '<file>'` in git means git is interpreting a path as a tree-ish. Fix: use `--` to separate revisions from paths (`git diff HEAD -- <file>`).

## Scope searches to the known location

When searching for a file or pattern, start from the most specific known directory — not a broad ancestor. Searching from a parent directory is slower, noisier, and risks touching unintended paths. If the search fails, widen incrementally.

Also: when the target path is a symlink, `find` may not follow it without a trailing slash. Use `find /path/to/symlink/ ...` (with trailing slash) to ensure the symlink is resolved.

## Stay within review scope

When reviewing or auditing, stay within the requested scope — do not propose or make code changes unless asked. A review request is a read-only task unless the user explicitly says to fix what's found.

## settings.json and Permission Rules

In Claude Code's `settings.json`, path fields (e.g. `additionalDirectories`) support `~/` tilde expansion but **not** `$HOME` variable expansion. Use `~/.claude` not `$HOME/.claude`.

Hook `command` strings are different — they're executed by bash, so `$HOME` works fine there.

Permission glob patterns (e.g. `Edit(~/.claude/*)`) use `*` which does **not** match subdirectories. Use `**` to match recursively: `Edit(~/.claude/**)`. Failing to do so leaves subdirectory edits unmatched, causing unexpected permission prompts.

Bash commands containing backslash-escaped whitespace (e.g. `Application\ Support`) trigger a separate confirmation dialog regardless of allow-list rules. Use `$HOME` with proper quoting instead: `"$HOME/Library/Application Support/"` rather than `~/Library/Application\ Support/`.
