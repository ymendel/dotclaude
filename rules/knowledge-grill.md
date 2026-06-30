# Knowledge Grill

Companion rule for the `knowledge-grill` skill — the proactive half that the skill package cannot
carry. The skill extracts tacit knowledge from the holder of a system through a relentless backward
interview and routes it into durable artifacts; this rule decides *when to suggest running it*.

## Suggest the grill before the knowledge walks away

When an exit, handoff, or staffing change is on the horizon — not only at the moment it happens —
suggest a knowledge grill (the `knowledge-grill` skill) while the person who holds the context is
still available to be interviewed. Treat "on the horizon" generously: a planned departure weeks
out, a project winding down, a contributor rotating off, a codebase about to be handed to someone
new.

The value is highest *before* the holder is gone. A grill run after departure can only work from
what survived in the code and the docs — which is exactly the knowledge that was never written down,
the reason the grill was needed.

## Failure mode this prevents

The highest-stakes extraction is the one most likely to be deferred. Description-match alone fires
the skill only when the conversation is *already about* leaving; it does not look up and notice the
exit approaching. Without a rule that watches the horizon, tacit knowledge walks out the door
because the grill waited for someone to remember it, and by the time the handoff is written the
person who held the why is already gone.

## Scope of this version

This version carries one trigger: knowledge about to walk away. Other moments where a backward grill
pays off — recurring tricky work, deviation from established norms, repeated re-discovery — are
deliberately left out for now. See `skills/knowledge-grill/TODO.md` for those candidates and the
reasoning for deferring them.
