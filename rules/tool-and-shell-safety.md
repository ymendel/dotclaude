# Tool and Shell Safety

Operating the shell and the file tools without silent mishaps — commands that trip an approval prompt, heredocs that ship stray escapes, writes that land somewhere other than intended, and destructive overwrites that can't be undone.

## Don't reflexively `cd` into the working directory

The Bash working directory is set to the project root at session start and persists across calls. Do not prefix commands with `cd /path/to/project` — it is unnecessary, and a `cd` combined with output redirection (`cd ... 2>/dev/null; <command>`) trips a security approval rule ("path resolution bypass"), forcing the user to manually approve every such command.

The reflex appears after working across multiple directories in one session (e.g. the project plus `~/.claude`), out of a wish to "be sure" of the cwd. Read/Edit on a file elsewhere does not change the shell's cwd, and tool calls don't drift it.

**A subtler consequence — silent wrong output, no approval prompt:** a `cd` into a *subdirectory of the project* (not just an unrelated dir) persists across calls the same way, and cwd-dependent tools then act on the wrong location without erroring — e.g. a handoff script writing relative to `os.getcwd()` lands its output in a subtree that the `SessionStart` hook and `list_handoffs.py` never scan (they see only the root), so nothing errors and the mistake is visible only by reading the tool's output path. This is distinct from the redirect/approval consequence above: that one is loud (an approval prompt), this one is silent.

**How to apply:** run commands directly — cwd is already the project root. If a command genuinely needs a different directory, pass it explicitly (`git -C <path>`, an absolute path) rather than `cd`-ing, and never combine `cd` with output redirection. This holds for project subdirectories too — a `cd` into `skills/` or `docs/` persists and will misdirect any cwd-relative tool (handoff scripts, generators, anything calling `getcwd`). When a tool's output lands somewhere unexpected, check `pwd` before assuming the tool is wrong.

**Now gated:** `hooks/reflexive-cd-guard.sh` blocks both hazard shapes with exit 2 and a pointer back here, so this prose is the discoverable *why* while the gate steers toward `git -C`, an absolute path, or a reverting subshell. It deliberately lets several `cd` forms through, including the ones that can strand the cwd elsewhere — blocking the way back would have the guard trap the drift it exists to warn about. `rules/references/tool-and-shell-safety/cd-guard.md` has the full blocked-and-allowed breakdown; load it when the guard fires on a command that looks legitimate, or before changing the hook.

## Don't add shell machinery the task didn't ask for

Write the command the work needs and nothing around it. The machinery bolted on out of diligence —
a guard, a status probe, a filter — is where the approval prompts come from, because the constructs
it is built out of are the ones the gate cannot resolve. Six instances, all real:

- **A function definition to enforce a rule on yourself.** Never open a command with `cd() { return
  1; }` or any other shadow of a command a rule forbids. Comply by writing the command without the
  forbidden form. The guard defeats itself: the gate reports `function_definition` (see *Batch
  repeated commands* below), that node cannot be allowlisted, so a read-only `grep` or `curl` stops
  for approval. Shadowing a command is also how one gets broken for real. An always-loaded
  prohibition is a reason to write a different command, never a mandate to build a mechanism that
  blocks it — and the `cd` rule already has `hooks/reflexive-cd-guard.sh`.
- **A function definition for no reason at all.** The case above at least has an argument behind it.
  This one has none: a stray `for_each() { :; };` or `cd() { :; };` in front of an ordinary `grep`,
  defining something nothing calls, enforcing nothing, doing nothing. It costs exactly what the
  deliberate version costs, because the gate reads the statement type rather than the intent —
  `function_definition`, unallowlistable, and a read-only search stops for approval. So read what
  sits in front of a command's first real word before sending it, and delete anything there that is
  not part of the work. Having done it once is reason to check the next few commands rather than to
  call it a one-off: the shape recurs within a session, and because it has no motive there is nothing
  to notice yourself talking into.
