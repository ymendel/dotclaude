# What `reflexive-cd-guard.sh` Blocks and What It Lets Through

> Not loaded in context by default. See `rules/tool-and-shell-safety.md` for behavioral guidance.

`hooks/reflexive-cd-guard.sh` is a PreToolUse Bash hook, per [ADR 0004](../../../docs/adr/0004-rule-vs-hook-enforcement-split.md)'s
rule-vs-hook split. It exits 2 with a pointer back to the rule.

## Blocked

Both hazard shapes of the reflex, when the `cd` leads the command:

- a target that is the project root, the cwd, or `.` — redundant, and paired with output redirection
  it trips the path-resolution security check.
- a target that is any project subdirectory — it persists across calls and misdirects cwd-relative
  tools.

It resolves symlinks, so a `cd` through the `~/.claude → dotclaude` alias into a subdirectory is
caught as well.

Separately from the reflex, a command that **shadows `cd`** — `cd() { … }`, `function cd { … }`, or
`alias cd=…` — anywhere in it, not only at the start. This is not a directory change but
self-enforcement of the rule the guard already enforces, and it costs an approval prompt on a
command whose real work is often read-only, because the gate reports `function_definition` and no
allow rule can grant a parser node. The brace (or the `=`) is required to match, so a mere mention
passes — `rtk grep "cd()"` is fine, a command carrying the full definition text is not. That is the
deny-substring trade-off from `settings.md`: it over-blocks, and the workaround is to pass the text
via a file.

## Passes, by design

- a reverting subshell, `(cd <dir> && <cmd>)` — the sanctioned way to run from another directory.
- a `cd` *out* of the project — `..`, an unrelated absolute path, `cd -`.
- a target it cannot resolve at hook time, e.g. `cd $VAR`.
- a `cd` into a nonexistent subdirectory, where the real `cd` fails and no drift occurs.
- `cd <project-root>` when the shell is *not* already there — a recovery, not a reflex.

Those passthroughs are exactly what can strand the cwd elsewhere for the rest of a session, so
blocking the way back would have the guard trap the drift it exists to warn about.
