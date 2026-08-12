# Tool and Shell Safety

Operating the shell and the file tools without silent mishaps — commands that trip an approval prompt, heredocs that ship stray escapes, writes that land somewhere other than intended, and destructive overwrites that can't be undone.

## Don't reflexively `cd` into the working directory

The Bash working directory is set to the project root at session start and persists across calls. Do not prefix commands with `cd /path/to/project` — it is unnecessary, and a `cd` combined with output redirection (`cd ... 2>/dev/null; <command>`) trips a security approval rule ("path resolution bypass"), forcing the user to manually approve every such command.

**Why:** the reflex tends to appear after working across multiple directories in one session (e.g. the project plus `~/.claude`), out of a wish to "be sure" of the cwd. But Read/Edit on a file elsewhere does not change the shell's cwd, and tool calls don't drift it. The `cd` adds nothing and costs an approval each time. This has recurred across sessions.

**A subtler consequence — silent wrong output, no approval prompt:** a `cd` into a *subdirectory of the project* (not just an unrelated dir) persists across calls the same way, and cwd-dependent tools then act on the wrong location without erroring — e.g. a handoff script writing relative to `os.getcwd()` lands its output in a subtree that the `SessionStart` hook and `list_handoffs.py` never scan (they see only the root), so nothing errors and the mistake is visible only by reading the tool's output path. This is distinct from the redirect/approval consequence above: that one is loud (an approval prompt), this one is silent.

**How to apply:** run commands directly — cwd is already the project root. If a command genuinely needs a different directory, pass it explicitly (`git -C <path>`, an absolute path) rather than `cd`-ing, and never combine `cd` with output redirection. This holds for project subdirectories too — a `cd` into `skills/` or `docs/` persists and will misdirect any cwd-relative tool (handoff scripts, generators, anything calling `getcwd`). When a tool's output lands somewhere unexpected, check `pwd` before assuming the tool is wrong.

**Now gated:** `hooks/reflexive-cd-guard.sh` blocks both hazard shapes with exit 2 and a pointer back here, so this prose is the discoverable *why* while the gate steers toward `git -C`, an absolute path, or a reverting subshell. It deliberately lets several `cd` forms through, including the ones that can strand the cwd elsewhere — blocking the way back would have the guard trap the drift it exists to warn about. `rules/references/tool-and-shell-safety/cd-guard.md` has the full blocked-and-allowed breakdown; load it when the guard fires on a command that looks legitimate, or before changing the hook.

## Don't add shell machinery the task didn't ask for

Write the command the work needs and nothing around it. The machinery bolted on out of diligence —
a guard, a status probe, a filter — is where the approval prompts come from, because the constructs
it is built out of are the ones the gate cannot resolve. Three instances, all real:

- **A function definition to enforce a rule on yourself.** Never open a command with `cd() { return
  1; }` or any other shadow of a command a rule forbids. Comply by writing the command without the
  forbidden form. The guard defeats itself: the gate reports `function_definition` (see *Batch
  repeated commands* below), that node cannot be allowlisted, so a read-only `grep` or `curl` stops
  for approval. Shadowing a command is also how one gets broken for real. `agents.md` documents
  this slip in the *sub-agent* direction, as something a flatly-phrased "never `cd`" provokes in a
  delegate; it applies at least as much here, where the rule is in context and visible. An
  always-loaded prohibition is a reason to write a different command, never a mandate to build a
  mechanism that blocks it — and the `cd` rule already has `hooks/reflexive-cd-guard.sh`, so
  enforcement is the hook's job.
- **A function definition for no reason at all.** The case above at least has an argument behind it.
  This one has none: a stray `for_each() { :; };` or `cd() { :; };` in front of an ordinary `grep`,
  defining something nothing calls, enforcing nothing, doing nothing. It costs exactly what the
  deliberate version costs, because the gate reads the statement type rather than the intent —
  `function_definition`, unallowlistable, and a read-only search stops for approval. So read what
  sits in front of a command's first real word before sending it, and delete anything there that is
  not part of the work. Having done it once is reason to check the next few commands rather than to
  call it a one-off: the shape recurs within a session, and because it has no motive there is nothing
  to notice yourself talking into.