- **An invented command in front of the real one, with its error suppressed.** The same
  motiveless shape as above, in the one form of it no hook can detect: a
  `rtk provoke 2>/dev/null;` ahead of an ordinary `grep`, naming a subcommand that does not exist.
  Nothing is enforced and nothing is called — but unlike the function form there is no gate to stop
  it, so the only thing that would have surfaced it is the error, and the `2>/dev/null` is what threw
  that away. Exit 127 and a `No such file or directory` were both available and both discarded. So
  read the command's first segment before sending it, as above — and never suppress stderr on a
  segment you *added* rather than on the one doing the work. That is the narrower and more checkable
  rule: suppression on the working segment is often deliberate, while suppression on scaffolding can
  only ever hide the evidence that the scaffolding is there.

  What makes this the harder half to catch is that the command *works*. The real segment runs, the
  output looks right, and no gate can help — the leading command resolves fine, since only its
  subcommand is invented, so a does-this-binary-exist check never fires. The stray segment is visible
  only to someone reading the command string rather than its result, and that reader is the user.
- **A variable assignment to avoid retyping a long string.** A `REF=origin/main; git show
  $REF:lib/parser.rb` reads as the tidy way to run three commands against one ref, and it is the same
  trade as the loop in *Batch repeated commands* below — nothing is saved, because a programmatically
  issued command pays no keystrokes. The expansion alone would prompt, but an **unquoted** variable
  followed by `:` or `[` is refused for a sharper reason, reported verbatim as `zsh $name[expr] /
  $name:mod in bare concatenation — recursive eval`. zsh reads those as subscript and modifier syntax
  that can expand to something evaluated again, and the analyzer checks that reading rather than the
  shell actually running — so the prompt fires on a bash session where the string is inert
  concatenation, and it fires in an ordinary command rather than only inside `[[ ]]`. A ref-and-path
  argument is precisely that shape. Write the ref and the path out literally in each command, however
  long.

  **The motiveless variant is the same shape with none of the argument, and it is now gated.** A
  `for_check=""; rtk wc -l file` assigns a name nothing references, so there is not even a retyping
  case to weigh. `hooks/shell-machinery-guard.sh` blocks an assignment followed by a separator,
  which covers both variants — the example above included. It deliberately leaves the *prefix* form
  `FOO=bar cmd` alone, since that scopes the variable to one command and is ordinary shell; a
  separator terminating the value is the whole distinction. Read a block as a prompt to write the
  value out literally.

  **The prefix form clears the guard and still costs a prompt**, so passing is not a recommendation.
  An allow rule is anchored on the command name, and the assignment makes the string stop starting
  with `rtk`, so `Bash(rtk ls:*)` no longer matches — the same mechanism that makes a
  `GIT_SEQUENCE_EDITOR=…` prefix the sole reason its command asks. Observed on a
  `FOO=bar rtk ls dir/ | rtk head -3`. Blocking it would be the wrong instrument, since that is the
  allowlist's business rather than a guard's, but there is no reason to reach for it either.

  The motiveless form costs no approval prompt of its own — a plain assignment is auto-approved, so
  nothing interrupts and nothing errors, and the only reader who sees it is whoever reads the
  command string. That silence is why it is gated.

  A **redirect target** is checked by a second, separate detector, so that `:`-and-`[` mechanism is
  not the boundary: `> $S/pages-build.md` is refused as ``Redirect target concatenation contains $/`
  — unanalyzable gap or substitution``, which fires on an unescaped `$` or backtick anywhere in the
  target and on nothing else. Expect to want the variable here — the Bash tool asks for absolute
  paths, absolute paths are long, and a variable is the obvious way to make them tolerable — and
  write the path out anyway. `notes/claude-code-quirks.md` carries the generating code and why that
  message is a legend rather than a quotation.
- **A pipe plus `${PIPESTATUS[0]}` where the plain command would do.** Covered in full by *A pipe
  hides the exit status* below, including why the expansion prompts and what to reach for instead.
  The trap specific to this section is applying that apparatus to output that needed no filtering
  at all — five lines through `tail -5`, and a status probe for a command whose status a bare run
  reports by itself.
- **A test-name filter written in regex the shell claims first.** An unquoted `-i
  /expired_token|refunds_none|which_charges/` is read as a three-segment pipeline before anything
  runs, so it fails at `refunds_none: command not found` — and the gate, which evaluates each segment
  separately (`settings.md`), then offers a standing allow-list entry for two "commands" that are
  regex fragments. That is what earns the rule: the failure is self-correcting, the grant is not. In
  the approval dialog it reads as an ordinary unfamiliar tool, which is the dialog-legibility half of
  `RTK.md`'s bare-`:` trap without its hazard — that entry silently grants truncation of any file,
  where this one can never fire and is simply dead weight competing with real rules for attention.
  Alternation and grouping are exactly the characters the shell takes for itself (`|`, `(`, `)`, `*`,
  `?`, `>`, `&`), so quote the filter or drop it. Dropping it is usually the answer: one such filter
  selected 2 of 43 tests in a file that runs in under two seconds, so running the whole file was
  simpler, faster, and verified more.

  **Double quotes are not the fix for a backtick or a `$`.** They stop the characters above and
  leave command substitution and expansion live, so a grep pattern written to find a markdown
  literal — ``"`term`\|\bterm\b"`` — reaches the gate as an attempt to run `term` as a command, and
  the prompt offers a standing grant for it. That grant is the dead-weight kind rather than the
  dangerous kind, since no such command exists, but it reads in the dialog exactly like a real
  tool. Observed once, on a command that also carried a pipe — so the per-segment split is what
  surfaced the inner word as a command name, and a substitution standing alone may instead behave
  as `settings.md` describes and offer nothing at all.

  Read that pattern again, though, because the quoting is the second mistake. `\bterm\b` already
  matches inside `` `term` `` — a backtick is not a word character — so the first alternative was
  redundant before any shell saw it. That is the usual shape of this: the backtick gets reached for
  to be precise about markdown, beside a word-boundary match that already covers the case. Drop the
  alternative rather than single-quoting it, and keep single quotes for a pattern that genuinely
  needs a `$` or a backtick.

The tell in each case: the part that trips the gate is not the work, it is the scaffolding. Before
adding a construct, ask what breaks if it is simply left out. Usually nothing — an unfiltered run
of a short command, or a plain invocation that respects the rule rather than policing it.

**Two of these shapes are gated:** `hooks/shell-machinery-guard.sh` blocks a function definition and
an assignment-plus-separator with exit 2 and a pointer back here. Its header enumerates what each
half knowingly over-blocks — read it before working around a block that looks wrong. The rest stay
prose-only, and the invented leading command cannot be gated at all, since the binary resolves and
only its subcommand is fabricated. Reading the first segment before sending is the only check there
is.

Failure mode this prevents: scaffolding added out of diligence converts an invisible call into a
permission prompt, and the prompt arrives attached to a command whose actual work needed no
approval — so it reads as a gap in the allow list rather than as a self-inflicted one, and the fix
that suggests itself is a new allowlist entry for a construct that can never be granted.

## Don't escape inside single-quoted heredocs

In a `<<'EOF'` heredoc (single-quoted delimiter), the shell preserves content literally — no parameter expansion, no command substitution, no backslash processing. Backticks, double-quotes, and dollar signs inside one don't need escaping. Doing so ships the literal backslash through to whatever consumes the heredoc.

**How to apply:** When writing inside `<<'EOF'`, write content as-is. The single-quoted delimiter is the explicit "treat this as a string literal" signal, so escaping inside it always overshoots. If you find yourself reaching for a backslash inside a heredoc, check the opening — if it's `'EOF'`, don't. (The same caution applies in reverse to `<<EOF` without quotes, where backticks and dollar signs *do* need escaping if you want them literal.)

## Batch repeated commands by repeating them literally, not with a loop variable

When running the same command over several files, write the calls out — `rtk read a.json && rtk read b.json` — or issue them as separate tool calls in one message. Do not wrap them in a `for f in …; do … "$f"; done`. The gate flags the loop by its construct, reporting `Contains for_statement`, and that check reads the statement type rather than anything inside the body — so a batch that would otherwise pass silently prompts instead, and rewriting the loop to carry no `$f` buys nothing. The loop is also the more fragile form: one unquoted expansion or a filename holding a space and the whole batch breaks.

`for_statement` joins `simple_expansion` (`settings.md`) and `function_definition` (`agents.md`) as parser-node names the gate reports as its reason. None of the three can be allowlisted, so in each case the fix is to write a different command rather than to add an entry.

The pull toward the loop is real — it looks like the tidier way to avoid repeating yourself, and it saves round-trips against an interactive prompt where a human is typing. Neither applies to a programmatically issued command, which pays nothing for the repetition and pays an approval for the construct. Same fix as the `cat "$(ls …)"` slip in `RTK.md`: resolve the paths first, then name them literally.

Failure mode this prevents: a read-only batch that should have been invisible interrupts the user for approval, and does it at exactly the moment the work is meant to be running unattended.

## Invoke a project script by the relative path its allow rule names

Run `bin/rubocop`, `scripts/report.sh`, `bash scripts/floor.sh` — not the absolute path to the same file. Allow rules match the literal command string, so a grant written as `Bash(bash scripts/floor.sh)` does not cover `bash /Users/…/project/scripts/floor.sh`: same script, same effect, different string, and the gate asks. The absolute form is the natural reach right after working in another directory or reading a path out of a tool result, which is when it slips in. The shell's cwd is the project root and stays there, so the relative form always resolves.

`agents.md` carries the same constraint for sub-agent prompts, which is where it bites hardest.

Failure mode this prevents: a routine, already-granted command interrupts the user for approval, and because the command is *correct* the prompt reads as a gap in the allow list rather than as a slip in how the command was written — so the fix attempted is a new allowlist entry that duplicates the one already there.

## Let the script's own header pick the runner

Before running a script, read its opening lines for the runner it declares. A PEP 723 `# /// script` block with a `dependencies` list means `uv run`, a shebang names its interpreter, and a docstring `Usage:` line often states the invocation outright. Reaching for `python3` on a PEP 723 script fails at the first import of a declared dependency, and the allow rule that would have covered it names `uv run`, because that is the form the script was written for.

