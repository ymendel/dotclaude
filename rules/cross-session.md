# Working Across Sessions

Several Claude sessions run at once, in different repos and on different machines, and they cannot
read each other's transcripts. That one fact drives everything here: what an instruction to "tell"
another session means, where a decision has to be written so the other side finds it, and how a
message that arrived whole in your context has to be relayed to a user who saw a preview of it.

Handing a *rule edit* to a session in the config tree has its own protocol, in
`references/rule-maintenance/cross-session-handover.md`.

## "Tell <name>" means message that session

When the user says "tell dotclaude", "let rails-template know", "ask <name>" — where the name is a
session rather than a person — that is an instruction to send a cross-session message. `ListAgents`
resolves the name, `SendMessage` delivers it. It is not an instruction to record anything.

The tell is that session names are usually repo names, since sessions get named after the work — so
"tell dotclaude" parses cleanly as "file this in the dotclaude config", and the edit that follows
looks like compliance. A name matching a repo is still a session name in this construction. Resolve
it before deciding, and where `ListAgents` shows no such session, say so and ask: a filing nobody
requested is worse than a no-op.

Failure mode this prevents: the message is never sent, the session it was meant for carries on
without it, and the user finds out only if they go looking. Meanwhile something lands in a rule file
on the strength of an instruction that was never about rules.

## Ask the session that owns a repo before reading it from outside

When a question turns on the state of a repo another live session is working in — whether its work
has landed, what a config file there now says — check `ListAgents` and ask that session before
fetching the files yourself through `gh api`, a raw URL, or a path into its tree. It can read its own
`main`, knows what is merged versus merely local, and can say what it did not check. A fetch from
outside sees only what was pushed, and none of the context around it.

The reach for the fetch is strong because it looks like the self-sufficient move, and the tool to do
it is already at hand. Reserve it for when no session owns the repo, or the owner has said it cannot
answer.

Failure mode this prevents: the answer comes back stripped of what the owning session would have
said with it — that a branch was squashed, that a claim was left unchecked — and the user has to
interrupt to redirect the question to the session that was sitting there idle.

## Write a settled call into the artifact, not only into the message that reports it

A decision taken in one session is invisible everywhere else until something durable carries it. A
message does not: it is point-to-point, arrives once, and the party who most needs the decision is
often not the party who was messaged. **When a call gets settled, write it where the other side
reads** — a PR description, an ADR, an issue body, a comment beside the code. Announcing it in a
message as well is fine; that is not the record.

**The claim half, which is the easier slip.** Not having received an answer is not the same as the
question being unanswered, and only the first is knowable from inside one session. Report "I have
not had an answer on X" rather than "X is still open" — the second is a claim about somebody else's
state, unverifiable from here and wrong in precisely the case that matters, where the call was made
out of view. Both are equally actionable, so the accurate one costs nothing.

When a peer's report and yours disagree about whether something is open, the side that made the call
is authoritative, and the artifact is what should have said so.

Failure mode this prevents: a question ricochets between sessions with the answer already in hand on
one of them, and the user is asked to re-decide something they decided — which reads as not having
been listened to. Worse, a confident "still open" gets acted on as a status, so work is planned
around a decision point that closed some time ago.

## A handover message is prose somebody else will commit

`references/rule-maintenance/cross-session-handover.md` tells the receiver to check a handed-over
edit's claims before staging. It says nothing to the sender, who is the one party that had the
evidence in front of them. Close it from this side: every claim in a handover has to survive that
check, because the words land in a commit under a byline that is not yours.

Make the case. That is what the message is for, and a receiver cannot route an edit they have only
been told the shape of. What must not ride along is force the evidence does not carry. An argument
for an edit pulls toward the flat quantifier — *will* rather than *can*, *at least as often as*, a
mechanism called blind to a case it merely handles poorly. None of those is the argument, and
striking them costs the argument nothing.

It evades the writing rules because a message reads as conversation while it is underway.
`writing.md`'s chat exemption covers replies to the user and not this — a handover becomes byline
output the moment the receiver commits it verbatim.

Failure mode this prevents: the receiver's claims check is the only control on the channel, so a
careful receiver spends the turn stripping quantifiers and a hurried one commits them into a public
repo. Both outcomes were avoidable by the only party who knew what the evidence was.

## Don't relay a peer message as though the user already read it

A cross-session message lands whole in your context and thinly in the user's — recent builds
collapse it to a one-line preview whose full text sits behind `Ctrl+O`, and even displayed in full
it arrives mid-work, in a conversation the user is reading rather than watching. Assume they have
not read it. The relay is the first and only telling.

**Carry the substance, not the citation.** "The `widget-api` session finished the schema migration"
informs. "I heard from `widget-api`" attributes and informs nobody. Attribution is worth one clause,
never the whole sentence.

**Restate on a later reference.** "As that session mentioned" points at something that may never
have rendered. Name the claim again rather than pointing back at it.

**Mark a relayed claim as the sender's, and as of when.** It is a copy of something somebody else
owns and can revise, and nothing in the relay marks it provisional. Say whose it is and when it
arrived, so a later correction reads as replacing a dated claim rather than contradicting a bare
one.

Failure mode this prevents: several messages arrive across a session, each gets relayed accurately
in passing, and the user afterwards asks whether anything came in at all — having read every reply
and retained none of the content. Nothing in the transcript looks wrong, so the gap surfaces only
when they happen to ask.
