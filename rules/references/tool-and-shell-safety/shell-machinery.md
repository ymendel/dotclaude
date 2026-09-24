# Shell machinery — the mechanism behind each shape

Companion to `tool-and-shell-safety.md`'s *Don't add shell machinery the task didn't ask for*, which
carries the directive and the tells. This carries what each shape actually does to the permission
gate, which is what you want when a block or a prompt looks wrong rather than when you are about to
write a command. Read it before changing `hooks/shell-machinery-guard.sh`.

## A function definition, deliberate or motiveless

The gate reports `function_definition` (one of the parser-node names it names as its reason, alongside
`for_statement` and `simple_expansion`). That node cannot be allowlisted, so a read-only `grep` or
`curl` stops for approval. The check reads the statement type rather than the intent, which is why the
motiveless form — a stray `for_each() { :; };` defining something nothing calls — costs exactly what a
deliberate guard costs.

Shadowing a command is also how one gets broken for real. An always-loaded prohibition is a reason to
write a different command, never a mandate to build a mechanism that blocks it, and the `cd` rule
already has `hooks/reflexive-cd-guard.sh`.

Having done the motiveless version once is reason to check the next few commands rather than to call
it a one-off. The shape recurs within a session, and because it has no motive there is nothing to
notice yourself talking into.

## An invented command with its error suppressed

`rtk provoke 2>/dev/null;` ahead of an ordinary `grep` names a subcommand that does not exist. Nothing
is enforced and nothing is called, and unlike the function form there is no gate to stop it — the only
thing that would have surfaced it is the error, and the `2>/dev/null` threw that away. Exit 127 and a
`No such file or directory` were both available and both discarded.

What makes this the harder half to catch is that the command *works*. The real segment runs, the output
looks right, and no gate can help: the leading command resolves fine, since only its subcommand is
invented, so a does-this-binary-exist check never fires. The stray segment is visible only to someone
reading the command string rather than its result, and that reader is the user.

The narrower, checkable rule is about which segment gets the suppression. On the working segment it is
often deliberate. On scaffolding it can only ever hide the evidence that the scaffolding is there.

## A command substitution that cannot produce output

`rtk grep -n 'runs,|failures' "$(rtk ls -t "$LOGDIR" | rtk head -1 > /dev/null; echo)"` greps a log for
a test count, which is an ordinary thing to want — so nothing reads as scaffolding until you look
inside the `$( )`, where the body pipes its result into `/dev/null` and then `echo`s nothing.

A substitution is empty when *every* output-producing command in it has had stdout taken away, which is
what `> /dev/null` did here. The trailing `echo` contributes nothing either way, and reading it as the
cause is the specific mistake: a bare `echo` prints blank, so it looks like it empties whatever it
ends. It does not, because it is not the only thing in there — `$(printf hello; echo)` returns
`hello`. Read a bare `echo` at the end as a tell that somebody was reaching for something, never as a
guarantee. `2>/dev/null` is a different thing again and usually right, since it discards the error
channel and leaves the value alone.

The prompt is no help. A substitution is a `command_substitution` node the gate cannot resolve
(`settings.md`), so it asks about every substitution alike and says nothing about this one being empty.

Two faults travelled together in the observed case, and the second is the general check: the command
carried a trailing `; rtk ls "$LOGDIR"` that nothing upstream depended on, which means it was two
commands rather than one. A later segment that does not use an earlier one is the tell. Underneath
both, the result being hunted for had already been reported by the command run just before —
`searching.md`'s *Don't search for what you already have*, in its shell-rediscovery spelling.

## A variable assignment, and the three detectors around it

`REF=origin/main; git show $REF:lib/parser.rb` reads as the tidy way to run three commands against one
ref. The expansion alone would prompt, but an **unquoted** variable followed by `:` or `[` is refused
for a sharper reason, reported verbatim as `zsh $name[expr] / $name:mod in bare concatenation —
recursive eval`. zsh reads those as subscript and modifier syntax that can expand to something
evaluated again, and the analyzer checks that reading rather than the shell actually running — so the
prompt fires on a bash session where the string is inert concatenation, and in an ordinary command
rather than only inside `[[ ]]`. A ref-and-path argument is precisely that shape.

**The motiveless variant is gated.** A `for_check=""; rtk wc -l file` assigns a name nothing
references. `hooks/shell-machinery-guard.sh` blocks an assignment followed by a separator, covering
both variants. It deliberately leaves the *prefix* form `FOO=bar cmd` alone, since that scopes the
variable to one command and is ordinary shell — a separator terminating the value is the whole
distinction.

**The prefix form clears the guard and still costs a prompt**, so passing is not a recommendation. An
allow rule is anchored on the command name, and the assignment makes the string stop starting with
`rtk`, so `Bash(rtk ls:*)` no longer matches — the same mechanism that makes a `GIT_SEQUENCE_EDITOR=…`
prefix the sole reason its command asks. Observed on a `FOO=bar rtk ls dir/ | rtk head -3`. Blocking it
would be the wrong instrument, since that is the allowlist's business rather than a guard's, but there
is no reason to reach for it either.

The motiveless form costs no approval prompt of its own — a plain assignment is auto-approved, so
nothing interrupts and nothing errors, and the only reader who sees it is whoever reads the command
string. That silence is why it is gated.

**A redirect target is checked by a second, separate detector**, so the `:`-and-`[` mechanism is not
the boundary. `> $S/pages-build.md` is refused as ``Redirect target concatenation contains $/` —
unanalyzable gap or substitution``, which fires on an unescaped `$` or backtick anywhere in the target
and on nothing else. Expect to want the variable here — the Bash tool asks for absolute paths,
absolute paths are long, and a variable is the obvious way to make them tolerable — and write the path
out anyway. `notes/claude-code-quirks.md` carries the generating code and why that message is a legend
rather than a quotation.

## A regex filter the shell claims first

An unquoted `-i /expired_token|refunds_none|which_charges/` is read as a three-segment pipeline before
anything runs, so it fails at `refunds_none: command not found` — and the gate, which evaluates each
segment separately (`settings.md`), then offers a standing allow-list entry for two "commands" that
are regex fragments. That is what earns the rule: the failure is self-correcting, the grant is not. In
the approval dialog it reads as an ordinary unfamiliar tool, which is the dialog-legibility half of
`RTK.md`'s bare-`:` trap without its hazard — that entry silently grants truncation of any file, where
this one can never fire and is simply dead weight competing with real rules for attention.

Dropping the filter is usually the answer rather than quoting it: one such filter selected 2 of 43
tests in a file that runs in under two seconds, so running the whole file was simpler, faster, and
verified more.

**Double quotes are not the fix for a backtick or a `$`.** They stop the shell's own characters and
leave command substitution and expansion live, so a grep pattern written to find a markdown literal —
``"`term`\|\bterm\b"`` — reaches the gate as an attempt to run `term` as a command, and the prompt
offers a standing grant for it. That grant is the dead-weight kind rather than the dangerous kind,
since no such command exists, but it reads in the dialog exactly like a real tool. Observed once, on a
command that also carried a pipe — so the per-segment split is what surfaced the inner word as a
command name, and a substitution standing alone may instead behave as `settings.md` describes and
offer nothing at all.

Read that pattern again, though, because the quoting is the second mistake. `\bterm\b` already matches
inside `` `term` `` — a backtick is not a word character — so the first alternative was redundant
before any shell saw it. That is the usual shape: the backtick gets reached for to be precise about
markdown, beside a word-boundary match that already covers the case. Drop the alternative rather than
single-quoting it, and keep single quotes for a pattern that genuinely needs a `$` or a backtick.