The wrong runner costs twice over. It is un-granted, so it interrupts for approval, and it is non-functional, so the interruption buys a `ModuleNotFoundError`. The prompt arrives first, so it reads as a missing allowlist entry, and the fix that suggests itself is granting a form that can never succeed.

## A malformed path won't error in Write the way it does in the shell — verify where it landed

File tools take absolute paths. Build each one clean from the project root. Don't splice a `../` segment into the middle. Such a path resolves differently depending on who handles it, and Write is the permissive one:

- **The shell and filesystem resolve `..` against real directories.** `a/b/../c` requires `a/b` to exist — if it doesn't, the command errors. A garbled path passed to `ls`, `cat`, or `rtk read` fails loudly, catching the mistake.
- **Write normalizes `..` lexically, then creates parents.** It collapses `b/..` as text without checking `a/b` exists, then `mkdir -p`'s the result. A garble the filesystem would reject instead resolves to a *different* real location, gets a full directory tree built there, and returns success — nothing pushes back at write time.

So Write offers *less* protection than a shell command here, not more. After writing to any path you assembled rather than copied verbatim from a known-good source, confirm it landed where intended — a quick `ls` of the expected path — instead of trusting the success message.

**How to apply:** build file-tool paths as clean absolutes from the project root, no `..` segments. Treat a mid-path `..` as a signal to re-derive, not submit. After any assembled Write, `ls` the location — Write's success confirms *a* write happened, not that it happened where you meant.

