# Diagnosis

## Diagnose before retrying

When a command fails **or gives unexpected output**, diagnose why before trying again. Retrying the same command (or minor variants) without understanding is a loop, not debugging. This applies equally to unexpected output — if a command succeeds but the output isn't what was expected, reason about why rather than issuing variations hoping for different results.

Specific case: `fatal: bad revision '<file>'` in git means git is interpreting a path as a tree-ish. Fix: use `--` to separate revisions from paths (`git diff HEAD -- <file>`).

Specific case: a command unexpectedly *denied* — most often a `git commit`, `echo`, or `grep` — may be tripping a deny rule on its *text* rather than its action. Deny patterns match the command string, so a message or argument that merely mentions a denied substring (a blocked git operation, a destructive flag) is denied even though the command does no such thing. Reword to drop the substring, or pass the text via a file (`git commit -F <file>`). See `settings.md` ("Deny Patterns Match the Command String").

Specific case: when RTK's diff output doesn't show a change that's known to exist, RTK filtered it (e.g., a single-line change inside a long string). Do not retry diff variants — switch to `git diff --cached` to check the index, or read the file directly. Retrying `git diff` with different flags will not produce different output through the same filter.

Specific case: when `git diff` output looks summarized or processed (a "Changes" header, no `+`/`-` lines, "No syntactic changes" for non-empty diffs), the user has an external diff tool configured via `diff.external`. Pass `--no-ext-diff` to `git diff` / `git show` / `git log -p` to get the standard unified diff. This is the right escape hatch — it's a documented git flag, not a workaround around the user's config. Don't reach for `/usr/bin/git` or shell out to `diff` directly.

