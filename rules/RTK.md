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

**Emptying a file is the third form, and the one the two paragraphs above don't obviously name.**
`: > file` and `> file` truncate rather than write, so neither "appending" nor "creating" reads as
covering them, which is why the redirect is what gets reached for. It is still a write. Use the
Write tool with empty content, or Edit to remove the lines that were the point — and reserve `rm`
for a file that should be gone rather than emptied, which is a different intent and often the wrong
one (an index file the tooling expects to exist wants truncating, not deleting).

The gate makes this the costliest of the three forms. It splits a compound command per segment
(`settings.md`) and names each segment by its command name, so a truncation riding along in an
otherwise ordinary `rm … && … && ls …` reaches the prompt as a bare `:` — the shell's no-op
builtin. The splitting is documented; the bare-`:` prompt is an observation from one such
command. An allow-list
entry for that can only ever be granting the redirect, because `:` does nothing on its own, so
`Bash(:)` reads as harmless while being a standing grant to truncate any file on disk. Decline it
wherever it is offered.

Failure mode this prevents: the truncation form slips past a rule written around appending and
creating, and the prompt it provokes then offers a permanent grant whose danger is invisible in the
name it is offered under.

### When not to use awk

awk is fine for the case it's built for — a per-line or per-field transformation where the
line's *content* is wanted alongside a computed value. Reach for it only when no simpler tool
covers the need: a single number belongs to a single-purpose tool (`wc -L`, `wc -l`,
`grep -c`), in-file editing to Edit, and a structured format to a real parser. Those three
cases and why each one bites are in `rules/references/rtk/awk.md` — load it when about to
write an awk expression, which is the moment the alternative is still cheap to take.

Failure mode this prevents: reaching for awk by reflex on a task a single-purpose tool does
in fewer characters and with less to get wrong — and, for parsing, building a fragile
field-splitter that looks right on the sample and breaks on the first irregular row.

### `sed` is not a line selector

Selecting lines is grep's job. A range-print (`sed -n '/START/,$p'`, `sed -n '5,20p'`) reaches
for a stream *editor* to do it, and the gate charges a read-only invocation exactly what it
charges an editing one: `sed` carries no allow entry and sits outside the built-in read-only
set, so every form of it asks, while `Bash(*sed -i*)` denies the in-place form outright. So the
filter added to keep the output small is the thing that stops the run, which is the same shape
as *Don't add shell machinery the task didn't ask for* in `tool-and-shell-safety.md`.

Reach for the plain alternatives instead: `rtk grep` (with `-A`/`-B`/`-C` when surrounding
context is what the range was really for), the built-in Grep tool for unfiltered matches, or
simply printing the whole thing when it is short — a `--help` page or a config file usually
is. Where a genuine transformation is needed, Edit does in-file changes and a real parser does
structured formats, exactly as in the awk case above.

The tell is a `-n` paired with a `p`: that combination means "suppress everything, then print
the part I want", which is a selection dressed as an edit. When the goal really is editing,
use Edit — never `sed -i`, which the tool-override section above already rules out and which
is error-prone on macOS besides.

Failure mode this prevents: a read-only inspection trips an approval prompt for a "write or
execute" command, and because the *work* was harmless the prompt reads as an over-strict gate
rather than as the wrong tool — so the fix that suggests itself is an allowlist entry for
`sed`, granting the in-place editor to buy a line range grep would have returned unprompted.

### When the filter hides what you need

Exception to the override table above: use the built-in Read/Grep/Glob tools when full, unfiltered
output is needed. Two concrete reasons this matters:

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

**`gh` shows the same shape, so treat an empty `gh` result the same way.** `rtk gh issue view
<n> --comments` returned nothing at all with exit 0, and so did `rtk proxy gh issue view <n>
--comments` — `proxy` is no escape here. Two escapes have been tried, and only one of them has
held up on every occasion:

- **`--json <fields>` works, and wants no pipe.** The call
  `rtk gh issue view <n> --json number,title,body,comments` returned the whole issue where the
  plain and `2>&1` forms both returned nothing. To narrow the result, reach for `gh`'s own
  `--jq <expression>` rather than piping into `jq`: a pipe adds a segment for the permission gate
  to clear and reports the filter's exit status in place of `gh`'s. This is also what
  `searching.md`'s *Prefer a tool's plain output over de-formatting its rendered output* asks for
  on its own terms — `gh`'s data mode rather than its display mode — so reach for it first rather
  than as a fallback.
- **Appending `2>&1` worked once and has since failed.** It returned the full issue on the occasion
  that first produced this note, and on a later one `rtk gh issue view <n> --comments 2>&1` returned
  nothing at all. So it is worth a try and worth nothing as a guarantee: a still-empty result after
  adding it says nothing about the issue. Keep it to output being *read here* — appending it to a
  redirect that captures a payload writes the error text into the file instead, per
  `tool-and-shell-safety.md`'s *Don't merge stderr into a file you intend to parse*.