## Copy off-disk state before overwriting it when a pending decision depends on it

Before overwriting or discarding on-disk-only state — uncommitted working-tree changes, gitignored or untracked files, scratch output — that an open decision or a proposed next step depends on, save a copy aside first. Git won't recover it: `git checkout` / `cp`-to-restore reflexes assume the thing being clobbered lives in history, and this state doesn't. The sharpest trigger is overwriting the very artifact an option *you just proposed* would need — that action quietly voids your own proposal.

This is not an always-do. Routine overwrites of regenerable or uninteresting files need no copy. It fires only when the on-disk-only state is load-bearing for a comparison or decision in play.

**How to apply:** when about to overwrite or discard uncommitted/untracked/scratch state, ask whether any decision currently in play — especially an option you just offered — would want to read that exact state later. If yes, copy it to a scratch path first (project `tmp/`, the session scratchpad).

## A pipe hides the exit status of the command you actually care about

In `cmd | grep …`, the shell reports **grep's** status, not `cmd`'s. So `cmd | grep -E "pass|fail" && git commit` commits whenever grep matched a line — including a line that says the run failed. The filter that made the output readable is the same thing that made the gate meaningless.

It bites hardest where the piped command *is* the verification — a test suite, a linter, a CI script, a build. Those are exactly the commands worth piping, since their output is long and only a few lines matter.

**How to apply:** when a command's exit status is load-bearing — anything gating a commit, a claim that a suite passed, or a decision about what to do next — don't pipe it. Never chain `&&` off a pipeline whose first element is the thing being tested.

