# Agent Selection

## Spawning spends the session and weekly budgets — ask before it, don't decide it

Every spawned agent draws on the session and weekly token budgets. Those are separate from the
context window and are the binding constraint: keeping the main context clean does not replenish
them. A sub-agent pays a fixed cost — its own system prompt, its tool definitions, and its reading
of whatever it was sent to read — and earns that back only because the noisy output never enters
the main context and so is never re-sent on later turns. The trade wins when the output is large
*and* many turns remain; it loses when either is small. A fan-out multiplies the fixed cost by the
number of agents and earns back about what one agent would.

So the recognition triggers throughout this file stay, and the reflex to act on them does not. When
one fires, put a one-line ask in front of the user — what would be sent, and to how many agents —
rather than spawning. **One agent is the default shape. Several is a request to make explicitly,
carrying a count, never a judgment call made quietly.** Most sessions also carry a harness
instruction not to call the Agent tool unless the user asked, so the ask is what makes a delegation
permitted as well as affordable.

**Standing authorization — code review.** Review goes to a single `code-reviewer` sub-agent. That
request is already made and needs no per-session ask. It is also a ceiling rather than a floor: not
a workflow, not a panel of reviewers, not a fan-out across review dimensions. Don't offer the
orchestrated version as an upgrade.

Failure mode this prevents: delegation gets justified on context grounds alone — the budget this
file spent most of its length talking about — which makes an extra agent look free, because the
resource it actually consumes is invisible from inside the session. The user finds out at the
weekly limit, having never been asked about any individual spawn.

## Codebase Exploration

Three agents handle codebase work. This table settles *which* one a delegation names once the ask has
been made — it is not itself a reason to spawn. Choose based on what you need back:

| Goal | Agent |
|------|-------|
| Locate files, understand structure, answer "how does X work" | `Explore` |
| Find concrete implementation examples to model after | `codebase-pattern-finder` |
| Exploration that must lead directly into editing or running commands | `general-purpose` |

**`Explore` vs `codebase-pattern-finder`**: If the output needs to be code you can copy or adapt, use `codebase-pattern-finder`. If you need structural answers or file locations, use `Explore`.

## Planning

The `Plan` subagent suits non-trivial implementations — offer it, per the budget section, rather than spawning it on your own read of "non-trivial". For decisions with long-term architectural impact, prefer ADRs over Claude Code's plan mode (EnterPlanMode) — see `rules/development-workflow.md`.

## Parallelization

This is a mechanic, not a license: it governs *how* to launch agents the user has already agreed to, never how many to launch. Once several are authorized, put them in a single message rather than sequentially so they run concurrently. Common cases: a code review alongside a security audit, or two separate subsystems explored at once — each of which is a count to have named in the ask.

### Recognize big-ADR kickoffs

When the user signals they're starting an ADR and the scope description sounds substantial — multiple subsystems, a refactor that fans out across files, cross-cutting concerns, multi-PR work implied — ask before drafting whether to spawn a parallel `Explore` to scout affected code first. Don't ask for every ADR. Reserve it for cases where the Context section will need real evidence gathering, not paraphrase.

Trigger phrases worth treating as "big": "this touches a lot of places", "a refactor across X", "rewriting all the Y", "the N places we currently...", multiple PRs or many issues implied, or the user explicitly naming the scope as large.

Failure mode this prevents: jumping straight to drafting on a substantial ADR produces a thin or inferred Context section that has to be rewritten once implementation surfaces what was missed. Parallel scouting front-loads the verification the ADR needs anyway.

## Noisy Output Is Worth An Ask, Not A Silent Spawn

When a tool call would dump high-volume output into the main context — large generated files, broad searches across many files, verbose test runs, long PR comment threads, full migration histories — and only a few facts are needed from it, that is the shape delegation is for: one `Explore` or `general-purpose` agent with a tight prompt asking for just those facts, burning its own context on the noise. Offer it in a sentence and let the user decide, per the budget section at the top of this file. The recognition is the valuable half and it belongs to you; the spend is theirs.

