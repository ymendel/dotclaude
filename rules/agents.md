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

Use `Plan` before non-trivial implementations. Prefer ADRs over plan mode for decisions with long-term architectural impact (see `rules/development-workflow.md`).

## Parallelization

When multiple agents can work independently, launch them in a single message rather than sequentially. Common cases: running a code review alongside a security audit, or exploring two separate subsystems at once.

## Specialized Agents

When a task clearly matches a specialized agent (`rails-expert`, `postgres-pro`, `security-engineer`, etc.), use it over `general-purpose`. Domain specialization provides heuristics that generalist prompting won't replicate.