Reach for a wrapper that filters *without* a pipe, so there is no second status to confuse: `rtk test <cmd>` shows only failures plus the tail of the output, and `rtk err <cmd>` shows only errors and warnings. Both propagate the wrapped command's status in each direction, so `rtk test bin/ci && …` gates on the suite rather than on a filter. Redirecting to a file and reading it afterwards has the same property, at the cost of a second step — and it is the form to reach for when an argument has to contain spaces, since `rtk test` re-parses its command and a quoted argument arrives at the wrapped command split into one entry per word (`RTK.md`).

**Then don't pipe the wrapper either.** `rtk test bin/ci | rtk tail -10` hands back the exact problem the wrapper was reached for: the pipeline reports the filter's status, and the propagation that made `rtk test` the right answer is gone. The pull is that the wrapper still prints a header and a couple of trailing lines, so trimming them reads as tidiness rather than as discarding an exit status — which is what carries it past a rule written about `proxy | tail`. The wrapper has already filtered. Take its output whole, and read a `| tail` or `| head` on a command chosen for its exit status as the tell.

Reserve `${PIPESTATUS[0]}` for a pipeline that genuinely cannot be replaced, and expect it to interrupt: it is an expansion, so the permission gate cannot resolve it and has to ask.

Failure mode this prevents: a red test run reads as green because the summary grep matched, the `&&` behind it fires anyway, and nothing in the visible output contradicts the report that says verified. Piping the wrapper fails one step later and more quietly: the status is simply absent rather than wrong, so the next move is to go hunting for a pass/fail signal in the log the wrapper had already summarized — and that hunt is where scaffolding gets built, for a question that was answered before the pipe was added.

## Don't merge stderr into a file you intend to parse

`cmd > out.log 2>&1` puts the error channel *inside the artifact*. When the command fails, the file is neither absent nor empty — it holds a short error message, which is a perfectly plausible-looking file. Every grep against it then returns a confident negative about *content*, when the fact to report is that the command failed.

Reproduced here: `ls <nonexistent> > merged.txt 2>&1` exited 1 and left 59 bytes of error text, while `ls <nonexistent> > clean.txt` exited 1 and left the file at 0 bytes with the error on the terminal where it belonged. The failure is loud in the second form and invisible in the first, and nothing about the first form's output says which happened.

**How to apply:** redirect stdout alone when capturing data to parse — a downloaded log, an API response, a generated fixture — and check the exit status. Reserve `2>&1` for capturing a transcript somebody is going to read, where interleaving the two channels is the point. Then run `wc -c` on the artifact before grepping it: a payload that should be hundreds of kilobytes arriving at a hundred bytes settles the question at once, and that evidence is usually in hand several commands before anyone looks at it.

This does not retract the `2>&1` suggestion in `RTK.md`'s empty-`gh`-result guidance. That one is about making output *visible* in the terminal, where merging the channels surfaces a message that would otherwise be lost. Keep the two uses apart by purpose — `2>&1` to see something, stdout alone to store something.

Failure mode this prevents: a failed fetch becomes a small file of error text rather than no file at all, and the greps that follow report findings about content the artifact never held. The command's exit status said so at the time, and the redirect is what made it easy not to look.

## Reverting a file discards every uncommitted change in it, not just the one you meant

`git checkout -- <file>` and `git restore <file>` take the file back to the index or HEAD wholesale. When a file carries deliberate uncommitted work *and* something temporary — a planted test case, a debug line, a probe — reverting to undo the temporary part silently destroys the deliberate part too. Git offers no partial undo here and reports nothing, because discarding is exactly what was asked for.

**How to apply:** remove the temporary edit the way you added it — with Edit, targeting the exact text — rather than reverting the file. Reach for `git checkout --` only when the file holds nothing you want to keep. When unsure whether it does, `git diff -- <file>` before discarding, which is cheap next to reconstructing lost work from memory.

Failure mode this prevents: a revert aimed at a two-line probe takes an hour of unrelated editing with it, and because the command succeeded exactly as documented, the loss surfaces later rather than at the moment it happened.

## An Edit revert and its restore have to cover the same span

The section above sends a temporary change back out with Edit rather than `git checkout`, and that is right. The trap sits on that path: an Edit pair meant to be inverse round-trips only when both operate on the *same span*. Where the revert's `old_string` covers less than the restore's `new_string` puts back, every cycle nets the difference.

The standing case is a comment. Reverting a modified line by matching the line alone leaves the comment above it untouched, and restoring by writing comment-plus-line back adds a copy that was never removed. Two red/green cycles later the file carries the comment three times over one line of code. Both Edits reported success, correctly — each matched exactly what it was told to match.

