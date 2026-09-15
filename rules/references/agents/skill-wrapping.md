# Wrapping a Skill in an Agent So Its Library Can Be Dropped

Companion to `agents.md`'s *Delegate A Noisy Read Rather Than Loading It*. Load this when
authoring or fixing an agent definition that exists to carry a skill, or when deciding whether a
given skill is worth wrapping at all.

## The gap a wrapper closes

Once a skill has fired in-session its content cannot be delegated anywhere. An agent whose
`skills:` frontmatter names the skill closes that gap: the field preloads the skill's **full
content**, not its description, into the agent's context at spawn, so the reference library lands in
a window that ends when the agent returns.

`mermaid-diagram-specialist` is the standing instance — a definition whose body is little more than
"follow the `mermaid-diagrams` skill", against a skill package of 124K.

## Two arrangements, pointing opposite ways

Picking the wrong one produces an agent that returns nothing.

- **A skill that is reference material** — syntax tables, conventions, selection guidance — goes
  behind an agent that names it in `skills:`. The agent's body supplies the task, the skill supplies
  the knowledge.
- **A skill that is itself a task** — explicit steps to carry out — takes `context: fork` and needs
  no wrapper, because the skill content *becomes* the agent's prompt. Forking a guidelines-only
  skill hands the agent knowledge and no instruction, and it returns without meaningful output.

A forked skill can also name `agent: Explore`, which is the one way to run this shape without the
~70K hierarchy load, since Explore skips it.

## Nothing enforces the ordering

This is the real difficulty. A skill fires on description-match during a turn, so "diagram this" can
load the library into the main context before any delegation decision gets made — the exact cost the
wrapper exists to avoid.

No frontmatter field prevents it. `disable-model-invocation: true` stops a skill firing on its own,
but it also stops the skill being preloaded into an agent, which breaks the very wrapper it would be
protecting. So the ordering lives in the standing-authorization list at the top of `agents.md`
rather than in config, and that list is the only thing that makes the wrapper reachable.

## When not to build one

Reach for a wrapper only where the skill's package is large enough that isolation is the point.
Where a skill is small, invoking it in-session beats a 70K spawn, and the wrapper is dead weight
worth deleting rather than routing to.

Failure mode this prevents: the wrapper agent exists, is correct, and never runs — because the skill
it wraps wins a race the wrapper cannot enter. The library loads into the main context anyway, and
the agent sits in the roster looking like configuration that was never needed rather than
configuration that keeps being bypassed.
