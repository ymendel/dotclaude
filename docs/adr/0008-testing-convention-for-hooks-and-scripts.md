# ADR 0008: Testing Convention for Hooks and Scripts

**Date:** 2026-08-17
**Status:** Proposed

## Context

Most of this repo is prose meant to be loaded into a model's context — rule
files, skills, `CLAUDE.md`. Prose is checked by reading it, and a mistake in it
is visible to whoever reads it next. But a growing minority of the repo is code
that runs: `PreToolUse` and `PostToolUse` hooks that fire on every matching tool
call, top-level scripts run by hand, and Python validators and generators
shipped inside skills. Code is wrong in ways nobody reads, and the hooks in
particular are wrong in ways nobody *can* read, because they run between the
model's intent and the tool call and produce no output when they pass.

The question of whether that code should be tested was raised on 2026-07-20 and
deliberately parked. It came from noticing that one skill, `session-handoff`,
shipped pytest tests for its scripts while nothing else in the repo was tested
at all. The parking note sharpened the premise before deferring it: that skill
is not tested *because it has scripts*, but because its scripts are logic-dense
and produce durable artifacts that are painful to get wrong. The generalization
worth having is **complexity × blast radius × how silently it fails**, not "has
a script."

What made the question answerable was not a decision but an accumulation. Two
hooks acquired test cases over the following month, and the harness question —
framed at the time as the real blocker, bats versus driving bash from pytest —
answered itself in practice before anyone chose. Nobody weighed plain bash
against a framework and picked bash. Plain bash kept being what got written.

