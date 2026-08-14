# Agents

Specialized subagents invoked via the `Agent` tool. Each one runs in its own context and does not
see the current conversation, but it *does* load the full `CLAUDE.md` hierarchy — `~/.claude/CLAUDE.md`
and every file in `rules/` — so an agent's expertise arrives on top of this repo's conventions rather
than in competition with them. The built-in `Explore` and `Plan` agents are the exceptions that skip
that load; nothing here does.

## What earns a place here

**A trigger path, not a domain match.** An agent only runs when something decides to delegate to it,
and skills fire on description-match without any such decision. So an agent with no entry in
`rules/agents.md` is unreachable in practice however well its description fits — it loses every race
to a skill covering the same ground, and sits in the roster reading as configuration nobody needed.
Every agent below is named by a standing authorization in that file or by its agent-selection table.

**Kept at the point of need, not in advance.** Speculative agents were the failure this directory
grew out of: 39 were added in April 2026, pruned to 24, and then largely unused. Stocking an agent
for a domain that might come up trades a small permanent cost — a description in every session's
system prompt, and a name to hold in mind — against a need that is only guessed at. The trade is
worst in an unfamiliar domain, which is exactly where the reflex to stock up is strongest: an agent
advising on ground you cannot evaluate is the riskiest one in the inventory, not the safest.

So when work arrives in a new domain, add an agent *then*. See *Adding one back* below.

**Judge a kept agent by recall, not authority.** These files are inherited checklists, and a long
bulleted list gives no signal about whether it helps. The answerable question after a real run is
"did this surface something I would not have listed" — which holds even in a domain you can't score
for correctness. Whether its *recommendations* are right is a separate question, and not one to
take on the agent's word.

## The agents

**`code-reviewer`** (opus) — Correctness, security, and best practices on a diff. Opus because review
quality compounds. It carries write tools and uses them for probes — exercising a test, adding timing
— which is legitimate, and it loads this repo's rules on reverting and staging, so the probe cleanup
is bounded by them.

**`architect-reviewer`** (opus) — Evaluates design decisions, patterns, and technology choices at the
macro level. The direction question, not the correctness one: reach for it when the ask is whether an
approach is right. Distinct from the `adr` skill, which records a decision already taken.

**`codebase-pattern-finder`** (read-only) — Finds existing implementations and usage examples.
Documentarian only: it shows what exists without evaluating, critiquing, or recommending. That
constraint is the whole point of it.

**`debugger`** — Root cause diagnosis. Kept for the shape rather than the domain — reproducing a
failure needs Bash and throws off exactly the noisy output worth confining to another context.

**`postgres-pro`** — PostgreSQL depth: query optimization, configuration tuning, advanced features.
The one domain agent kept, on the author's own ground rather than on a blind spot.

**`mermaid-diagram-specialist`** — Produces Mermaid diagrams, with the `mermaid-diagrams` skill named
in its `skills:` frontmatter so the skill's full content preloads into the agent's context. The
124K reference package lands in a window that ends when the agent returns, which is the entire reason
this agent exists.

## Adding one back

Nothing here was authored in this repo — every file is third-party MIT, from
`VoltAgent/awesome-claude-code-subagents` or `softaworks/agent-toolkit` (ADR 0006, which also explains
why agents carry repo-level attribution only and no per-agent notice). So adding and removing them is
cheap in both directions.

- **Previously present** — `git show b150e69:agents/<name>.md` recovers any of the 39 originals,
  including those pruned before this set.
- **New** — take it from either upstream above, and add its author to the README's Appreciation
  section if the upstream is not already credited there.

Either way, give it an entry in `rules/agents.md` in the same change. An agent added without one
repeats the failure this directory was pruned to fix.