**Nothing catches it.** A test suite is silent by construction about text carrying no behaviour, so the run stays green through every cycle — and green is the signal being watched, because observing the red/green transition is the entire point of the exercise. The suite is not a weak detector here, it is an incapable one — a full run, however many times it is repeated, says nothing whatever about the file's state.

The exposure scales with rigour: reverting code to observe an honest red is what test-first asks for when the code got written first, so the more faithfully the discipline runs, the more cycles execute and the more copies stack up.

**How to apply:** make the revert's match cover everything the restore will write back — the comment, the blank line, the whole hunk — so the two are genuine inverses. Then read the region back once the cycle finishes, rather than inferring its state from a green suite.

## Reproduce anchor lines byte-for-byte in an Edit

An Edit's `old_string` often extends past the text being changed to reach a unique match, pulling in a neighboring line as an anchor. Reproduce every such anchor byte-for-byte in `new_string` — trailing spaces, tabs-vs-spaces, and all. Prefer ending the match at a line boundary over cutting mid-line, since a partial trailing line is where the whitespace slip happens.

Edit reports success on any exact match, so a mangled anchor never surfaces as an error, and whether the damage shows depends entirely on the target format's tolerance. Git config trims whitespace around `=`, so clipping the trailing space off `logg = log --graph …` left the alias working and the edit looking clean; Makefiles, YAML, Python, and heredocs would each have broken instead.

**Dropping an anchor entirely does surface, in the commit's own stat line.** Where the anchor was a whole line — a heading, a closing brace — omitting it from `new_string` deletes it, and `git show --stat` then reports a deletion on a change that should have been purely additive. So read any deletion count on an insertion as the tell, and check it before the commit rather than after. This is the one variant the diff can catch, which matters because the *reparenting* it causes cannot be seen there at all: every line that changed owner is byte-identical (see *Inserting a block into markdown reparents what follows it* above).

**How to apply:** when `old_string` includes a line you aren't changing, copy it into `new_string` rather than retyping it. After editing a whitespace-sensitive format, read back the lines adjacent to the change, not just the changed ones.

Failure mode this prevents: an edit silently alters a line it was never meant to touch, and nothing in the diff marks it as unintentional — or, in a tolerant format, it is never noticed and ships as an unexplained whitespace diff in an otherwise focused commit.

## Inserting a block into markdown reparents what follows it

Markdown has no closing tags, so a heading owns everything down to the next heading of equal or higher level. Insert an `###` after a `##` section's opening prose and every remaining paragraph in that section becomes its content, including examples that were illustrating something else. Inserting a paragraph does the smaller version of this: a sentence that closed the previous block ends up closing the new one instead.

The damage occupies no diff lines. `git diff` reports only the insertion, and every reparented line is byte-identical, so reviewing the diff — the obvious check, and the one most likely to be run — cannot reveal it.

**How to apply:** after inserting a block, read forward from it to the next heading of the same or higher level and ask whether that content still belongs under what it now sits beneath. When it doesn't, placing the new block at the *end* of the section usually fixes it without rewording anything.

Failure mode this prevents: a section's worth of established guidance is silently re-scoped under a narrow new subheading. Because nothing about that guidance changed, it survives review and reads as deliberate to every reader afterward.

## Stop a backgrounded command once its output has been read

A foreground command that exceeds its timeout is moved to the background, and its output goes on accruing to a file. Reading that file is what answers the question — and it is also the last moment anything will draw attention to the task, because a process that never exits never sends the completion notification that would. So the task can outlive the work it was part of by hours while every visible sign says the work is done.

Some commands simply do not exit. A CLI that forks a detached update-check or telemetry child hands that child the pipeline's stdout, so the shell waits on a descriptor nobody will ever close, long after all four segments of a compound command have printed. Nothing errors, and the output file looks complete because it is.

**How to apply:** when a backgrounded command's output has been read and the answer taken from it, stop the task (`TaskStop`) rather than leaving it. Where the command really is still working, *Distinguish "in progress" from "failed"* in `diagnosis.md` governs first — this is for the case where the output is complete and only the process is left.

Failure mode this prevents: an orphaned shell holds a process tree for hours, and the user is the one who finds it — auditing leftovers they never created, in a task list where the stale entries hide the genuinely running one.