Three suites exist across two repos, and the relationship between them is worth
stating precisely, because it is the whole evidentiary basis for the harness
decision below. Two are in the sibling dotfiles repo: `demo/test/run-checks.sh`
(28 cases, introduced in "add a demo topic to repair and extend demo-magic") and
`shell/test/run-checks.sh` (9 cases, at "count local branch commits against the
main branch", still unmerged). Those two share a *verbatim* helper signature
comment, `# check <label> <expected> <actual>`, and a verbatim rationale comment
for omitting `set -e`. Same author, same repo, days apart — so they are one
design applied to two units, not two independent arrivals at it.

The third, this repo's `hooks/test/run-checks.sh`, was written by a different
session against a different kind of unit, and it is independent: its signature is
`check <guard-script> <label> <expected-exit> <command-string>`, and it carries
two further helpers (`check_at`, `says`) that the dotfiles suites have no need
for. So the honest count is two independent arrivals rather than three — and the
second one *diverged where the units differed* while keeping the shape. That is a
better argument for the shape than three identical copies would have been, since
it shows the design survives adaptation instead of only replication.

Those units now bracket a real range, which is what makes a repo-wide rule
writable rather than an extrapolation from one file:

- `shell-machinery-guard.sh` is pure text in, exit code out. No filesystem, no
  settings, no environment. Its cases need no fixtures whatsoever.
- `reflexive-cd-guard.sh` resolves physical paths against the real filesystem,
  reads `permissions.additionalDirectories` from three separate settings files,
  and honours an environment variable the tool payload does not carry. Its cases
  need temporary directories created and removed, which is the first thing in
  this repo to want setup and teardown rather than pure invoke-and-check.
- `check-prerequisites.sh` acquired a deliberate exit-code contract on
  2026-08-17, and it is the shape whose green run proves least: on a fully
  provisioned machine every branch that matters is unreachable, so the run has
  to be made against synthesised conditions or it asserts nothing.

Writing a convention from any one of those would have described that one's
needs and called them the rule.

Two lessons the tested units produced are constraints on any bar this ADR
picks. The first is that **a guard's message is part of its contract.** When the
reflexive-cd guard gained its recovery carve-out, the message "you are already
at the project root" became untrue whenever the shell had drifted — while the
guard still blocked correctly from a drifted cwd. Same exit 2, same PASS, wrong
explanation. A guard's entire value is the message it prints, because the reader
of that message is its only consumer, so an exit-code-only harness is blind to
the defect that matters most.

The second is that **a harness inherits nothing from the fail-open posture of
the thing it tests.** Every hook here passes through with exit 0 when `jq` is
absent, deliberately: a guard that cannot parse its input must not block the
command it was handed. A harness asserting exit codes against those guards
therefore reports PASS on every allow-case it holds, on a machine with no `jq`
— a green run testing nothing. The suite has to fail loudly on the very
dependency the code under test is designed to tolerate.

The cost of continuing not to decide is concrete and has a name.
`reflexive-cd-guard.sh` is 290 lines and has been through five rounds of scope
change, each arriving with new cases, and each re-verified by hand-recreating a
scratch script from a working note. That cost was paid repeatedly, by one file,
because nothing said when a test was owed.

The inventory as it actually stands, counted 2026-09-11:

| Group | Files | Lines | Files with any test |
|---|---|---|---|
| `hooks/` | 8 | 782 | 2 |
| `scripts/` top level | 9 | 1412 | 0 |
| Skill validators and generators | 4 | 1327 | 0 |
| `session-handoff/scripts/` | 5 | 1374 | 4 |

The counts are stated with a date because every previously written version of
this inventory was wrong by the time anyone read it. The version written for the
first draft of this ADR recorded the reflexive-cd guard at 229 lines when it had
grown to 264, omitted two top-level scripts entirely, and treated
`session-handoff` as tested. Its successor, counted 2026-08-17, was correct that
day and understated `hooks/` by a file and 211 lines within the month. So any bar
keyed to an inventory has to assume the inventory is stale, which is the argument
for keying the bar to a property of the code instead.

The `session-handoff` row is the one worth reading twice. `check_staleness.py` —
408 lines, the second-largest script in that skill — has no pytest coverage at
all, while being documented in the skill's `SKILL.md`, listed in its script
table, and granted its own allowlist entry. It is thoroughly *described* and
entirely unchecked, and the only thing resembling a test is a manual checkbox in
an eval scenario.

The `hooks/` row grew by `context-usage-notice.sh`, a `Stop` hook added
2026-09-10 that reports context usage at band crossings. It is Tier 1 by the
definition below — it fires without being invoked and says nothing when it works
— and it shipped with a comment at line 38 recording that it has no coverage,
because the committed suite is scoped to `PreToolUse` Bash guards. That is the
ratchet's case arriving before the ratchet exists.

Three constraints apply regardless of which bar is chosen. `hooks/rtk-rewrite.sh`
is vendored from RTK and pinned by a checksum, so its behaviour is not this
repo's to guarantee and a test against it would break on every upstream update.
The existing pytest suite has exactly one working invocation, `uv run --with
pytest pytest`, because the system `python3` carries no pytest — which puts `uv`
on the path of anyone running the tests. And there is no runner: the two suites
that exist are invoked two different ways, neither discoverable from the other.

### Options

**1. Property tiering with a change ratchet (chosen).** Classify each executable
unit by the sharpened premise — complexity × blast radius × how silently it
fails — into a tier that says whether a test is owed. Separately, any unit in a
tier that owes tests gains cases the next time it is modified, whether or not it
has them today.

- *Pros:* The tier answers "does this deserve a test" on a property of the code
  rather than on whoever last had an opinion, and it puts the automatically-firing
  silent-failure units at the top where the argument is strongest. The ratchet
  answers the question the tier cannot, which is *when* — the five-widening
  history of one guard is a case where the tier was obviously satisfied and the
  work still never got scheduled. The two compose: the tier says what is owed,
  the ratchet says when it comes due, and neither has to carry the other's job.
  Existing untested code is not retroactively a defect, so the convention can be
  adopted without a backlog attached to it.
- *Cons:* Two mechanisms to remember rather than one, and the tiering is a
  judgment call per unit rather than a mechanical test. The ratchet also fires on
  the *modifier's* schedule, so a unit nobody touches keeps its exemption
  indefinitely — which is the intended trade, but it means the largest untested
  files stay untested precisely because they are stable.

**2. Test everything executable.** Every hook, script, and validator in the repo
owes a suite.

- *Pros:* Needs no per-unit judgment, so it cannot be gamed by assigning a
  convenient tier to something inconvenient to test, and a reader never has to
  work out which bucket a new file falls into. It is also the only option whose
  compliance is mechanically checkable in one pass.
- *Cons:* Roughly 4,400 lines across 23 files, most of which is either trivial
  (`notify-config-update.sh` is 4 lines) or vendored and not ours to guarantee.
  A rule that classifies a 4-line wrapper alongside a 596-line validator is
  ceremony, and a bar nobody can meet is a bar nobody consults. Rejected because
  the uniformity buys nothing the tiering does not, and costs a backlog that
  would make the convention read as aspirational from the day it landed.

**3. Keep it ad hoc — test what hurts, no standing rule.** Continue as the repo
has been: a suite appears when someone is bitten badly enough.

- *Pros:* Zero ceremony, and it is honest about how the two existing suites
  actually came about. Nothing is owed, so nothing is overdue.
- *Cons:* This is the status quo whose cost prompted the ADR. Its observed
  outcome is one hook absorbing five rounds of manual re-verification while six
  others stayed untouched, and a 408-line script sitting untested inside the one
  skill everybody believed was covered. The failure is not that the wrong things
  got tested — it is that nothing recorded what was owed, so the answer was
  re-derived from scratch each time and twice came out wrong. Rejected.

### Harness and layout (sub-decision)

Which harness the tests use sits on a distinct axis from the bar above — it is
*how* a suite is written, not which units owe one.

**A. bats, or another bash test framework.** Adopt a framework for the bash side
and write suites as framework files.

- *Pros:* Standard vocabulary, familiar structure, and assertion helpers that do
  not have to be written.
- *Cons:* Adds a dependency to a repo whose whole point is portable
  configuration, for a benefit the three converged suites demonstrably did not
  need. It would also be a fourth prerequisite tier entry, and one whose absence
  silently turns testing off.

**Rejected:** the framework's value is assertion plumbing that ~30 lines of
plain bash already provides, against a new dependency the repo would have to
declare and check for.

**B. Drive everything from pytest via subprocess.** One language for all suites,
invoking the bash units as subprocesses.

- *Pros:* A single runner and a single reporting format across both languages.
- *Cons:* Puts every bash test behind `uv` and pytest, so a hook suite cannot be
  run on a machine that only has bash. It also inverts the natural fidelity: a
  hook is invoked with a synthesised payload on stdin, which bash constructs
  directly and Python has to marshal.

**Rejected:** it makes the cheapest-to-test units depend on the heaviest
toolchain in the repo.

**C. Plain bash per topic, pytest where the code is already Python (chosen).**
A bash suite is an executable `<topic>/test/run-checks.sh` with a local
`check`-style helper and no framework. Python code keeps pytest. Neither side
gains a dependency it does not already have.

- *Pros:* This is what two independent arrivals already produced, across two
  repos and three differently-shaped units, and the second one adapted the shape
  rather than copying it — which is a stronger argument than any comparison made
  in advance. The layout matches the per-topic convention already
  in use rather than inventing a dotclaude-specific one, and the allowlist
  `.gitignore` already tracks the path through `!/hooks/**/*`, so no config change
  is needed to add a suite. A bash suite runs anywhere bash and `jq` run.
- *Cons:* Two reporting formats and two invocations, which is what the entry
  point below exists to paper over. Shared helpers have no home yet — both
  guards' cases live in one file partly because that is where the helpers are, so
  splitting per guard later means deciding where they go.

### Single entry point (sub-decision)

**A. Defer it, as the sibling repo did.** Leave each suite invoked on its own
terms until there are enough of them to generalise from.

- *Pros:* Consistent with the reasoning that deferred it elsewhere, where two
  suites was judged a thin basis for a convention.
- *Cons:* The two suites here are not the two suites there. These are in
  different languages with different runners, one of which needs `uv`, and
  neither is discoverable from the other. That is the case an entry point solves,
  not the case for waiting.

**Rejected:** the ratchet above requires being able to run everything before a
change lands, and there is currently no command that does.

**B. A single entry point now (chosen).** One script that finds and runs every
suite, reporting a combined result and a non-zero exit if any suite fails.

- *Pros:* Makes the ratchet actionable — "gains cases the next time it is
  modified" needs one command that proves the rest still passes. Discovers new
  suites by convention rather than by registration, so adding a topic's tests
  requires no edit anywhere else. It is also the only place the `uv` dependency
  has to be named.
- *Cons:* One more script to maintain, and it has to propagate failure without a
  pipe, which is a real constraint rather than a detail — a filtered suite whose
  status is read from the filter is exactly the trap the repo's own rules warn
  about.

### Ratchet enforcement (sub-decision)

The bar above is a constraint on behaviour, and this repo already has a policy
for where those live. [ADR 0004](0004-rule-vs-hook-enforcement-split.md) asks one
question — could a script recognise a violation without judgment? — and a change
that stages `hooks/uv-run-guard.sh` without staging any test path answers yes.
The staged file list settles it, with no judgment required. So leaving the ratchet
in prose would be this repo declining its own test.

**A. Prose only, enforced by review.** State the ratchet in a rule file and rely
on it firing.

- *Pros:* No mechanism to build, and discoverable by reading `rules/`.
- *Cons:* Passively-loaded prose does not reliably fire during fast-moving work,
  which is the finding ADR 0004 exists to record. It is also the exact class of
  constraint that ADR names as gateable, so choosing prose here would need an
  argument this ADR does not have.

**Rejected:** ADR 0004's test returns "gateable" and nothing about this case is
the exception.

**B. A git `pre-commit` hook, installed by the Makefile.** Check the staged set on
every commit, whoever makes it.

- *Pros:* Catches the author's own commits as well as the model's, which is
  strictly more coverage. Installation is a genuine make target, since symlinking
  a hook into `.git/hooks` is making something rather than running a task.
- *Cons:* Fires on the owner's own commits, which converts a mechanism built to
  catch the model's reflex into a constraint on the person who chose to adopt it.
  It also needs an install step, so a fresh clone is unprotected until `make`
  runs, and there is no equivalent of the model's approval prompt to explain
  itself when it blocks.

**Rejected:** the extra coverage is over the one committer who does not need it,
at the cost of gating the owner.

**C. A `PreToolUse` hook on the commit command (chosen).** Parse the staged path
list when a `git commit` is about to run, and block with exit 2 when a Tier 1 or
Tier 2 source path is staged and no corresponding test path is.

- *Pros:* Uses the mechanism ADR 0004 established and this repo already runs
  several of, so it needs no install step and no new concept. It gates the model,
  which is where the evidence points — the guard that absorbed five widenings did
  so across sessions, and `shell-machinery-guard.sh` was written because its
  prose had been bypassed four times in two sessions. The escape hatch requires no design: a change that
  genuinely needs no test is one the author commits from their own terminal, so a
  false positive costs a sentence rather than a bypass flag.
- *Cons:* Only sees commits made through the tool, so it is a partial gate by
  construction. It also needs the tier assignments in a form a script can read,
  which turns the tiers from prose into config and creates a second place they
  can drift from this ADR.

## Decision

Adopt a two-part bar. A unit's **tier** says whether tests are owed, and the
**ratchet** says when they come due.

Tiers are assigned by the sharpened premise — complexity, blast radius, and how
silently the unit fails:

- **Tier 1, tests owed.** Anything that fires automatically without being
  invoked, and anything that is dense deterministic input-to-output logic. This
  is the hooks this repo owns, and the skill validators. The argument is
  strongest here because a hook's failure mode is silence: it runs between intent
  and execution, and a hook that has stopped working looks exactly like a hook
  with nothing to say.
- **Tier 2, situational.** Units with real consequences on failure that are run
  deliberately by a human who sees the outcome — `sync-skill.sh`, which copies
  over files, and `init_skill.py`, which generates a tree. A human at the
  keyboard is a weak check but not no check.
- **Tier 3, exempt.** Thin wrappers with too little logic to carry a test, and
  vendored code. `hooks/rtk-rewrite.sh` is exempt by construction: it is pinned
  by checksum and overwritten on upstream update, so its behaviour is not ours to
  guarantee and a test against it would break on someone else's schedule.

The ratchet: **a Tier 1 or Tier 2 unit gains test cases in the same change that
modifies it.** Existing untested code is not retroactively a defect — the
convention creates no backlog. What it forbids is the sixth widening of a unit
that has already had five, verified by a script recreated from a note.

The ratchet is enforced by a gate, not by this prose. A new `PreToolUse` hook
inspects the staged path list when a `git commit` is about to run and blocks with
exit 2 when a Tier 1 or Tier 2 source path is staged with no test path alongside
it. Tier membership therefore has to be readable by a script, so the hook carries
the tier lists the way `check-prerequisites.sh` carries its prerequisite tiers —
as arrays, kept in agreement with this ADR by nothing but attention. The gate sees
only commits made through the tool, which makes committing from a terminal the
escape hatch for a change that genuinely owes no test.

Suites are written as follows. A bash suite is an executable
`<topic>/test/run-checks.sh` with local `check`-style helpers — the committed one
has three, differing in what a case needs to supply — no framework, and no
`set -e`, since a failing case must report and let the rest run. Python code
keeps pytest, under the topic's own `tests/`. Two rules apply to both, and both
were learned the hard way rather than reasoned out:

- **Assert on the human-readable output where the output is the product.** A
  guard's message is part of its contract, so a suite asserting only exit codes
  is incomplete for anything whose consumer reads what it prints. This extends to
  the validators' diagnostics.
- **A suite must fail loudly when its own instrument is missing.** Where the code
  under test is designed to pass through on a missing dependency, the suite
  testing it must not inherit that posture. A `jq`-dependent suite exits non-zero
  with a message rather than reporting passes it never earned.

Add `scripts/run-tests.sh` as the single entry point. It discovers every
`*/test/run-checks.sh` and every topic `tests/` directory by convention rather
than by a registered list, runs each, and exits non-zero if any suite fails. It
must not read a suite's status through a pipe. Where `uv` is absent it exits
non-zero rather than skipping the Python half, by the same rule as any other
suite: a runner that reports success over a suite it could not execute is worse
than one that refuses.

Finally, **`uv` moves from optional to load-bearing.** It was listed as optional
on the reasoning that only skill authoring goes through it, and that was already
wrong before this ADR: `ascii-diagram-validator` declares
`allowed-tools: Bash(uv run *)` and fires on description-match during ordinary
work, so `uv`'s absence breaks a skill any session can invoke. The test suite
adds a second such path — the existing pytest suite has exactly one working
invocation and it runs through `uv`, since the system `python3` carries no
pytest.

Load-bearing rather than required, because the tiers are keyed to *whose* path an
absence sits on, and the required tier's contract is an exit 1 from
`scripts/check-prerequisites.sh`. Someone who clones this config to borrow rules
and skills should not be told their machine is broken over a tool they need only
for the suite. Load-bearing states the dependency honestly and leaves the exit
code at 0. The safety the required tier would have bought is already specified
above: `run-tests.sh` refuses to run rather than skipping the Python half, which
catches the one reader who actually needs catching at the moment they need it.
The README ledger and `scripts/check-prerequisites.sh` both change.

What this ADR deliberately does not settle: whether the hook suite eventually
splits per guard and where shared helpers live if it does, and whether the
`additionalDirectories` coverage gap in the reflexive-cd guard is worth the
throwaway project fixture it needs. Both are open, and neither blocks the
convention.

## Consequences

- **Positive:** "Does this need a test?" has an answer that does not depend on
  who is asking or how recently something broke. The tier is a property of the
  code, so it survives the inventory going stale — which it demonstrably does.

- **Positive:** The ratchet puts the cost where the change is. A unit being
  modified is a unit somebody already has in their head, which is the cheapest
  possible moment to write its cases and the moment the five-widening history
  kept passing up.

- **Positive:** A single entry point makes "everything still passes" one command
  rather than two invocations a reader has to know about, one of which needs a
  tool the ledger mis-tiered until this decision.

- **Positive:** Gating the ratchet rather than writing it down means the
  convention does not depend on being remembered mid-change, which is the whole
  finding ADR 0004 records. It also means this ADR's own bar is applied to itself:
  a behavioural constraint that a script can check is not left in prose.

- **Neutral:** The harness decision ratifies what already happened rather than
  choosing it. Two independent arrivals is the strongest evidence available here,
  and it is also the weakest kind of decision to record, since nothing was
  actually at stake by the time it was written down.

- **Neutral:** The gate is partial by construction. It sees commits made through
  the tool and not those made from a terminal, which is deliberate — it makes the
  owner the escape hatch — but it means the ratchet's coverage depends on who is
  committing rather than on what is being committed.

- **Neutral:** Tier assignment is a judgment call per unit. The three tiers name
  the axis rather than mechanising it, so two readers could reasonably place
  `usage-report.sh` differently.

- **Negative:** The ratchet exempts stable code permanently. `check_ascii_alignment.py`
  is 596 lines of Tier 1 logic and will stay untested for as long as nobody edits
  it, which is likely to be a long time precisely because it works. The
  convention makes this visible rather than fixing it, and a reader should not
  mistake "no tests" for "not owed."

- **Neutral:** The `uv` tier move records a dependency that already existed
  rather than creating one. A borrower's exit code is unchanged, and the tool was
  needed by `ascii-diagram-validator` before this decision was written — the
  ledger simply said otherwise. What the move costs is that `uv` now appears
  alongside RTK and `gh` as something the config assumes, which is a fair
  description of a repo whose skills shell out to it.

- **Negative:** The tier lists now exist twice — as prose in this ADR and as
  arrays in the gate hook — with nothing keeping them in agreement. This is the
  same drift hazard the prerequisite ledger already carries between the README and
  `check-prerequisites.sh`, knowingly repeated, and it is worse here because a
  stale tier list in the gate fails silently in the permissive direction: a unit
  dropped from the array simply stops being gated.

- **Negative:** Two reporting formats remain. The entry point aggregates exit
  codes, not output, so a combined run prints one suite's PASS lines and
  another's pytest dots. Anyone reading a failure still has to know which half of
  the repo they are in.

- **Negative:** The convention adds a step to every future hook or validator
  change, including small ones. The ratchet has no size exemption, and its
  absence is what would let it be ignored — so the cost is real and lands on
  changes that would previously have been one edit.

## References

- [ADR 0004](0004-rule-vs-hook-enforcement-split.md) — the rule-versus-hook
  split that produced both tested guards, and the reason hooks exist as an
  enforcement mechanism at all
- [ADR 0003](0003-allowlist-gitignore.md) — the allowlist `.gitignore` whose
  `!/hooks/**/*` re-inclusion already tracks the suite path, so adding a bash
  suite needs no ignore change
- [ADR 0007](0007-progressive-disclosure-for-rules.md) — the sub-decision
  precedent this ADR's three option lists follow, and the routing policy that
  keeps the dated counts above out of always-loaded rule prose
- `hooks/test/run-checks.sh` — the committed suite over both guards, and the
  reference implementation of the `check`-style shape
- The sibling dotfiles repo's two suites, read for this decision:
  `demo/test/run-checks.sh` from "add a demo topic to repair and extend
  demo-magic", and `shell/test/run-checks.sh` from "count local branch commits
  against the main branch", the latter still on an unmerged branch. Cited by
  commit subject because a bare SHA does not survive a rebase and the paths are
  not reachable from this repo.
- `skills/session-handoff/tests/` — the pytest precedent that prompted the
  original question
- `notes/testing-hooks-and-scripts.md` — the working note this decision is drawn
  from, including the three convergences and the two hard-won suite rules
- `README.md` and `scripts/check-prerequisites.sh` — the prerequisite ledger and
  check whose `uv` tier this decision changes
