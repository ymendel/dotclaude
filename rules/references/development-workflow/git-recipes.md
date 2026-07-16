# Development Workflow — Edge-Case Git Recipes

Consult-on-demand companion to the Version Control section of `development-workflow.md`, which stays always-loaded. Load this when you hit one of these specific git situations — they come up rarely, so the recipes don't need to be resident. Extracted per [ADR 0007](../../../docs/adr/0007-progressive-disclosure-for-rules.md) (destination 4).

## Rewording a non-HEAD commit

To reword a non-HEAD commit, ask the user to run `git rebase -i` interactively. Scripted workarounds (GIT_EDITOR overrides, chained amends) are unreliable and cause cascading message corruption.

## Splitting one file's changes across commits

To split a file's changes across commits, ask the user to run `git add -p` interactively. Once the partial stage is done, use plain `git add <file>` for any remaining hunks — no further interactivity needed. When the hunks aren't cleanly splittable (adjacent additions that collapse into one `git add -p` hunk, &c.), an alternative is to edit the file in-place to revert one change, commit the remaining one, then re-apply the reverted change for the next commit. Use this as a fallback when the changes are independent and the full text of both is recoverable from context — but verify the reverted state leaves the other change committable on its own, and don't reach for it when many hunks or files are in play (the manual juggling gets error-prone fast).

## Branching off a remote-tracking ref (the `--no-track` artifact)

When branching off a remote-tracking ref to start from the current remote tip (`git switch -c foo origin/main`), pass `--no-track`. Otherwise git's default `branch.autoSetupMerge` sets `origin/main` as the new branch's upstream, so `git status` reports the branch tracking `main` (`[ahead N]` against it) and a bare `git pull` would pull main. The artifact clears on the first `git push -u`, but reads as misleading until then. Alternative: advance the local ref first (`git fetch origin main:main`) and branch off local `main`, which doesn't auto-track. Branching off a stale local `main` without `--no-track` avoids the artifact but risks a stale base — the worse of the two. (`git checkout -b` behaves identically. The choice of verb doesn't change the tracking.)
