# Development Workflow

## General

- Unless working on a small, relatively obvious change, plan before doing. (exception: spikes)
- Prefer ADRs to any sort of internal or proprietary "plan mode".

## Active Attention to Constraints

At the start of any long, multi-file, or multi-thread task, restate the constraints that apply to this work before acting — even though the rules are loaded passively in context. Examples: Edit tool not `sed`, `rtk proxy git diff` when diff output is suppressed, devenv-only commands for test/rubocop on projects that use it, no autonomous pushes or merges.

This is not a request to re-derive the rules from scratch — it's a one-pass acknowledgment of which ones govern the work about to start. A short bulleted recap is enough. It goes in the first response of the task, not every response within it.

Failure mode this prevents: with many rules loaded passively, applying them during fast-moving work requires deliberate attention. Without restating them at the start, the easy path is to default to the unconstrained action and rely on the user to catch the slip mid-tool-use. This is the dominant source of "wrong approach" friction in long sessions. The rules already exist, the gap is attention, and the user shouldn't have to add a constraint header to every prompt to compensate.

## Spikes

- Sometimes something has to be tried out as a "spike" to determine the proper path or the full shape of the problem.
- When performing a spike, take note of learnings in a document.
- When the spike is finished, remove everything but the document and use that as the basis of the plan.

## Implementation

- Use the ADR as the guidelines for implementing the plan. While implementing, keep the ADR in `Proposed` status — it's a working document until the implementation validates it. If the work surfaces gaps or contradictions, update the Proposed ADR rather than reconciling around it. Flip to `Accepted` once the decision has been validated by working code — meaning the decision's *central premise* has been exercised against real data, not just that the code ran without crashing. For a matching or sync strategy, that means measuring the match rate against a representative slice; for a schema change, running the queries that drove the decision; for an integration, at least one round-trip against the real upstream. "Ran the task once and it completed" is not validation when the premise itself was never tested.
- Work through the implementation in logical steps, committing as you go.
- When you hit a confusion or contradiction you can resolve confidently, resolve it and note it for the post-implementation report — don't interrupt the flow for handleable issues.
- Stop and ask only when you genuinely can't proceed: the ADR seems materially wrong, the resolution affects scope, or you'd be guessing at intent.
- When implementation is complete, provide a post-implementation report covering: (a) anything you handled inline that the user might want to revisit (small reconciliations, judgment calls, deviations from the ADR), and (b) remaining next steps (follow-on work, config, documentation, etc.) that fall outside the scope of what was just implemented.
- Before declaring an implementation complete, grep the pattern, not just the enumeration. When the work relaxes or flips an invariant, sites that *enforced* it get named in the issue (the unique index, the validation). Sites that *assumed* it are scattered through business-logic queries and don't surface until verification or production. Name the literal pattern (e.g. a `where(child_table: { id: nil })` join, a subquery through the old single-FK column), grep, audit each hit — including in files the PR already touched.

## Version Control