Specific case: a permission-gate refusal that names characters is usually enumerating the class the analyzer rejects, not quoting what it found in the command. ``Redirect target concatenation contains $/` — unanalyzable gap or substitution`` fires on an unescaped `$` *or* a backtick, and the `/` is an "or" — so searching the command for a literal `$/` and a backtick finds nothing and reads as though the gate misfired. Before hunting for the characters a gate message shows, ask whether it is reporting the match or the class; only the first is checkable against what was run.

Related: when the command in question is asynchronous (a background Bash, a long-running task) and the symptom is *absent* output rather than wrong output, see "Distinguish 'in progress' from 'failed' before concluding failure" below — that case has its own diagnostic checks before reissuing.

## A parse error at the end of a pipe is usually the failure of the command at its start

A `--json` flag describes the *success* path. Most CLIs fall back to plain text on the error path — a
wrong app or project name, an expired credential, an unknown flag — so `<cmd> --json | jq …` hands jq
an English sentence, and jq reports what it honestly sees: `parse error: Invalid numeric literal at
line 1, column 6`. That message names jq, cites a column, and says nothing about the command that
actually failed, so the natural next move is to fix the jq expression — which cannot work, because
the expression was never the problem.

**How to apply:** when the last stage of a pipeline reports a parse or format error, re-run the first
stage alone before touching the parser. Its own error message is usually sitting there in plain text.
Reserve edits to the jq or parser expression for a case where the input is confirmed well-formed.

Worked example: `heroku config --app <name> --json | jq 'keys'` reported `Invalid numeric literal` at
column 6, and again at column 5 for a second app. Both app names were wrong; heroku printed a
plain-text "couldn't find that app" error and jq choked on its first letter. Nothing was wrong with
`keys`, and no amount of rewriting it would have helped.

Sibling: `tool-and-shell-safety.md`'s *A pipe hides the exit status of the command you actually care
about*. There the pipe hides a failure completely; here it relabels one as a different stage's fault.
Both are the pipe misattributing a result — which is the reason to suspect the pipe before suspecting
the stage the error names.

Failure mode this prevents: an upstream failure gets diagnosed as a malformed parser expression, so
the fixing effort lands on the one part of the pipeline that was working, and the real error — which
the tool had already printed in plain English — is never read.

## Validate a probe's detector before trusting its negative

When testing an unknown by observing a downstream signal — "is X loaded?" answered by "does Y appear?" — confirm the signal actually fires in a known-positive case before trusting a *negative* result. A null from an unvalidated detector can't distinguish "X is false" from "the detector would never have shown X anyway."

For example, probing whether a config file is read by setting an `env` var in it and checking `echo $VAR` in a fresh session yields an ambiguous UNSET — it can't distinguish "file not read" from "the env never reaches this shell." The fix is a positive control first: put the same `env` var in a known-read file — only if *that* shows up is a null from the unknown file meaningful.

Specific case — a permission prompt is invisible in tool output, so "I got output" is not a detector for "it didn't prompt." An auto-allowed command and a command the user approved at a prompt return byte-identical results — nothing in the tool output distinguishes the two. So when probing whether a config change (sandbox mode, an allowlist entry, a permission mode) *suppresses* a prompt, output-presence is an implicit detector that can never fire negative correctly — every "ran clean, no prompt" conclusion drawn from seeing output is void. The only reliable detector is the user reporting "prompted" or "ran clean," one command at a time. The trap is worse than an uncalibrated detector: here the detector is structurally incapable of detecting the thing, so no calibration exists — the signal has to come from the user.

Of the four possible outcomes only two leave a trace: a rejection errors in the tool result, and an approval that offered "don't ask again" writes an entry to the repo's `.claude/settings.local.json`. A plain "Yes" and an auto-allow leave nothing, which is the pair that matters. So a saved rule is a *one-way* detector — its presence proves a prompt happened and its shape shows what string the gate matched, its absence proves nothing. Read that file before theorizing about why a command didn't prompt, and keep any probe to a single command with no pipe, redirect, or substitution.

`rules/references/diagnosis/permission-prompt-probes.md` has the outcome breakdown, the matching skew in the user's own recollection, and why the single-command shape is what attributes cleanly. Load it before designing a probe of this kind.

Prefer the authoritative source when it can answer directly. The actual question here was settled by the docs (the scope table lists no user-level `settings.local.json`), which made the empirical probe both inconclusive *and* unnecessary. When docs or spec can answer, reach for them before an empirical probe whose detector you'd have to calibrate anyway.

Failure mode this prevents: reading a null result as a finding ("the file isn't read") when it only reflects an uncalibrated instrument — the quantitative-absence sibling of honesty.md's "Do Not Assert Absence Without Verifying."

## Distinguish "in progress" from "failed" before concluding failure

When a long-running command has been started in the background (or any task whose output arrives asynchronously), an empty output file is not evidence of failure — it's also consistent with "still running, output not flushed yet". Before declaring the run failed and reissuing it, check:

- The file's modification time. If it was created moments ago and the task is one that takes time, it almost certainly hasn't finished yet.
- The expected completion mechanism for the task. Background Bash calls emit a `task-notification` when they exit. The right move when uncertain is to wait for that notification (or use `Monitor` against the output file) rather than re-run.
- Whether the tool you reached for to "check status" actually applies. `TaskGet` is for the tracker — it returns "Task not found" for background Bash IDs regardless of whether the Bash task is running, finished, or never existed. A "not found" response from the wrong tool isn't a status signal.

Failure mode this prevents: a task that takes minutes (large remote API scan, long-running build, slow query) gets re-run because its empty intermediate output looked like failure. The re-run duplicates the cost — extra API calls, extra load on a remote system, duplicated wall-clock — and often finishes around the same time as the original, producing two identical results and revealing the diagnosis only in hindsight. This sits next to "Diagnose before retrying" above: that rule covers retrying a command whose output is *known* but wrong. This one covers reissuing a command whose output is *absent* in a way that's also consistent with not-done-yet.

## Don't route around the user's configuration

Reaching for `/bin/ls`, `/usr/bin/grep`, or similar absolute paths to sidestep aliases or shell configuration is a smell. The user's shell setup is intentional. Bypassing it produces output that doesn't reflect their environment, may evade allowlists (since the allowlist matches the literal command string), and signals that something else is off. If a command isn't behaving as expected, diagnose why — don't route around the user's configuration.

**A denied command is a decision, not an obstacle.** The strongest form of this is a `deny` entry in `settings.json`, and it is the one place where routing around is not a smell but a defeat of the thing itself. Deny patterns match the command *string*, so an equivalent spelling is always findable — `git update-ref -d refs/heads/spike` deletes a branch without ever matching `*git branch -D *`, and plumbing offers the same escape for most of the list. Never reach for one. When a command is denied, the action belongs to the user: say what would do it and stop.

Two things make this worse than the alias case above. It defeats a control deliberately rather than by inattention, and nothing in the result marks it as having happened — the command succeeds and reports what any other successful command reports. Per [ADR 0004](../docs/adr/0004-rule-vs-hook-enforcement-split.md), the deny list exists to catch the *reflex* form of a destructive action, and no pattern set can enumerate the equivalents. That gap is closed here or not at all.

Failure mode this prevents: the block reads as friction in the way of finishing the task, so the next command found is the one that gets past it — and the user discovers that their own guardrail was stepped over rather than respected, in a session where nothing looked wrong.

## Verify state at the layer that produces the behavior

When changing a configuration value, verify the layer that *produces* the runtime behavior reflects the change — not only the layer that *stores* it. Many systems keep the same state in two places: a durable backing store (a DB row, a config file) and a runtime cache, in-memory schedule, or pre-boot snapshot that mediates actual behavior. Updating the backing store is often necessary but not sufficient.

The failure mode: confirming the stored value "looks right" feels like verification but is a false-positive when the runtime layer hasn't re-read. The symptom shows up as "I changed X but nothing happened" — and re-changing X won't fix it. Check both the storage layer and the runtime side before concluding the change took effect or that the system is misbehaving.

Common cases where this trap shows up:

- Job schedulers with in-memory cron tables (Solid Queue dynamic recurring tasks, Sidekiq Cron, etc.) — the DB row updates without the running scheduler noticing.
- Caches (`Rails.cache`, Redis, fragment caches) — a record updates while a cached projection of it stays stale.
- ENV vars / platform config vars — most platforms apply changes on process or dyno restart, not immediately to running processes.
- Feature flag stores or configuration that snapshots at boot rather than re-reading at runtime.

## Pasted terminal output may be redacted — a placeholder credential inverts the apparent result

When the user pastes command output, secrets are often edited out before sharing — a real token replaced with a joke or placeholder value (`adtk_nicetry`, `adtk_nope`, `xxx`, `<token>`, `REDACTED`). Read a transparently-fake credential as a *redaction signal*, not as the literal value that ran. The trap is when the redacted credential flips what the output means: an obviously-fake token sitting next to a `200 OK` reads as "invalid token got through" (alarming) when the truth is "valid token was swapped out for the paste" (nothing wrong).

**Why:** the model over-indexes on the alarming status line and under-weights that the credential is plainly not real. A genuine invalid-token test uses a *plausible-but-wrong* value, not a pun. `nicetry`/`nope` are tells that the user substituted them.

**How to apply:** when a pasted result would be alarming *only if a specific credential in it were real*, and that credential looks placeholder/joke/redacted, ask the one-line question first — "did you redact those tokens?" — before mounting an expensive investigation (booting a repro server, a git-history dig). Still flag a genuinely alarming result (honesty.md's surface-doubts posture holds — don't stay silent on a possible auth bypass), but flag-and-ask is cheaper than flag-and-reproduce. This is the paste-redaction cousin of the "Validate a probe's detector" section above: here the "detector" is the pasted output, and a redacted value is a known way it lies.
