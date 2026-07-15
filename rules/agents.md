# Agent Selection

## Codebase Exploration

Three agents handle codebase work — choose based on what you need back:

| Goal | Agent |
|------|-------|
| Locate files, understand structure, answer "how does X work" | `Explore` |
| Find concrete implementation examples to model after | `codebase-pattern-finder` |
| Exploration that must lead directly into editing or running commands | `general-purpose` |

**`Explore` vs `codebase-pattern-finder`**: If the output needs to be code you can copy or adapt, use `codebase-pattern-finder`. If you need structural answers or file locations, use `Explore`.

## Planning

Use the `Plan` subagent before non-trivial implementations. For decisions with long-term architectural impact, prefer ADRs over Claude Code's plan mode (EnterPlanMode) — see `rules/development-workflow.md`.

## Parallelization

When multiple agents can work independently, launch them in a single message rather than sequentially. Common cases: running a code review alongside a security audit, or exploring two separate subsystems at once.

### Recognize big-ADR kickoffs

When the user signals they're starting an ADR and the scope description sounds substantial — multiple subsystems, a refactor that fans out across files, cross-cutting concerns, multi-PR work implied — ask before drafting whether to spawn a parallel `Explore` to scout affected code first. Don't ask for every ADR. Reserve it for cases where the Context section will need real evidence gathering, not paraphrase.

Trigger phrases worth treating as "big": "this touches a lot of places", "a refactor across X", "rewriting all the Y", "the N places we currently...", multiple PRs or many issues implied, or the user explicitly naming the scope as large.

Failure mode this prevents: jumping straight to drafting on a substantial ADR produces a thin or inferred Context section that has to be rewritten once implementation surfaces what was missed. Parallel scouting front-loads the verification the ADR needs anyway.

## Delegate Noisy Output to Preserve Main Context

When a tool call would dump high-volume output into the main context — large generated files, broad searches across many files, verbose test runs, long PR comment threads, full migration histories — and only a few facts are needed from it, delegate to `Explore` or `general-purpose` with a tight prompt asking for just those facts. The sub-agent burns its context on the noise. The main context stays clean for the work that needs it.

Trigger examples:
- "When was the `users.email_verified_at` column added?" — delegate. The main context doesn't need 30 migrations loaded.
- "What does the open PR review feedback say across these four PRs?" — delegate, return a summary.
- "Find every callsite of `LegacyJob` and summarize what they pass" — delegate, return just the table.
- **Source-gathering for prose.** When about to write prose describing how an external system or codebase concept works (per `honesty.md`'s framing rule), send an `Explore` agent to gather the source quotes first, then draft from those quotes. Keeps the gather phase out of the main context and produces the quoted evidence the framing rule requires.

Failure mode this prevents: long sessions accumulate context from noisy reads that were only useful for extracting one or two facts. By the time the actually-important work arrives, the context window is full of incidental output and the model is operating with reduced headroom. Delegating noisy reads is cheap and preserves the runway for the real work.

## Sub-Agents Don't Inherit These Rules — Pass Constraints In The Prompt

A spawned sub-agent (`Explore`, `general-purpose`, a specialized agent) runs with a stripped context. It does **not** inherit the rules loaded here — RTK tool conventions, code style, searching scope, naming. So a rule that would govern the sub-agent's actual work only takes effect if it's restated in the spawning prompt.

When delegating work whose *how* is governed by a rule the sub-agent won't see, pass that constraint along. The recurring case is RTK: an `Explore` agent doing file-discovery reaches for `awk` (or a bare `cat`, `find | wc -l`, &c.) because it never saw `RTK.md` — and each such command trips a permission prompt, since awk and friends aren't allow-listed. Naming the constraint in the prompt ("use `rtk ls`/`rtk find`/`rtk read`; don't pipe to `awk`") heads it off. The same applies to any rule the delegated task actually exercises — a code-style convention for an agent that will write code, the home-directory scope limit for an agent that searches paths.

Another high-frequency case is the no-`cd` rule (feedback.md's *Don't reflexively `cd` into the working directory*). A sub-agent starts in the project root but, not seeing that rule, prefixes commands with `cd <project-root>` — often paired with output redirection (`2>/dev/null`), which trips a security-approval prompt on *every* such call. Tell any Bash-running sub-agent it starts in the project root: don't `cd`, and never pair `cd` with output redirection.

Don't dump the whole ruleset into every prompt — pass only the constraints the delegated work will actually exercise.

Failure mode this prevents: delegating work assuming the sub-agent carries the same rules the main context does, then getting output (or, with RTK, a string of permission prompts) that violates a rule the agent never had a chance to follow. The rule exists; the gap is that it never reached the agent doing the work.

## Specialized Agents

When a task clearly matches a specialized agent (`rails-expert`, `postgres-pro`, `security-engineer`, etc.), use it over `general-purpose`. Domain specialization provides heuristics that generalist prompting won't replicate.
