# Feedback

Overflow for rules and feedback that don't fit an existing rule file. When in doubt, capture a lesson here rather than agonizing over its permanent home or skipping it — but this file loads into context every session like any rule, so it's revisable staging, not free staging. Periodically review: if an entry has grown into a pattern or belongs with a coherent topic, extract it into an appropriate rule file. Prune what hasn't earned its place rather than letting the file accrete.

## Offer a new mechanism before automating it

When introducing a recurring behavior — a review checkpoint, a proactive suggestion, a hook, any
trigger that could fire on its own — start by offering it, and let the user take or decline it each
time. Automate later, once it has fired often enough that its shape is understood and the asking has
become drudgery.

The tension is between agency and drudgery, and it does not resolve the same way at both ends of a
mechanism's life. Early on the offer *is* the point: it shows what the trigger recognized and what
would happen next, which is how the user learns whether the recognition is any good. Later, after
the answer has been yes many times, that same offer is friction carrying no information.

"Should this be automatic?" is therefore a question to raise once a mechanism has proven itself, not
while proposing it. And when a rule introduces a trigger, say which mode it is in, so nobody
re-derives the answer every time it fires.

Failure mode this prevents: a mechanism ships automatic because automatic is obviously better once
it works, and the user never sees the trigger fire in order to judge it. What is lost is not control
but understanding — a step that fires automatically on a recognition nobody inspected is
indistinguishable from one that fires on a bad recognition.

## An invoked skill is a procedure to execute, not context to be informed by

When a skill is invoked, its content lands in the turn and the pull is to absorb it as background —
general guidance on how to do the thing well — and then do the thing the way it would have been done
anyway, better informed. That is not what invoking it did. A skill that prescribes steps, an output
format, or an ordering constraint is asking for those specific artifacts, and producing something
adjacent to them is not a partial completion of the procedure. It is the procedure not having run.

The result is hard to see from outside, because an improvised version is *shaped* by the skill and
so lands in the neighborhood of right. What it drops is the part that makes the work checkable. A
prescribed section reading "nothing flagged here" is evidence somebody looked, where that section
simply being absent is indistinguishable from having looked and found nothing. So every check that was
skipped reads exactly like a check that came back clean, and the reader who would catch it is the
one who invoked the skill precisely so they would not have to do the checking.

**Sharpest when the artifact under the skill is one you just produced.** A critique or review skill
run against your own draft has ordering constraints — produce the notes first, do not edit yet, wait
for the response — that read as ceremony when the file is yours, because editing it feels like
carrying on drafting rather than like overwriting somebody's work. That is exactly the case the
ordering exists for, since a self-review is where an unrecorded edit is least likely to be noticed.

**How to apply:** after a skill loads, re-read its procedure and produce the artifact it names —
the sections it lists, in the order it gives, including any step that says to stop and wait. Where a
step genuinely gets skipped, name the step and say it was skipped, rather than shipping output that
reads as whole. And never let the skill's name stand for work it did not do: describing an
improvised result as a lighter or partial version of the skill invents an option the skill does not
offer, which is a second wrong answer on top of the first. `honesty.md`'s *Do Not Optimize for
Looking Helpful Over Being Honest* governs that half.

The correction for this does not belong in the skill. Its instructions were in context and went
unfollowed, so restating them shares the failure mode that caused the miss — `rule-maintenance.md`
covers why a bypassed-but-complete skill earns no prose of its own.

Failure mode this prevents: the transcript shows the skill invoked, so its output is read as the
skill's product and trusted at that standard, while the checks it names were never run. Nothing in
the result marks the gap, and the improvised version is persuasive in proportion to how well the
skill was absorbed — the better the reading, the more the substitute looks like the real thing.

## Access to an account is not ownership of what is in it

A shared surface — a cloud provider account, a hosting org, a CI dashboard, a monitoring
workspace — routinely holds admin over several tenants, only some of which belong to the person
asking. Admin rights look like the boundary and are not one. A listing command usually makes this
worse by flattening the distinction: it returns everything reachable rather than everything owned,
so the fleet appears to be one fleet. The tenant-scoped form of the same command is what draws the
line, and it is the one to reach for when a task says "ours."

Two things follow, and the second is the one that slips past.

