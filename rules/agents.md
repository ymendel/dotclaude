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

When the user signals they're starting an ADR and the scope description sounds substantial — multiple subsystems, a refactor that fans out across files, cross-cutting concerns, multi-PR work implied — ask before drafting whether to spawn a parallel `Explore` to scout affected code first. Don't ask for every ADR; reserve it for cases where the Context section will need real evidence gathering, not paraphrase.

Trigger phrases worth treating as "big": "this touches a lot of places", "a refactor across X", "rewriting all the Y", "the N places we currently...", multiple PRs or many issues implied, or the user explicitly naming the scope as large.

Failure mode this prevents: jumping straight to drafting on a substantial ADR produces a thin or inferred Context section that has to be rewritten once implementation surfaces what was missed. Parallel scouting front-loads the verification the ADR needs anyway.

## Delegate Noisy Output to Preserve Main Context

When a tool call would dump high-volume output into the main context — large generated files, broad searches across many files, verbose test runs, long PR comment threads, full migration histories — and only a few facts are needed from it, delegate to `Explore` or `general-purpose` with a tight prompt asking for just those facts. The sub-agent burns its context on the noise; the main context stays clean for the work that needs it.

Trigger examples:
- "When was the `users.email_verified_at` column added?" — delegate; the main context doesn't need 30 migrations loaded.
- "What does the open PR review feedback say across these four PRs?" — delegate; return a summary.
- "Find every callsite of `LegacyJob` and summarize what they pass" — delegate; return just the table.
- **Source-gathering for prose.** When about to write prose describing how an external system or codebase concept works (per `honesty.md`'s framing rule), send an `Explore` agent to gather the source quotes first, then draft from those quotes. Keeps the gather phase out of the main context and produces the quoted evidence the framing rule requires.

Failure mode this prevents: long sessions accumulate context from noisy reads that were only useful for extracting one or two facts. By the time the actually-important work arrives, the context window is full of incidental output and the model is operating with reduced headroom. Delegating noisy reads is cheap and preserves the runway for the real work.

## Specialized Agents

When a task clearly matches a specialized agent (`rails-expert`, `postgres-pro`, `security-engineer`, etc.), use it over `general-purpose`. Domain specialization provides heuristics that generalist prompting won't replicate.