- **A pipe plus `${PIPESTATUS[0]}` where the plain command would do.** Covered in full by *A pipe
  hides the exit status* below, including why the expansion prompts and what to reach for instead.
  The trap specific to this section is applying that apparatus to output that needed no filtering
  at all — five lines through `tail -5`, and a status probe for a command whose status a bare run
  reports by itself.

The tell in each case: the part that trips the gate is not the work, it is the scaffolding. Before
adding a construct, ask what breaks if it is simply left out. Usually nothing — an unfiltered run
of a short command, or a plain invocation that respects the rule rather than policing it.

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

The pull toward the loop is real — it looks like the tidier way to avoid repeating yourself, and it saves round-trips against an interactive prompt where a human is typing. Neither applies to a programmatically issued command, which pays nothing for the repetition and pays an approval for the construct. Cousin of the `cat "$(ls …)"` slip in `RTK.md`, with the same fix — resolve the paths first, then name them literally — though not the same root: that one prompts because an argument resolves only at runtime, this one because of the shape of the statement wrapping it.

Failure mode this prevents: a read-only batch that should have been invisible interrupts the user for approval, and does it at exactly the moment the work is meant to be running unattended.

## Invoke a project script by the relative path its allow rule names

Run `bin/rubocop`, `scripts/report.sh`, `bash scripts/floor.sh` — not the absolute path to the same file. Allow rules match the literal command string, so a grant written as `Bash(bash scripts/floor.sh)` does not cover `bash /Users/…/project/scripts/floor.sh`: same script, same effect, different string, and the gate asks. The absolute form is the natural reach right after working in another directory or reading a path out of a tool result, which is when it slips in. The shell's cwd is the project root and stays there, so the relative form always resolves.

A companion to the two entries above it: those keep a dynamic argument out of the command so the gate can resolve it, this keeps the command name in the form the gate already knows. `agents.md` carries the same constraint for sub-agent prompts, which is where it bites hardest — but it applies to a command issued from here first.

Failure mode this prevents: a routine, already-granted command interrupts the user for approval, and because the command is *correct* the prompt reads as a gap in the allow list rather than as a slip in how the command was written — so the fix attempted is a new allowlist entry that duplicates the one already there.

## Let the script's own header pick the runner

Before running a script, read its opening lines for the runner it declares. A PEP 723 `# /// script` block with a `dependencies` list means `uv run`, a shebang names its interpreter, and a docstring `Usage:` line often states the invocation outright. Reaching for `python3` on a PEP 723 script fails at the first import of a declared dependency, and the allow rule that would have covered it names `uv run`, because that is the form the script was written for.

The wrong runner costs twice over. It is un-granted, so it interrupts for approval, and it is non-functional, so the interruption buys a `ModuleNotFoundError`. The prompt arrives first, which is what makes this worth a rule — it reads as a missing allowlist entry, and the fix that suggests itself is granting the broken form, an entry that can never succeed and that sits in the list competing for attention with the working one.

Sibling of the section above. That one keeps the *path* in the form the gate already knows, this one the *runner*. Same literal-string match, except here the script itself is the authority on which string is right.

## A malformed path won't error in Write the way it does in the shell — verify where it landed

File tools take absolute paths. Build each one clean from the project root. Don't splice a `../` segment into the middle. Such a path resolves differently depending on who handles it, and Write is the permissive one:

- **The shell and filesystem resolve `..` against real directories.** `a/b/../c` requires `a/b` to exist — if it doesn't, the command errors. A garbled path passed to `ls`, `cat`, or `rtk read` fails loudly, catching the mistake.
- **Write normalizes `..` lexically, then creates parents.** It collapses `b/..` as text without checking `a/b` exists, then `mkdir -p`'s the result. A garble the filesystem would reject instead resolves to a *different* real location, gets a full directory tree built there, and returns success — nothing pushes back at write time.

So Write offers *less* protection than a shell command here, not more. After writing to any path you assembled rather than copied verbatim from a known-good source, confirm it landed where intended — a quick `ls` of the expected path — instead of trusting the success message.