Read an empty result as the tooling until a data-mode call says otherwise. This matters more than a
missing `grep` match, because the empty result reads as *an issue with no body or no comments* — a
claim about the artifact rather than about the tooling — and an issue or PR is exactly the kind of
thing whose contents get summarized onward to other people. It is also the check whose whole value
rides on trusting a negative, which `project-notes.md` leans on when it asks for a tracker search
before filing anything as new.

**For an Actions job log, reach for `gh run view` rather than the raw API path.** Actions logs carry
ANSI escape sequences from whatever ran inside them, and RTK declines to emit output containing
them without `--allow-escape-sequences` — so `rtk gh api repos/{owner}/{repo}/actions/jobs/{id}/logs`
stops with a refusal on stderr at exit 1, and `rtk proxy` is no escape. Reach for
`--log-failed` first, which returns only the failed steps and is usually the whole question, and
`--log` for the entire thing. `--job <id>` works on its own, so neither form needs a run id:

```bash
rtk gh run view --log-failed --job <job-id>
rtk gh run view --log --job <job-id>
```

Two caveats `gh`'s own help volunteers, both platform-dependent rather than deterministic. Logs come
as a zip by default, with a slower per-job API fallback when `gh` cannot associate jobs with their
logs, and that fallback fails outright once more than 25 job logs are missing. Some lines cannot be
tied to a step and appear under `UNKNOWN STEP`. This is a fact about the guard and about log content
rather than an instance of `searching.md`'s data-mode preference, which points the other way here —
the API is the data surface and `run view` is the rendered one.

## Golden Rule

**Always prefix Bash commands with `rtk`**. If RTK has a dedicated filter, it uses it. If not, it passes through unchanged. This means RTK is always safe to use.

**Important**: Even in command chains with `&&`, use `rtk`:
```bash
# ❌ Wrong
git add . && git commit -m "msg" && git push

# ✅ Correct
rtk git add . && rtk git commit -m "msg" && rtk git push
```

**Exception — `python3`, `ruby`, `node`, `trafilatura`, `heroku`, `brew`, `chmod`, and a project's own scripts pass
through unchanged.** The golden rule holds for anything RTK can rewrite. A command with no RTK
equivalent is *not* prefixed — `rtk rewrite` returns exit 1 and the command reaches the permission
gate exactly as written. `python3`, `ruby`, `node`, `trafilatura`, `heroku`, `brew` and `chmod` are
the live external cases, each confirmed by an exit-1 `rtk rewrite`, and a repo's own
entry points are the same class — **`bin/` binstubs as much as `scripts/`**: write `bin/rubocop …`,
`bin/rails test …`, `bin/ci`, `./scripts/sync-skill.sh …`, never `rtk` in front of any of them. So
their allowlist entries take the **bare** form — `Bash(trafilatura --URL:*)`,
`Bash(heroku releases:*)`, `Bash(./scripts/sync-skill.sh *--dry-run)`, and the path-globbed
`Bash(python3 *…)` — never an `rtk python3 …` prefix, which would never match the
string the gate actually sees.

**`uv` is not on that list — it rewrites, and the exit code says so.** `rtk rewrite 'uv run x'`
returns `rtk uv run x` with exit **3**, and the hook treats 3 as *rewrite and let Claude Code
prompt* rather than as passthrough (`hooks/rtk-rewrite.sh`, whose `case` falls through on 3 with no
early exit). So write `rtk uv run …`, and grant it in the `rtk`-prefixed form. A bare
`Bash(uv run …)` entry can never fire, because the gate never sees a bare `uv`.

Run `rtk rewrite '<the bare command>'` before adding any entry, and read the *exit code* rather than
the output: 1 is passthrough and earns a bare grant, 3 is a rewrite that happens to want a prompt and
earns an `rtk`-prefixed one. Both print something, which is what makes 3 easy to read as 1. Every such entry takes the boundary-enforcing `:*` or ` *` form —
`Bash(bin/rubocop:*)`, not `Bash(bin/rubocop*)`, which also matches `bin/rubocop-daemon`. Which file
it goes in is `settings.md`'s call and splits on what is being granted rather than on where the path
points: a repo's *own* script goes in that repo's `.claude/settings.json`, while a binstub for a
shared standard tool goes at user level with the tool itself. This is the same passthrough mechanism
as the `cat "$(…)"` and heredoc-commit slips below (`rtk rewrite` exit 1 → bare command at the gate).
The difference is that here the bare form is *correct*, not a slip to route around. Mechanism
confirmed by reading `hooks/rtk-rewrite.sh`.

**`gh` splits down the middle, so the exception is per subcommand rather than per command.** The
built-in subcommands rewrite — `rtk rewrite 'gh release list'` returns `rtk gh release list` — while
a `gh` **extension** does not: `rtk rewrite 'gh stack list'` exits 1, so `gh stack …` reaches the
gate bare, exactly like `heroku`. Write extensions unprefixed and give them bare allowlist entries
(`Bash(gh stack:*)`), and keep `rtk gh …` for everything gh ships itself. Verified against
`gh stack` (`github/gh-stack` v0.1.0, GitHub's stacked pull requests, public preview since
2026-07-30) on 2026-08-13.