- git is the version-control tool of choice, and GitHub is the preferred hosting provider
- Commit structuring and message format are governed by the `purposeful-commits` and `commit-message-guide` skills. When both are active, `purposeful-commits` runs first to structure the work into logical commits, then `commit-message-guide` applies to each individual commit message.
- Never use `git add -A` or `git add .` — these sweep in untracked files. Prefer staging specific files by name. `git add -u` (stages modifications and deletions to already-tracked files only, never untracked) is acceptable when naming files individually is impractical (e.g. a wide mechanical rename) *and* the working tree has been verified to contain only in-scope changes — confirm `git status` shows no untracked files first, since `-u` is still a bulk stage. The hazard `-A`/`.` guard against is pulling in untracked junk. `-u` can't do that, which is why it's allowed where they aren't.
- Keep commits to small, logical changes. Do not make one big commit at the end.
- When refining a change that just happened, amend the previous commit instead of creating a new one. If a new commit was already made by mistake, recover with `git reset --soft HEAD~1` followed by `git commit --amend` — no interactive rebase needed.
- To reword a non-HEAD commit, ask the user to run `git rebase -i` interactively. Scripted workarounds (GIT_EDITOR overrides, chained amends) are unreliable and cause cascading message corruption.
- To split a file's changes across commits, ask the user to run `git add -p` interactively. Once the partial stage is done, use plain `git add <file>` for any remaining hunks — no further interactivity needed. When the hunks aren't cleanly splittable (adjacent additions that collapse into one `git add -p` hunk, &c.), an alternative is to edit the file in-place to revert one change, commit the remaining one, then re-apply the reverted change for the next commit. Use this as a fallback when the changes are independent and the full text of both is recoverable from context — but verify the reverted state leaves the other change committable on its own, and don't reach for it when many hunks or files are in play (the manual juggling gets error-prone fast).
- Use the `gh` command-line tool when interacting with GitHub
- When moving a file, always use `git mv` — never `cp` followed by a separate delete. `git mv` preserves history and stages the rename atomically.
- When a change spans both `git mv` (which auto-stages the renames) and Edit-tool changes to other files (which do not), explicitly verify the staged set before committing — `git diff --cached --stat`, or read `git status` carefully. The trap: `git mv` makes status *look* like the change is tracked (renames listed under "Changes to be committed"), while concurrent unstaged Edit-tool changes sit under "Changes not staged for commit" — easy to miss in a quick glance, especially with compact tooling output. Failure mode: the commit lands with only the auto-staged half, leaving HEAD in a broken state (files moved, but the file that points at them not updated).
- On personally-owned repos (dotfiles, personal config, single-author projects), working on `main` and pushing freely is the default — no branch needed. Reserve a branch for work that's more significant than usual (a multi-step, coherent change set that should land together) or for tangents that may not land. Without this rule, the team-repo branching habit reflexively gets applied to repos with no collaborator to coordinate with, adding ceremony to changes that don't need it.
- Branch names should be descriptive of the work, not a numeric identifier. The standard format is `initials/descriptive-kebab-case-name`. Avoid leading IDs like `ym/adr-0003-...` or `ym/jira-1234-...`. If a ticket/ADR/issue reference is worth including, put it at the *end* of the branch name, not the start (e.g. `ym/opt-in-publishing-adr-0003`, not `ym/adr-0003-opt-in-publishing`). On personally-owned repos where there's no collaborator to disambiguate from, the `initials/` prefix is often omitted entirely — `retroactive-architecture-adrs` is fine without `ym/`. Without this rule, branch lists read as a wall of opaque identifiers instead of as a description of what each branch does.
- When branching off a remote-tracking ref to start from the current remote tip (`git switch -c foo origin/main`), pass `--no-track`. Otherwise git's default `branch.autoSetupMerge` sets `origin/main` as the new branch's upstream, so `git status` reports the branch tracking `main` (`[ahead N]` against it) and a bare `git pull` would pull main. The artifact clears on the first `git push -u`, but reads as misleading until then. Alternative: advance the local ref first (`git fetch origin main:main`) and branch off local `main`, which doesn't auto-track. Branching off a stale local `main` without `--no-track` avoids the artifact but risks a stale base — the worse of the two. (`git checkout -b` behaves identically. The choice of verb doesn't change the tracking.)
- When work needs to be set aside (to switch tasks, pull a clean base, or park a tangent), offer a branch — commit the in-progress work to a descriptive branch — rather than `git stash`. The user prefers pause/resume on a branch so the parked work has a name and a visible home, not the liminal stash space. Reserve `git stash` for when the user explicitly asks for it. Without this rule, the reflexive "stash it" suggestion pushes work into a space the user actively avoids.
- Before describing a commit as an extraction, move, rename, revert, or refactor *of existing committed work*, verify with `git log` or `git show` that the prior state actually exists in history. Unstaged or in-session changes are not history — claiming to extract from them produces commit messages that describe a refactor that never happened. Failure mode: a future reader reads the commit message, looks for the prior state in `git log`, and finds nothing.
- Before referencing a project file in a PR description, ADR, issue, commit message, shared skill content (SKILL.md, TODO.md, references/), or any other artifact with readers off your machine, verify the file is tracked. `git ls-files <path>` is the quick check. Paths under `.claude/` are globally gitignored (via the user's `~/.gitignore`) even in repos whose own `.gitignore` doesn't list them — so an in-session file at `.claude/foo.md` is visible to me on this machine but invisible to anyone reading the PR, including the user from another machine. Describing such a file as "on this branch" or "in this PR" is misleading. Failure mode: a reader follows the reference, fails to find the file, and either loses the context the reference was meant to provide or has to ask. Especially common with handoffs and local punchlist/note files written under `.claude/` mid-session that then get name-dropped in PR descriptions or skill TODO entries without the location qualifier.
- Before suggesting the user discard a staged change that looks irregular or "wonky", verify whether external context explains it — open PR review comments on the current branch (`gh pr view --comments`), recent issue threads, CI failures the change might be responding to. A staged change is a deliberate act, so treat it as load-bearing until proven otherwise. When the staged diff looks off, frame as "the intent looks like X — is the execution wrong, or am I missing context?" and offer redo-correctly as a first-class option alongside commit-as-is and discard. Failure mode: a binary commit-or-drop framing pushes the user to discard work that was directionally correct but buggy in execution, costing a redo and an extra commit.

## User's Independent Habits

The user pushes branches, creates commits, creates new branches, and switches contexts independently — without narrating it. When interpreting a request, always check current state first (`git status`, `git branch`, `git diff HEAD`) rather than assuming the working context matches what was last discussed.

Specific case: "review the current diff" or "review this" without a PR number means review the local uncommitted or unpushed changes (`git diff HEAD`), not a PR. Run `git diff HEAD` directly rather than invoking the `review` skill, which assumes a PR context.

Specific case: "block this PR", "comment on this PR", "label this PR", "approve this PR", and similar requests about "this PR" / "this branch" / "this issue" without a number must trigger a state check (`gh pr list`, `git branch --show-current` + `gh pr list --head <branch>`) — even when an earlier turn in the same session named a specific PR. A salient antecedent does not survive a silent context-switch. Failure mode: a multi-action request (labels, blocking, comments) lands on the wrong PR, requiring retraction of the wrong-PR labels and comments while redoing the work on the right PR. The cost of the state check is one shell command. The cost of acting on the wrong antecedent is visible to reviewers.

## Reviewing

- Stay within the requested scope — do not propose or make code changes unless asked. A review request is a read-only task unless the user explicitly says to fix what's found.

## Pull Requests

- Always create PRs as 'drafts'.
- Keep PR descriptions up to date with changes – e.g. TODO lists, deferred work, references to ADRs, &c.
- Never push to GitHub on your own — not after commits, not as a prerequisite for creating a PR, not for any reason. If the branch needs to be pushed first (e.g., to open a PR), ask the user to push. The only exception: if the only unpushed changes involve CI/CD or GitHub Actions, flag it and let the user decide.
- Never merge PRs on the user's behalf — even when the PR is approved, CI is green, and the user says "looks clean". Merging is the user's action, paired with pushes. Confirm readiness (state, checks, conflicts), surface anything off, and leave the merge button to the user. The same applies to closing PRs and deleting remote branches: confirm and surface, do not execute. Failure mode: autonomous merging denies the user the final-eyeball moment before main moves.

## Commenting

- Preserve existing comments when editing code. Comments are for humans, not the parser. Never silently drop them as collateral during edits.
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
- **No automated safety net before compaction.** Claude Code's `PreCompact` hook cannot inject context for the model to react to — it can only block compaction or show a user-facing message. The model must therefore take responsibility for noticing when compaction is approaching and surfacing a handoff suggestion *before* it lands. Bias toward suggesting earlier rather than later: false positives are cheap. A missed handoff before compaction means the context is lost.
- Any one of these signals is enough to surface a handoff suggestion:
  - 5+ file edits, multiple commits, or non-trivial decisions that wouldn't be obvious from the diff alone
  - The user pauses, switches topic, or signals winding down
  - The conversation has been long enough that compaction is plausible (extended back-and-forth, large tool outputs)
  - A new phase of work is starting that depends on context from the previous phase
- **Save external artifacts as they're produced, not at handoff time.** When the work in a session produces something that lives outside the repo — a draft message sent to a teammate, an ASCII wireframe in a chat window, a question put to a stakeholder — save a copy under `.claude/handoffs/artifacts/` while the artifact is still in front of you. The `session-handoff` skill covers how a handoff should reference these. The rule's half is timing, because by handoff-write time a chat-only draft may already be scrolled out of context. The `artifacts/` subdirectory keeps companion files out of the way of the `SessionStart` hook and `list_handoffs.py`, which only see top-level `.md` files. Failure mode this prevents: the stakeholder replies "I like B" days later, and the resuming session can't reconstruct B without interrupting the user.
- A `SessionStart` hook surfaces the most recent handoff (within 7 days) at session start. When that reminder fires, surface it to the user on the first turn and ask whether to resume — do not silently judge from the prompt alone. The filename slug is rarely enough signal to decide on its own, and a missed continuation means working without the prior context. Phrase the question briefly (e.g., "There's a recent handoff: `<slug>`. Resume?") and let the user decide. **Exception:** if the first message already answers the question, honor it directly instead of re-asking — "resume" / "continue where we left off" → resume from the handoff; an explicit "start fresh" / "ignore the handoff" → skip it. The "don't judge from the prompt alone" guard is against *inferring* a decline from a merely unrelated-looking prompt (the costly silent-skip), not against honoring an explicit instruction. A prompt that's topically unrelated but doesn't explicitly decline (e.g. "add a logout button", no mention of the handoff) still gets the question.
