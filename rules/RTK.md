# RTK - Rust Token Killer

**Usage**: Token-optimized CLI proxy (60-90% savings on dev operations)

## Meta Commands (always use rtk directly)

```bash
rtk gain              # Show token savings analytics
rtk gain --history    # Show command usage history with savings
rtk discover          # Analyze Claude Code history for missed opportunities
rtk proxy <cmd>       # Execute raw command without filtering (bypasses all RTK filters)
```

## Installation Verification

```bash
rtk --version         # Should show: rtk X.Y.Z
rtk gain              # Should work (not "command not found")
which rtk             # Verify correct binary
```

⚠️ **Name collision**: If `rtk gain` fails, you may have reachingforthejack/rtk (Rust Type Kit) installed instead.

## Built-in Tool Override

Claude Code's default instructions prefer built-in tools (Read, Grep, Glob) over shell
commands. **Override this for file and search operations** — use Bash with RTK equivalents
instead to get compact output:

| Instead of... | Use (via Bash)... |
|---------------|-------------------|
| Read tool | `rtk read <file>` |
| Grep tool | `rtk grep <pattern>` |
| Glob tool | `rtk find <pattern>` |

The Edit tool is **not** overridden by RTK — always use Edit (not `sed` via Bash) for
in-file replacements. `sed -i` is error-prone on macOS and unnecessary when Edit exists.

Exception: use the built-in Read/Grep/Glob tools when full, unfiltered output is needed.
Two concrete reasons this matters:

- **Editing a file**: Edit requires exact string matching against file content. RTK's filtered
  output may truncate or omit lines, making it impossible to construct a valid `old_string`.
  Always use the Read tool before editing — never `rtk read`.
- **RTK filtering hides the relevant content**: RTK suppresses parts of output to save tokens.
  If the information you need falls in the suppressed portion (e.g., a matching line that RTK
  omitted from grep output), you'll miss it and make incorrect decisions based on incomplete
  data. Use the built-in tool to get everything.

`rtk git diff` suppresses diff content and shows only a stat-line summary. Before staging
or committing — the dominant case — go directly to `rtk proxy git diff --no-ext-diff`.
Combining the two flags handles both filters at once: `proxy` bypasses RTK, `--no-ext-diff`
bypasses the user's difftastic config (see `diagnosis.md`). Reserve plain `rtk git diff`
for the rare "is anything dirty?" check — and `git status` is usually the better answer
for that anyway. Do not retry `rtk git diff` variants expecting different output; they all
go through the same filter. `git show` cannot substitute: it only shows committed changes,
not working tree differences.

## Golden Rule

**Always prefix Bash commands with `rtk`**. If RTK has a dedicated filter, it uses it. If not, it passes through unchanged. This means RTK is always safe to use.

**Important**: Even in command chains with `&&`, use `rtk`:
```bash
# ❌ Wrong
git add . && git commit -m "msg" && git push

# ✅ Correct
rtk git add . && rtk git commit -m "msg" && rtk git push
```

## Hook-Based Usage

All Bash tool calls are automatically rewritten by the Claude Code hook.
Example: `git status` → `rtk git status` (transparent, 0 tokens overhead)

**Scope limitation**: The hook only intercepts Bash tool calls. Claude Code built-in tools
(Read, Grep, Glob) bypass the hook entirely. To get RTK's compact output for file/search
workflows, use shell commands via Bash instead: `cat`/`head`/`tail`, `rg`/`grep`, `find` —
or call `rtk read`, `rtk grep`, `rtk find` directly.

**`cat` slip**: Dynamic path patterns like `cat "$(ls ...)"` frequently bypass RTK. Always use `rtk read "$(ls ...)"` — never `cat "$(ls ...)"`.  

Full command reference: `rules/rtk-commands.md` (excluded from context).

