# Development Workflow

## General

- Unless working on a small, relatively obvious change, plan before doing. (exception: spikes)
- Prefer ADRs to any sort of internal or proprietary "plan mode".

## Spikes

- Sometimes something has to be tried out as a "spike" to determine the proper path or the full shape of the problem.
- When performing a spike, take note of learnings in a document.
- When the spike is finished, remove everything but the document and use that as the basis of the plan.

## Implementation

- Use the ADR as the guidelines for implementing the plan.
- When conflicts come up between the ADR and the implementation, reconcile them. Determine whether the ADR or the implementation is correct. If you're not sure, ask.

## Version Control

- git is the version-control tool of choice, and GitHub is the preferred hosting provider
- Commit structuring and message format are governed by the `purposeful-commits` and `commit-message-guide` skills. When both are active, `purposeful-commits` runs first to structure the work into logical commits, then `commit-message-guide` applies to each individual commit message.
- Never use `git add -A` or `git add .` — always stage specific files by name.
- Keep commits to small, logical changes. Do not make one big commit at the end.
- When refining a change that just happened, amend the previous commit instead of creating a new one.
- To reword a non-HEAD commit, ask the user to run `git rebase -i` interactively. Scripted workarounds (GIT_EDITOR overrides, chained amends) are unreliable and cause cascading message corruption.
- Use the `gh` command-line tool when interacting with GitHub

## Pull Requests

- Always create PRs as 'drafts'.
- Keep PR descriptions up to date with changes – e.g. TODO lists, deferred work, references to ADRs, &c.
- Never push to GitHub on your own — not after commits, not as a prerequisite for creating a PR, not for any reason. If the branch needs to be pushed first (e.g., to open a PR), ask the user to push. The only exception: if the only unpushed changes involve CI/CD or GitHub Actions, flag it and let the user decide.

## Commenting

- Preserve existing comments when editing code; comments are for humans, not the parser. Never silently drop them as collateral during edits.
- Add comments for some of the same reasons as including a body in the git commit — why (if not obvious), context that's not clear. Prefer a reference to an ADR to inlining the full reasoning.
- Use comment keywords to highlight special comments
    - **NOTE**: explanations and miscellaneous annotations
    - **TODO**: useful features, optimizations, or refactorings that might be worth doing in the future. Or simply marking "the next step".
    - **FIXME**: definitely broken, but may not need to worry about it right now
    - **TBD**: uncertainty about an implementation, behavior, conceptual understanding, &c.

## Refactoring

- Refactor correctively (to fix a real problem) or when there's a clear benefit — not as routine hygiene or speculation about future needs.
- Keep refactoring separate from behavior changes: add any necessary tests first, ensure they pass, then refactor, then change behavior.

## Context Continuity

- After any substantial work block — multiple file edits, debugging, architecture decisions — proactively write or update project memories for facts that would matter in a future session. Don't wait to be asked.
- After a work block, proactively check whether `lesson-learned` or `self-improvement` applies. Don't wait to be asked.
- In sessions where multiple commits have been made and work is ongoing, suggest `/session-handoff` after each major phase completes (e.g., after a logical group of commits). Do not wait for the user to signal they are wrapping up — by then the context may already be near its limit.
- Also suggest `/session-handoff` when the user signals wrapping up, or when significant in-progress work exists that would be disorienting to resume cold.