Trigger examples:
- "When was the `users.email_verified_at` column added?" — worth an ask. The main context doesn't need 30 migrations loaded.
- "What does the open PR review feedback say across these four PRs?" — worth an ask; one agent, returning a summary.
- "Find every callsite of `LegacyJob` and summarize what they pass" — worth an ask; one agent, returning just the table.
- **Source-gathering for prose.** When about to write prose describing how an external system or codebase concept works (per `honesty.md`'s framing rule), an `Explore` agent can gather the source quotes to draft from. Note when offering it that reading the source directly is often the cheaper answer — this one earns its keep when the sources are scattered across many files, not when they are three greps.

Failure mode this prevents: long sessions accumulate context from noisy reads that were only useful for extracting one or two facts, and by the time the important work arrives the window is full of incidental output. The correction is not to spawn on reflex — that trades a context problem for a token-budget one the user never agreed to — but to name the trade and let them take it.

### A skill that inlines a reference library is for building the thing, not for deciding whether to

Some skills carry a whole reference library and inline **all** of it on invocation — every language's SDK docs, every adjacent product surface, the full migration guide — not the one page the question needs. Their trigger text is written for the build case ("read this before writing the code"), and it matches just as readily on a *scoping* question, where the same volume buys a single fact. The `claude-api` skill is the recognizable instance; the shape is what to watch for, since which skills behave this way changes.

So decide before calling, because there is nowhere else to put it: a skill invoked through `Skill` loads into the turn that calls it, and no flag redirects it. Ask what you would actually take away.

- **A procedure you're about to follow** — writing the integration, running the migration, authoring the artifact. Invoke it; that is what it is for.
- **A fact** — a current version or identifier, a limit, whether a feature exists. Check what is already in context first. The environment block, the project's own lockfile, and its docs routinely already hold it, and a fact in hand needs no skill at all.
- **A fact that genuinely isn't at hand** — this is the delegation case above. Send an agent to absorb the library in its own context and hand back the sentence. Where standing instructions bar spawning an agent unprompted, ask for one; a single question costs less than the load.

Failure mode this prevents: a question about *whether* to build something pulls in the library for *building* it, and nothing can unload it afterward. Because the trigger genuinely matched, the call reads as correct at the time and the cost is only visible later — as a context jump the user notices and has to ask about, in a session whose remaining headroom was the thing being spent.

## Sub-Agents Don't Inherit These Rules — Pass Constraints In The Prompt

A spawned sub-agent (`Explore`, `general-purpose`, a specialized agent) runs with a stripped context. It does **not** inherit the rules loaded here — RTK tool conventions, code style, searching scope, naming. So a rule that would govern the sub-agent's actual work only takes effect if it's restated in the spawning prompt.

When delegating work whose *how* is governed by a rule the sub-agent won't see, pass that constraint along. The recurring case is RTK: an `Explore` agent doing file-discovery reaches for `awk` (or a bare `cat`, `find | wc -l`, &c.) because it never saw `RTK.md` — and each such command trips a permission prompt, since awk and friends aren't allow-listed. Naming the constraint in the prompt ("use `rtk ls`/`rtk find`/`rtk read`; don't pipe to `awk`") heads it off. The same applies to any rule the delegated task actually exercises — a code-style convention for an agent that will write code, the home-directory scope limit for an agent that searches paths.

Another high-frequency case is the no-`cd` rule (tool-and-shell-safety.md's *Don't reflexively `cd` into the working directory*). A sub-agent starts in the project root but, not seeing that rule, prefixes commands with `cd <project-root>` — often paired with output redirection (`2>/dev/null`), which trips a security-approval prompt on *every* such call. Tell any Bash-running sub-agent it starts in the project root: don't `cd`, and never pair `cd` with output redirection.

**Phrase that as where it starts, not as a prohibition to enforce.** A sub-agent handed a flat "never `cd`" may try to *guarantee* it rather than simply comply — one prefixed its command with `cd() { return 1; }` to make the call fail if anything reached for it. That is harmless in effect, since a shell function dies with the invocation that defined it, but it trips the `function_definition` security check and puts a prompt in front of the user for a command whose actual work was a read-only `grep`. Defining a function is also how a command gets shadowed for real, so the check is worth keeping and the prompt is worth not provoking. State the fact — "your shell starts in the project root, so paths are relative to it" — and leave the enforcement to the guard hook that already exists.

**Say to invoke project scripts by their relative path**, per tool-and-shell-safety.md's *Invoke a project script by the relative path its allow rule names*. A sub-agent reaching for an absolute path — the natural move when it has been told which directory it is in — prompts for a command the project already allow-listed. One sentence in the spawning prompt ("run project scripts as `bin/<script>`, not by absolute path") avoids it.

Don't dump the whole ruleset into every prompt — pass only the constraints the delegated work will actually exercise.

Failure mode this prevents: delegating work assuming the sub-agent carries the same rules the main context does, then getting output (or, with RTK, a string of permission prompts) that violates a rule the agent never had a chance to follow. The prompts are the worse half, and the two phrasing lessons above are aimed squarely at them — the delegated work stops for approvals the user cannot evaluate, because they never saw the command composed and the reason it prompted is a property of the *prompt you wrote* rather than of the work being done. The rule exists. The gap is that it never reached the agent doing the work.

## Specialized Agents

When a task clearly matches a specialized agent (`rails-expert`, `postgres-pro`, `security-engineer`, etc.), name that one rather than `general-purpose` — domain specialization provides heuristics that generalist prompting won't replicate. Like the table above, this picks the agent for a delegation already agreed to; a clear domain match is not itself the reason to spawn one.