**How to apply:** build file-tool paths as clean absolutes from the project root, no `..` segments. Treat a mid-path `..` as a signal to re-derive, not submit. After any assembled Write, `ls` the location — Write's success confirms *a* write happened, not that it happened where you meant.

## Copy off-disk state before overwriting it when a pending decision depends on it

Before overwriting or discarding on-disk-only state — uncommitted working-tree changes, gitignored or untracked files, scratch output — that an open decision or a proposed next step depends on, save a copy aside first. Git won't recover it: `git checkout` / `cp`-to-restore reflexes assume the thing being clobbered lives in history, and this state doesn't. The sharpest trigger is overwriting the very artifact an option *you just proposed* would need — that action quietly voids your own proposal.

This is not an always-do. Routine overwrites of regenerable or uninteresting files need no copy. It fires only when the on-disk-only state is load-bearing for a comparison or decision in play.

**How to apply:** when about to overwrite or discard uncommitted/untracked/scratch state, ask whether any decision currently in play — especially an option you just offered — would want to read that exact state later. If yes, copy it to a scratch path first (project `tmp/`, the session scratchpad). This composes with `honesty.md`'s *Surface Doubts Your Own Correction Reveals* — both catch an action that undermines a position you just took. That rule catches it in prose, this one catches it in a destructive file operation.

## A pipe hides the exit status of the command you actually care about

In `cmd | grep …`, the shell reports **grep's** status, not `cmd`'s. So `cmd | grep -E "pass|fail" && git commit` commits whenever grep matched a line — including a line that says the run failed. The filter that made the output readable is the same thing that made the gate meaningless.

It bites hardest where the piped command *is* the verification — a test suite, a linter, a CI script, a build. Those are exactly the commands worth piping, since their output is long and only a few lines matter.

**How to apply:** when a command's exit status is load-bearing — anything gating a commit, a claim that a suite passed, or a decision about what to do next — don't pipe it. Never chain `&&` off a pipeline whose first element is the thing being tested.

Reach for a wrapper that filters *without* a pipe, so there is no second status to confuse: `rtk test <cmd>` shows only failures plus the tail of the output, and `rtk err <cmd>` shows only errors and warnings. Both propagate the wrapped command's status in each direction, so `rtk test bin/ci && …` gates on the suite rather than on a filter. Redirecting to a file and reading it afterwards has the same property, at the cost of a second step.

Reserve `${PIPESTATUS[0]}` for a pipeline that genuinely cannot be replaced, and expect it to interrupt: it is an expansion, so the permission gate cannot resolve it and has to ask — see *Batch repeated commands by repeating them literally* above for the same mechanism. Prescribing it as the default trades a silent wrong answer for a prompt on every verification run, which is why it sits last here rather than first.

Failure mode this prevents: a red test run reads as green because the summary grep matched, the `&&` behind it fires anyway, and nothing in the visible output contradicts the report that says verified. This is `honesty.md`'s *Never Present Estimates as Measurements* arriving through a shell mechanism rather than a reasoning one.

## Reverting a file discards every uncommitted change in it, not just the one you meant

`git checkout -- <file>` and `git restore <file>` take the file back to the index or HEAD wholesale. When a file carries deliberate uncommitted work *and* something temporary — a planted test case, a debug line, a probe — reverting to undo the temporary part silently destroys the deliberate part too. Git offers no partial undo here and reports nothing, because discarding is exactly what was asked for.

**How to apply:** remove the temporary edit the way you added it — with Edit, targeting the exact text — rather than reverting the file. Reach for `git checkout --` only when the file holds nothing you want to keep. When unsure whether it does, `git diff -- <file>` before discarding, which is cheap next to reconstructing lost work from memory.

Failure mode this prevents: a revert aimed at a two-line probe takes an hour of unrelated editing with it, and because the command succeeded exactly as documented, the loss surfaces later — when the missing work is noticed downstream — rather than at the moment it happened. Sibling of the section above it: that one is about state a *pending decision* needs, this one about state you simply had not committed yet.
