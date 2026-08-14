# Agent Selection

## Delegate one agent freely — a fan-out is a request to make explicitly

Every spawned agent draws on the session and weekly token budgets. Those are separate from the
context window and are the binding constraint: keeping the main context clean does not replenish
them.

**The fixed cost of a spawn is around 70K tokens before the agent does any work**, and the rule set
is the dominant term in it rather than the agent's own prompt or its tool definitions. A
`general-purpose` agent that made zero tool calls and answered three questions about its own
context came to 72,497 tokens, nearly all of it input — this file and its two dozen siblings, plus
`CLAUDE.md`. Every agent that loads the hierarchy pays that, which is all of them but `Explore` and
`Plan`.

A spawn earns that back because the noisy output never enters the main context and so is never
re-sent on later turns. That makes the comparison a product rather than a threshold: **tokens of
noise avoided, times turns remaining, against ~70K.** A broad search early in a long session clears
it comfortably. The same search on the last turn before stopping does not, and neither does a small
read at any point — "the output is large" is not sufficient on its own, because a single large read
is one turn's worth of savings against the whole fixed cost.

That arithmetic is what breaks on a fan-out, which multiplies the fixed cost by the number of agents
and earns back about what one agent would. **So one agent is the shape. Several is a request to make
explicitly, carrying a count, never a judgment call made quietly** — and a dynamic workflow, a
reviewer panel, or a swarm across dimensions is not an upgrade to offer at all.

Within that ceiling the recognition triggers throughout this file are meant to fire *and* be acted
on. These shapes carry a standing authorization, so spawn a single agent for them without a
per-session ask:

- **Code review** — one `code-reviewer` sub-agent.
- **Direction or design review** — one `architect-reviewer`. Whether an approach is right is a
  different question from whether code is correct, and the tell that it was wanted is a request
  aimed at `code-reviewer` carrying the framing by hand ("don't treat this as final", "review the
  direction"). It weighs an approach still in flight, where the `adr` skill records a decision
  already taken.
- **A noisy read** — the high-volume-output section below, including its source-gathering and
  library-inlining subsections.
- **Codebase exploration whose output would be file dumps** — one `Explore` or
  `codebase-pattern-finder`, per the table below.
- **Root-cause diagnosis that needs reproduction** — one `debugger`. Rerunning a failing case,
  bisecting it, and reading stack traces is the noisy-read shape wearing a different hat, and the
  reproduction has to happen in some context regardless.
- **Diagram production** — one `mermaid-diagram-specialist`, and don't invoke the
  `mermaid-diagrams` skill in-session instead. See *An agent that wraps a skill puts the library
  where it can be dropped* below for why the order matters.

Anything outside those shapes gets a one-line ask naming what would be sent. So does anything above
one agent, whatever the shape. Most sessions also carry a harness instruction not to call the Agent
tool unless the user asked, and a standing authorization is what makes a delegation permitted as
well as affordable — the request was made here rather than in the session.

Failure mode this prevents: the two costs get collapsed into one policy. Gating every spawn on an
ask suppresses the single delegation that pays for itself, putting the friction on the cheap case
while the expensive one — the fan-out — is what needed the gate. Leaving both ungated inverts it,
because an extra agent looks free when the resource it consumes is invisible from inside the
session, and the user finds out at the weekly limit having never been asked.

## Codebase Exploration

Three agents handle codebase work. This table picks *which* one, within the standing authorization
above for exploration whose output would be file dumps. Choose based on what you need back:

| Goal | Agent |
|------|-------|
| Locate files, understand structure, answer "how does X work" | `Explore` |
| Find concrete implementation examples to model after | `codebase-pattern-finder` |
| Exploration that must lead directly into editing or running commands | `general-purpose` |

**`Explore` vs `codebase-pattern-finder`**: If the output needs to be code you can copy or adapt, use `codebase-pattern-finder`. If you need structural answers or file locations, use `Explore`.

## Planning

The `Plan` subagent suits non-trivial implementations. Planning carries no standing authorization above, so offer it rather than spawning it on your own read of "non-trivial". For decisions with long-term architectural impact, prefer ADRs over Claude Code's plan mode (EnterPlanMode) — see `rules/development-workflow.md`.

## Parallelization

This is a mechanic, not a license: it governs *how* to launch agents the user has already agreed to, never how many to launch. Once several are authorized, put them in a single message rather than sequentially so they run concurrently. Common cases: a code review alongside a security audit, or two separate subsystems explored at once. A standing authorization covers one agent for its shape, never two of them together, so each of these is still a count to have named in the ask.

### Recognize big-ADR kickoffs

When the user signals they're starting an ADR and the scope description sounds substantial — multiple subsystems, a refactor that fans out across files, cross-cutting concerns, multi-PR work implied — ask before drafting whether to spawn a parallel `Explore` to scout affected code first. Don't ask for every ADR. Reserve it for cases where the Context section will need real evidence gathering, not paraphrase.

Trigger phrases worth treating as "big": "this touches a lot of places", "a refactor across X", "rewriting all the Y", "the N places we currently...", multiple PRs or many issues implied, or the user explicitly naming the scope as large.

Failure mode this prevents: jumping straight to drafting on a substantial ADR produces a thin or inferred Context section that has to be rewritten once implementation surfaces what was missed. Parallel scouting front-loads the verification the ADR needs anyway.

## Delegate A Noisy Read Rather Than Loading It

When a tool call would dump high-volume output into the main context — large generated files, broad searches across many files, verbose test runs, long PR comment threads, full migration histories — and only a few facts are needed from it, that is the shape delegation is for: one `Explore` or `general-purpose` agent with a tight prompt asking for just those facts, burning its own context on the noise. This shape carries the standing authorization at the top of this file, so send it without asking first.

What it does need is a *tight* prompt. A vague one pays the fixed cost and returns the noise anyway, which is the only way this shape loses — so name the facts wanted and the form to return them in.

Trigger examples:
- "When was the `users.email_verified_at` column added?" — delegate. The main context doesn't need 30 migrations loaded.
- "What does the open PR review feedback say across these four PRs?" — delegate, one agent, returning a summary.
- "Find every callsite of `LegacyJob` and summarize what they pass" — delegate, one agent, returning just the table.
- **Source-gathering for prose.** When about to write prose describing how an external system or codebase concept works (per `honesty.md`'s framing rule), send an `Explore` agent to gather the source quotes to draft from. Reading the source directly is the cheaper answer when it is three greps — this earns its keep when the sources are scattered across many files.

Failure mode this prevents: long sessions accumulate context from noisy reads that were only useful for extracting one or two facts, and by the time the important work arrives the window is full of incidental output. Gating this shape on an ask does not fix that — it puts a question in front of the user on the one delegation whose arithmetic already works, and the reflex under friction is to load the noise instead.

### A skill that inlines a reference library is for building the thing, not for deciding whether to

Some skills carry a whole reference library and inline **all** of it on invocation — every language's SDK docs, every adjacent product surface, the full migration guide — not the one page the question needs. Their trigger text is written for the build case ("read this before writing the code"), and it matches just as readily on a *scoping* question, where the same volume buys a single fact. The `claude-api` skill is the recognizable instance; the shape is what to watch for, since which skills behave this way changes.

So decide before calling, because there is nowhere else to put it: a skill invoked through `Skill` loads into the turn that calls it, and no flag redirects it. Ask what you would actually take away.

- **A procedure you're about to follow** — writing the integration, running the migration, authoring the artifact. Invoke it; that is what it is for.
- **A fact** — a current version or identifier, a limit, whether a feature exists. Check what is already in context first. The environment block, the project's own lockfile, and its docs routinely already hold it, and a fact in hand needs no skill at all.
- **A fact that genuinely isn't at hand** — this is the delegation case above, and the standing authorization covers it. Send an agent to absorb the library in its own context and hand back the sentence.

Failure mode this prevents: a question about *whether* to build something pulls in the library for *building* it, and nothing can unload it afterward. Because the trigger genuinely matched, the call reads as correct at the time and the cost is only visible later — as a context jump the user notices and has to ask about, in a session whose remaining headroom was the thing being spent.

### An agent that wraps a skill puts the library where it can be dropped

The subsection above says to delegate rather than load, which leaves a gap: once a skill has fired in-session its content cannot be delegated anywhere. An agent whose `skills:` frontmatter names the skill closes that gap. The field preloads the skill's **full content**, not its description, into the agent's context at spawn — so the reference library lands in a window that ends when the agent returns. `mermaid-diagram-specialist` is the standing instance: a definition whose body is little more than "follow the `mermaid-diagrams` skill", against a skill package of 124K.

Two documented arrangements point opposite ways, and picking the wrong one produces an agent that returns nothing:

- **A skill that is reference material** — syntax tables, conventions, selection guidance — goes behind an agent that names it in `skills:`. The agent's body supplies the task, the skill supplies the knowledge.
- **A skill that is itself a task** — explicit steps to carry out — takes `context: fork` and needs no wrapper, because the skill content *becomes* the agent's prompt. Forking a guidelines-only skill hands the agent knowledge and no instruction, and it returns without meaningful output.

A forked skill can also name `agent: Explore`, which is the one way to run this shape without the ~70K hierarchy load, since Explore skips it.

Nothing enforces the ordering, and that is the real difficulty. A skill fires on description-match during a turn, so "diagram this" can load the library into the main context before any delegation decision gets made — the exact cost the wrapper exists to avoid. No frontmatter field prevents that: `disable-model-invocation: true` stops a skill firing on its own, but it also stops the skill being preloaded into an agent, which breaks the very wrapper it would be protecting. So the ordering lives in the standing-authorization list at the top of this file rather than in config, and the list is the only thing that makes the wrapper reachable.

Reach for a wrapper only where the skill's package is large enough that isolation is the point. Where a skill is small, invoking it in-session beats a 70K spawn, and the wrapper is dead weight worth deleting rather than routing to.

Failure mode this prevents: the wrapper agent exists, is correct, and never runs — because the skill it wraps wins a race the wrapper cannot enter. The library loads into the main context anyway, and the agent sits in the roster looking like configuration that was never needed rather than configuration that keeps being bypassed.

## `Explore` And `Plan` Are The Only Agents Without These Rules

Exactly two sub-agents run without the rules loaded here, and both are built-ins: `Explore` and `Plan` skip the entire CLAUDE.md hierarchy — `~/.claude/CLAUDE.md`, the `rules/` directory including its private symlinked files, `CLAUDE.local.md`, managed policy. Every other agent loads all of it, custom definitions in `agents/` and the built-in `general-purpose` alike. No frontmatter field moves an agent across that line.

So a specialized agent's expertise arrives **on top of** this baseline rather than in competition with it. `postgres-pro` has the code style. `code-reviewer` has the revert hazard and the staging rules. Do not restate a rule in a prompt to one of them, and do not treat their output as advice from somewhere the conventions don't reach.

The constraint-passing below is for `Explore` and `Plan` alone.

When delegating to either, pass along any rule that governs the work's *how*. The recurring case is RTK: an `Explore` agent doing file-discovery reaches for `awk` (or a bare `cat`, `find | wc -l`, &c.) because it never saw `RTK.md` — and each such command trips a permission prompt, since awk and friends aren't allow-listed. Naming the constraint in the prompt ("use `rtk ls`/`rtk find`/`rtk read`; don't pipe to `awk`") heads it off. The same applies to any rule the delegated task actually exercises — the home-directory scope limit for an agent that searches paths, for instance.

Another high-frequency case is the no-`cd` rule (tool-and-shell-safety.md's *Don't reflexively `cd` into the working directory*). Both agents carry Bash and start in the project root but, not seeing that rule, prefix commands with `cd <project-root>` — often paired with output redirection (`2>/dev/null`), which trips a security-approval prompt on *every* such call. Tell them where the shell starts: don't `cd`, and never pair `cd` with output redirection.

**Phrase that as where it starts, not as a prohibition to enforce.** An agent handed a flat "never `cd`" may try to *guarantee* it rather than simply comply — one prefixed its command with `cd() { return 1; }` to make the call fail if anything reached for it. That is harmless in effect, since a shell function dies with the invocation that defined it, but it trips the `function_definition` security check and puts a prompt in front of the user for a command whose actual work was a read-only `grep`. Defining a function is also how a command gets shadowed for real, so the check is worth keeping and the prompt is worth not provoking. State the fact — "your shell starts in the project root, so paths are relative to it" — and leave the enforcement to the guard hook that already exists.

**Say to invoke project scripts by their relative path**, per tool-and-shell-safety.md's *Invoke a project script by the relative path its allow rule names*. An agent reaching for an absolute path — the natural move when it has been told which directory it is in — prompts for a command the project already allow-listed. One sentence in the spawning prompt ("run project scripts as `bin/<script>`, not by absolute path") avoids it.

Pass only the constraints the delegated work will actually exercise, and only to these two. The main conversation reads their results with the full rule set in context, so most rules never need to reach the agent at all — restate one when it governs a command the agent will *run*, not when it governs how the result gets used.

Failure mode this prevents, in both directions. Assume every agent is stripped and the prompts to custom agents fill with restated conventions they already hold, while their expertise gets discounted as coming from outside the conventions. Assume every agent is equipped and `Explore` reaches for `awk` and `cd … 2>/dev/null`, stopping the delegated work for approvals the user cannot evaluate — they never saw the command composed, and the reason it prompted is a property of the *prompt you wrote* rather than of the work being done.

## Specialized Agents

When a task clearly matches a specialized agent — `postgres-pro` for PostgreSQL depth, `debugger` for root-cause work — name that one rather than `general-purpose`, since domain specialization provides heuristics that generalist prompting won't replicate. Like the table above, this picks the agent for a delegation already agreed to, and a clear domain match is not itself the reason to spawn one.

**`postgres-pro` needs its recognition stated, because nothing else fires it.** A PostgreSQL question deep enough that the answer changes what gets written — an index choice, a query rewrite, planner behaviour under real cardinality, a configuration knob — is one to offer it for rather than answer from general knowledge. An offer, not a spawn, per the ceiling at the top of this file. Note the boundary against the two Postgres *skills*, which fire on their own and cover schema design and Supabase-flavoured practice: reach for the agent when the question is how this database will actually behave, and let the skills have the question of how to shape a schema.

`agents/` is deliberately small, and a domain not covered there is not an oversight to work around. Agents are kept at the point of need rather than in advance, so the answer to "there's no agent for this" is either to add one with a trigger path (see `agents/README.md`) or to proceed without one — never to stretch a nearby agent over ground it wasn't kept for.
