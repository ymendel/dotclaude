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

**An empty or thin `rtk find` / `rtk grep` result is a wrapper artifact before it is an answer.**
Four separate mechanisms in these two commands turn a real match into a clean-looking miss — token
suppression, `.gitignore` filtering, a glob-vs-directory mismatch, and short flags consumed before
they reach the tool. None of them errors, and two are documented to return exit 0 while producing
nothing, so the result reads as the answer. **Load `rules/references/rtk/traps.md` before concluding
a file or match isn't there, and before retrying with a different flag** — it maps each symptom to
its mechanism and its escape (`rtk proxy …`, `rtk ls`, the built-in Glob tool, long-form flags).
Failure mode this prevents: a filtered or gitignored miss is taken as ground truth, and the next
step is built on "that file isn't here" or "nothing matches" when both are false.

## Golden Rule

**Always prefix Bash commands with `rtk`**. If RTK has a dedicated filter, it uses it. If not, it passes through unchanged. This means RTK is always safe to use.

**Important**: Even in command chains with `&&`, use `rtk`:
```bash
# ❌ Wrong
git add . && git commit -m "msg" && git push

# ✅ Correct
rtk git add . && rtk git commit -m "msg" && rtk git push
```

**Exception — `python3`, `uv`, and `trafilatura` pass through unchanged.** The golden rule holds for
anything RTK can rewrite. A command with no RTK equivalent is *not* prefixed — `rtk rewrite` returns
exit 1 and the command reaches the permission gate exactly as written. Those three are the live
cases. So their allowlist entries take the **bare** form — `Bash(python3 *…)`, `Bash(uv run *…)`,
`Bash(trafilatura --URL *…)` — never an `rtk python3 …` prefix, which would never match the string
the gate actually sees. This is the same passthrough mechanism as the `cat "$(…)"` and heredoc-commit
slips below (`rtk rewrite` exit 1 → bare command at the gate). The difference is that here the bare
form is *correct*, not a slip to route around. Mechanism confirmed by reading `hooks/rtk-rewrite.sh`.

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

Two reference files carry the rest, both excluded from context and read on demand:

- `rules/references/rtk/commands.md` — when you need an RTK command or flag not covered above, or
  when rtk itself misbehaves: the install check, the `reachingforthejack/rtk` name collision, and
  the `rtk gain` / `rtk discover` analytics along with how to read their output.
- `rules/references/rtk/traps.md` — when `rtk find` or `rtk grep` returns an empty or surprising
  result, per the section above.