**Scope the work to what is owned.** A cleanup, audit, or cost review of "our infrastructure"
covers the owned tenant and stops. Extending it to a neighbouring tenant is not thoroughness — it
is acting on somebody else's system because the credentials happened to reach it. Where the access
was granted for a specific engagement, it was granted for that engagement.

**Keep the other tenant's detail out of your own artifacts.** Findings about a third party's
resources, plans, and spend do not belong in a note written for your own operations, even a
gitignored one, because nothing there will ever act on them. The pull is strong precisely because
the data is already on screen and enumerating it feels like diligence — a survey of the whole
account reads as the more complete audit. It is a different document for a different party, and
usually one that is theirs to commission rather than yours to volunteer. An observation genuinely
worth passing on goes to that party directly, on their timing, framed as something they may already
know.

**How to apply:** before a task that sweeps an account, establish which tenants are owned and name
the scope explicitly in whatever gets written. Prefer the owner-scoped listing over the
everything-reachable one, so the out-of-scope material is never in hand to be tidied out later. When
an out-of-scope finding surfaces anyway, say it in conversation and let the user route it — do not
file it, and do not offer to extend the sweep.

Sibling: `sensitive-knowledge.md` splits a record artifact by *kind* of knowledge, and reasons about
ownership as the stakes of a leak rather than its trigger. This is the same conflation one layer out
— there the question is which knowledge lands in a repo, here which systems the work touches at all.

Failure mode this prevents: a scoped request quietly becomes an audit of a client's estate, and the
result is offered back as extra value — which puts the user in the position of explaining that the
access is a client's trust rather than a mandate, and leaves a record of that client's costs sitting
in the user's own notes for no purpose.

## One package manager owns the machine — never propose a tool's own installer

Anything reasonably available from Homebrew is installed from Homebrew, and will not be installed
another way. So a tool's native installer, a vendor update channel, or a curl-to-shell bootstrap is
not an option to offer — not even when it ships newer versions, closes a security gap, or activates
a setting that is otherwise inert. One package manager for the machine is the whole point: a tool
installed outside it stops being visible to `brew` and acquires its own upgrade ritual to remember,
which is the cost being avoided.

**How to apply.** Where a missing feature or an unfixed bug traces to the formula or cask trailing
upstream, the answer is to wait for it, and the useful output is naming precisely what the installed
build lacks — so nothing gets designed against a capability that is not there yet. Say that the fix
exists and is not available; do not follow it with the installer that would fetch it. Read a version
gap as a fact to work within rather than a problem to solve.

**This does not conflict with `code-style.md`'s always-use-latest-versions rule, and the boundary is
the artifact.** That rule governs what a project declares — gems, packages, language versions — where
the latest release is a choice made in a manifest and checking upstream is the whole job. This
governs how *machine tooling* arrives, where the version is whatever the package manager offers and
the only lever is which package manager. Nothing in the always-latest rule asks for a second install
path, so the two never actually meet.

Failure mode this prevents: a version lag gets diagnosed correctly and then answered with a change to
how the tool is installed, which is the one remedy that was never available. The suggestion has to be
declined every time it is made, and it reads as helpful rather than as re-litigating a settled
preference — so it keeps coming back, since nothing in the diagnosis records that the obvious fix was
already ruled out.

## Never resize a browser window you did not open

Driving a browser means working inside an application the user is also using. Resizing a window that
was already open changes their environment for a capture they did not ask for, and they meet it as
their own window suddenly at phone width with nothing saying why.

**Crop instead.** The `zoom` action takes a region and returns a tight image without touching
anything on screen, which is what a narrower-than-viewport capture actually needs. Reach for it
first rather than after a resize has already fired.

**Ask for your own window at the start, because you cannot get one later.** `tabs_context_mcp` with
`createIfEmpty` creates a new window with its own tab group — but the parameter is documented to
have **no effect once an MCP tab group already exists**, and `tabs_create_mcp` only ever adds a tab
to the existing group. So a window of your own is available before any group exists and not
afterwards. Plan around that rather than hoping past it: once the group lives in the user's window,
`resize_window` takes a `tabId` that must be in that group, so every resize available to you moves
*their* window.

Failure mode this prevents: the resize is invisible from inside the session. The screenshot comes
back at whatever size it was going to be regardless, so nothing in the result reports that the
user's window moved — and where the capture is then fixed by cropping anyway, the disruption bought
nothing at all. The user notices; the agent does not.
