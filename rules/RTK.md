# RTK - Rust Token Killer

**Usage**: Token-optimized CLI proxy (60-90% savings on dev operations)

`rtk proxy <cmd>` runs a command raw, bypassing every RTK filter. It is the escape hatch the rest
of this file keeps reaching for, so it is the one meta command worth knowing without a lookup.

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
This covers **appending** too: to add to an existing file, Edit anchored on its last
unique line (or Read-then-Write for a full rewrite) — never a shell redirect
(`printf … >> file`, `echo … >> file`, `cat >> file`). The append case is the easy slip,
because it reads as "just adding text" rather than "editing a file"; it is the latter. The
tell is escaping content to survive the shell — the `'"'"'`-style apostrophe contortion, or
backslash-escaping quotes/`$`/backticks — which the file tools never require. A shell
redirect also routes through the permission gate the file tools sidestep.

The same holds for *creating* a file: use the **Write tool**, not `cat > file`/heredoc via Bash.
A Bash write routes file work through the permission gate Write sidesteps entirely — `cat` isn't
allow-listed, so it prompts, and `rtk read` is read-only, no help for a write. Write, like Edit,
never touches the Bash gate.

### When not to use awk

awk is fine for the genuine case it's built for — a per-line or per-field transformation
where you need the line's *content* alongside a computed value (e.g. `awk '{ print length": "$0 }'`
to see which commit-body lines exceed a wrap width and what they say). Reach for it only when
no simpler tool covers the need. Three cases where it's the wrong reach:

- **A dedicated tool already answers the question.** For a single number, prefer the
  single-purpose tool: `wc -L` for the longest line's length, `wc -l` for a line count,
  `grep -c` for a match count. `… | wc -L` beats `… | awk '{ if (length>m) m=length } END { print m }'`
  for "is anything over 72?" — shorter, clearer, and `wc` has no destructive form so it's
  safely allow-listed (`Bash(wc:*)`) — awk is not.
- **In-file editing.** Same rule as `sed` above — use Edit, never `awk -i inplace` or an
  awk-to-tempfile-and-move dance.
- **Parsing structured formats.** Use a real parser (`jq` for JSON, &c.), not awk
  field-splitting. This is the shell-pipeline echo of code-style's "parse with parser
  libraries, not regex" — column-counting breaks on quoted delimiters, escapes, and
  embedded newlines exactly where it matters.

Failure mode this prevents: reaching for awk by reflex on a task a single-purpose tool does
in fewer characters and with less to get wrong — and, for parsing, building a fragile
field-splitter that looks right on the sample and breaks on the first irregular row.

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
for that anyway. Do not retry `rtk git diff` variants expecting different output. They all
go through the same filter. `git show` cannot substitute: it only shows committed changes,
not working tree differences.

`rtk find` suppresses output the same way — fine for navigating ("does this directory have
a README?"), wrong when an exact count or full list matters. Counting via
`rtk find ... | wc -l` returns the *filtered* count and silently underreports the real one.
When the answer feeds a quantitative check — file counts after a copy, an audit of every
match, anything where a decision rides on the total — use `rtk proxy find` instead. Failure
mode this prevents: a filtered `find | wc -l` looks authoritative and makes plausible-but-wrong
counts feel like ground truth, leading to false alarms (or worse, missed real ones) when the
delta between filtered and real is large.

**`rtk find` also respects `.gitignore` — a distinct trap from the token-suppression above.**
It omits gitignored paths entirely, not just some lines of output. In a repo that is
gitignored-by-default (this repo, `dotclaude`, uses an allowlist `.gitignore` per ADR 0003 — only
explicitly re-included paths are tracked), that means a `find` for anything *not* on the allowlist
(a stray PDF, a scratch note, a downloaded asset dropped into the tree) comes back empty even
though the file is sitting right there. The empty result reads as "file absent" when the truth is
"file present but gitignored." When searching for a file that may not be tracked — and especially
in an allowlist repo, where *most* files aren't — use `rtk proxy find` (raw `find`, no gitignore
filtering) or the built-in Glob tool. Failure mode this prevents: concluding a file doesn't exist
here (e.g. "it must be in the home directory") from an `rtk find` miss, when the hook silently
rewrote `find`→`rtk find` and gitignore hid the file.

**`rtk find` matches a glob *pattern*, not a directory — a third trap, upstream of both filters
above.** `rtk find <pattern>` globs filenames (grouped by directory), like the built-in Glob tool. It
is *not* real `find <dir>`, which lists a directory. So `rtk find docs/adr/` treats the directory
path as a pattern, matches no file *named* that, and returns empty with exit 0 — even when the
directory is full of tracked files. The hook makes it silent: a bare `find docs/adr/`, typed for
real-find's listing behavior, gets rewritten to `rtk find docs/adr/` before anyone types `rtk`. To
list a directory use `rtk ls <dir>` (or `rtk proxy find <dir>`, or Glob `docs/adr/*`). Reserve
`rtk find` for filename globs like `rtk find '*.md'`. Failure mode this prevents: reading an empty
`rtk find docs/adr/` as "the files aren't here" and reaching for the gitignore or token-suppression
explanations above, when neither applies.

