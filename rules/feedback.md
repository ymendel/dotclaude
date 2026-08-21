# Feedback

Overflow for rules and feedback that don't fit an existing rule file. When in doubt, capture a lesson here rather than agonizing over its permanent home or skipping it — but this file loads into context every session like any rule, so it's revisable staging, not free staging. Periodically review: if an entry has grown into a pattern or belongs with a coherent topic, extract it into an appropriate rule file. Prune what hasn't earned its place rather than letting the file accrete.

## Reproduce anchor lines byte-for-byte in an Edit

An Edit's `old_string` often extends past the text being changed to reach a unique match, pulling in
a neighboring line as an anchor. Reproduce every such anchor byte-for-byte in `new_string` —
trailing spaces, tabs-vs-spaces, and all. Prefer ending the match at a line boundary over cutting
mid-line, since a partial trailing line is where the whitespace slip happens.

Edit reports success on any exact match, so a mangled anchor never surfaces as an error, and whether
the damage shows depends entirely on the target format's tolerance. Git config trims whitespace
around `=`, so clipping the trailing space off `logg = log --graph …` left the alias working and the
edit looking clean; Makefiles, YAML, Python, and heredocs would each have broken instead.

**How to apply:** when `old_string` includes a line you aren't changing, copy it into `new_string`
rather than retyping it. After editing a whitespace-sensitive format, read back the lines adjacent to
the change, not just the changed ones.

Failure mode this prevents: an edit silently alters a line it was never meant to touch, and nothing
in the diff marks it as unintentional — or, in a tolerant format, it is never noticed and ships as an
unexplained whitespace diff in an otherwise focused commit.

## Inserting a block into markdown reparents what follows it

Markdown has no closing tags, so a heading owns everything down to the next heading of equal or
higher level. Insert an `###` after a `##` section's opening prose and every remaining paragraph in
that section becomes its content, including examples that were illustrating something else.
Inserting a paragraph does the smaller version of this: a sentence that closed the previous block
ends up closing the new one instead.

The damage occupies no diff lines. `git diff` reports only the insertion, and every reparented line
is byte-identical, so reviewing the diff — the obvious check, and the one most likely to be run —
cannot reveal it.

**How to apply:** after inserting a block, read forward from it to the next heading of the same or
higher level and ask whether that content still belongs under what it now sits beneath. When it
doesn't, placing the new block at the *end* of the section usually fixes it without rewording
anything. Sibling of the entry above: that one covers the text an Edit matches on, this one the text
after it, and in both the Edit reports success while the damage sits where nobody looked.

Failure mode this prevents: a section's worth of established guidance is silently re-scoped under a
narrow new subheading. Because nothing about that guidance changed, it survives review and reads as
deliberate to every reader afterward.

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

## Write a settled call into the artifact, not only into the message that reports it

When work is split across sessions — a peer session in another repo, a delegate, a colleague's
agent — none of them can read the others' transcripts. A decision taken in one is therefore
invisible everywhere else until something durable carries it. Messages do not carry it: they are
point-to-point, they arrive once, and the party who most needs the decision is often not the party
who was messaged.

So when a call gets settled, put it where the other side reads rather than where the other side was
told. A PR description, an ADR, an issue body, a comment in the code — any of them is a surface both
sides can consult unprompted and re-consult later. The message announcing the decision is fine, and
it is not the record.

**The claim half, which is the easier slip.** Not having received an answer is not the same as the
question being unanswered, and only the first is knowable from inside one session. Report "I have
not had an answer on X" rather than "X is still open" or "X is unanswered" — the second is a claim
about somebody else's state that cannot be checked from here, and it is wrong precisely in the case
that matters, where the decision was taken somewhere out of view. Both forms are equally actionable,
so the accurate one costs nothing. This is `honesty.md`'s *Do Not Assert Absence Without Verifying*
one scope out: there a partial search is read as a complete one, here an empty inbox is read as an
undecided question.

**How to apply:** when a decision is made, ask which artifact a reader would have to open to learn
it, and write it there in the same breath. When reporting status across a boundary, say what you
know — what you sent, what came back — rather than characterising the state of a question you can
only see one side of. When a peer's report and yours disagree about whether something is open, the
side that made the call is authoritative and the artifact is what should have said so.

Failure mode this prevents: a question ricochets between sessions with the answer already in hand on
one of them, and the user is asked to re-decide something they decided — which reads as not having
been listened to. Worse, a confident "still open" gets acted on as a status, so work is planned
around a decision point that closed some time ago.

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