The grants point the wrong way here, which is what makes it worth stating. `Bash(rtk gh:*)` covers a
hand-written `rtk gh stack …`, so the incorrect form runs unprompted while the correct bare one has
no entry and asks — the reverse of the standing-entry-keeps-prompting tell below. Read a prompt on
`gh stack …` as the missing bare grant, not as a reason to reach back for the prefix.

**A binstub is the easier miss, and `rtk test` hides it for a while.** `bin/rails` and `bin/rubocop`
read as ordinary commands the golden rule would cover, and the prefix-versus-wrapper distinction is
what makes the mistake survivable long enough to be confusing: `rtk bin/rubocop …` is the wrong
*prefix* form, while `rtk test bin/ci` is the right *wrapper* form — the one
`tool-and-shell-safety.md` asks for on any verification run, because it filters without a pipe and
propagates the wrapped command's status. Since `Bash(rtk test:*)` grants every wrapper invocation, a
session can run several `rtk test bin/…` commands unprompted and then be surprised when a
`rtk bin/rubocop …` asks. Nor does appending a pipe for brevity help: `bin/rubocop … | tail -5` is
split per segment (`settings.md`) and bare `tail` carries no grant where `rtk tail:*` does, so the
filter added to shorten the output is a second, independent reason the command stops — the
grant-shaped reason alongside the swallowed-status one that *`rtk proxy` is an escape hatch* below
covers.

**The tell that a tool belongs on this list is a *standing* allowlist entry that keeps prompting
anyway.** A granted command that still asks is evidence the gate is seeing a different string than
the entry was written for, and the `rtk ` prefix is the likeliest reason. Settle it with `rtk rewrite
'<the bare command>'` — exit 1 means the tool passes through, so write it bare and add it here rather
than adding an `rtk`-prefixed allowlist entry that can never fire. Failure mode: the prompts get read
as a missing grant, and the entry added to stop them duplicates one already present in the file.

**No RTK command filters stdin.** `rtk read`, `rtk grep`, and `rtk find` take paths; `rtk test <cmd>`
and `rtk err <cmd>` wrap a command. So piping a command's output into one — `<cmd> | rtk read
/dev/stdin` — filters nothing while adding a segment the gate has to clear on its own and
re-introducing the swallowed-exit-status trap. When a passthrough command's output runs long, wrap it
in `rtk test` or `rtk err`, or redirect to a file and `rtk read` the file. Failure mode: the pipe
reads as the compact-output habit applied correctly, so the prompt it causes gets diagnosed as a
missing grant for the command at the head of the pipeline.

**`rtk test` re-parses its command, so a quoted argument does not survive the wrapper.** The command
is handed to a shell a second time and the quoting is gone by then, so an argument containing spaces
arrives at the wrapped command as one argv entry per word. Nothing reports a quoting problem,
because whatever receives the strays decides how they present — a test runner that reads leftover
positional arguments as file paths turns them into `cannot load such file`, naming a word from the
middle of the pattern you were filtering on. Keep a wrapped command's arguments space-free, or run
it bare and redirect to a file when one has to contain spaces. Verified for `rtk test`; `rtk err`
and a plain rewritten command are unchecked. `notes/rtk-quirks.md` carries the two-line reproduction
and the episode it cost. A *metacharacter* in that argument is a separate mechanism this note does
not cover: an unquoted `|` or `(` is claimed by the outer shell before rtk sees the command at all,
so the wrapper's second parse never comes into it and a space-free argument is no protection. The
consequence is worse than a split argv — see `tool-and-shell-safety.md`'s *Don't add shell machinery
the task didn't ask for*.

Failure mode this prevents: the wrapper gets reached for exactly where the rules send you — filtering
a long verification run — and it corrupts the command it was added to make readable. The symptom
names the wrapped tool rather than the wrapper, so the diagnosis goes to the tool's own flags — the
one place the cause is not.

### `rtk proxy` is an escape hatch, not a prefix

The Golden Rule asks for `rtk`, not `rtk proxy`. Proxying bypasses every filter, so a reflexive
`rtk proxy <cmd>` pays the prefix and collects none of the savings — the Golden Rule inverted while
looking like compliance. Reach for it only with a reason to name: `rtk proxy git diff --no-ext-diff`
per the diff guidance above, debugging RTK itself, or a case where a filter is known to hide what is
needed (the Exception under *Built-in Tool Override*). "I wasn't sure" is not one of those reasons —
an unfiltered read is what the built-in Read/Grep/Glob tools are for.

**The tell that it is reflex rather than reason: `proxy` on a long-output command, paired with
`head` or `tail` in the same command line.** That pairing turns the filtering off and then
hand-rolls a cruder version of it, and the pipe it needs re-introduces the swallowed-exit-status
trap — so a CI or test run gated on `&&` reports the filter's status, not the suite's. `rtk test
<cmd>` and `rtk err <cmd>` filter the same output with no pipe at all and propagate the wrapped
command's status, which is why `tool-and-shell-safety.md` now sends verification runs there.

Failure mode this prevents: the prefix reads as the careful choice while doing the opposite of what
it is for, and the verbosity it causes gets papered over with a pipe that quietly breaks the exit
status the command was run to check.

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