**`rtk grep` swallows some short flags — `-h` prints rtk's help instead of suppressing filenames,
and exits 0 doing it.** rtk's own options shadow grep's, so `-h` (help), `-m` (max results) and
`-t` (file type) never reach grep. `-l` is the exception that makes guessing unsafe: rtk defines it
too (max line length) and yet it *does* reach grep, so which flags leak cannot be read off rtk's
`--help`. Position counts as much as the flag — only a *leading* flag hits rtk's parser, and the
same flag placed after the pattern and paths passes through and works. The exit code is what keeps
this quiet, because the help path returns 0, so a chained `rtk grep -h … && <next>` runs on as
though the search succeeded. Three fixes, cheapest first. Use the long form (`grep --no-filename`),
which code-style.md wants anyway and rtk passes through untouched. Move the short flag after the
positional args. Or go around the wrapper with `rtk proxy grep`. Verified on rtk 0.44.2 and for
`grep` alone — other subcommands define their own short flags, so assume nothing about which of
theirs leak. Failure mode this prevents: reading rtk's usage block as "I got the grep syntax wrong"
and retyping variants when the flag was correct and never arrived — or taking the exit 0 for a
successful search that found nothing.

## Golden Rule

**Always prefix Bash commands with `rtk`**. If RTK has a dedicated filter, it uses it. If not, it passes through unchanged. This means RTK is always safe to use.

**Important**: Even in command chains with `&&`, use `rtk`:
```bash
# ❌ Wrong
git add . && git commit -m "msg" && git push

# ✅ Correct
rtk git add . && rtk git commit -m "msg" && rtk git push
```

**Exception — `python3` and `uv` pass through unchanged.** The golden rule holds for anything RTK
can rewrite. A command with no RTK equivalent is *not* prefixed — `rtk rewrite` returns exit 1 and
the command reaches the permission gate exactly as written. `python3` and `uv` are the live cases.
So their allowlist entries take the **bare** form — `Bash(python3 *…)`, `Bash(uv run *…)` — never an
`rtk python3 …` prefix, which would never match the string the gate actually sees. This is the same
passthrough mechanism as the `cat "$(…)"` and heredoc-commit slips below (`rtk rewrite` exit 1 → bare
command at the gate). The difference is that for `python3`/`uv` the bare form is *correct*, not a slip
to route around. Mechanism confirmed by reading `hooks/rtk-rewrite.sh`.

## Hook-Based Usage

All Bash tool calls are automatically rewritten by the Claude Code hook.
Example: `git status` → `rtk git status` (transparent, 0 tokens overhead)

**Scope limitation**: The hook only intercepts Bash tool calls. Claude Code built-in tools
(Read, Grep, Glob) bypass the hook entirely. To get RTK's compact output for file/search
workflows, use shell commands via Bash instead: `cat`/`head`/`tail`, `rg`/`grep`, `find` —
or call `rtk read`, `rtk grep`, `rtk find` directly.

**`cat` slip**: Dynamic path patterns like `cat "$(ls ...)"` frequently bypass RTK. Always use `rtk read "$(ls ...)"` — never `cat "$(ls ...)"`.  

**heredoc commit slip**: A heredoc-fed `git commit -F - <<'EOF' … EOF` isn't rewritten —
`rtk rewrite` passes it through (exit 1), so it reaches the permission gate as a bare `git commit`
and prompts (only `rtk git:*` is allowed — `settings.md` covers why heredoc/substitution forms pass
through). Create the message file with the **Write tool** (per the file-creation rule above), then
`rtk git commit -F <file>` — or `rtk git commit -m "…"` for single-line forms the rewriter handles.
The file form also keeps the message text out of the command string, dodging the deny-substring trap.

**`cd`-strip footgun**: `rtk rewrite` strips a leading `cd <project-root> &&` (the reflexive-cd
cleanup) by a raw, **non-quote-aware** text match — `rtk rewrite 'cd <project-root> && pwd'` returns
`rtk rewrite 'pwd'` even with the `cd …` inside a single-quoted argument. So any command that merely
*contains* the substring `cd <project-root> &&` — in an `echo`, a `grep` pattern, a commit message, a
heredoc, a quoted argument — has it silently removed, corrupting the command. Same
naive-string-manipulation family as the deny-substring trap (`settings.md`) and the two slips above;
same mitigation — keep that literal substring out of the command text (pass via a file, reword).

When you need an RTK command or flag not covered above, load the full reference (read it on demand): `rules/references/rtk/commands.md` (excluded from context).

