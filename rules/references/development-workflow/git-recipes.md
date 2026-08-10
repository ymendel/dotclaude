# Development Workflow — Edge-Case Git Recipes

> Not loaded in context by default. See `rules/development-workflow.md` for behavioral guidance.

## Changing a non-HEAD commit

Split by whether the change touches the *message* or only the *content*.

**Rewording** — ask the user to run `git rebase -i` interactively. Scripted workarounds (GIT_EDITOR overrides, chained amends) are unreliable and cause cascading message corruption.

**Folding content in** — do it yourself, no interactivity required. Stage the change, `git commit --fixup <target-sha>`, then `git rebase --autosquash <target-sha>^`. A `fixup!` commit keeps the target's message verbatim, so no editor is ever invoked, and `--autosquash` has worked outside `-i` since git 2.38. This is the case for "that hunk belongs in an earlier commit" — an allowlist entry the rule it implements arrived without, a file the commit should have carried.

Failure mode this prevents: the reword restriction gets read as covering every non-HEAD change, so a mechanical fixup is handed back to the user as though it needed their hands — or worse, gets abandoned and the hunk lands as a stray follow-up commit that has to be explained.

## Splitting one file's changes across commits

To split a file's changes across commits, ask the user to run `git add -p` interactively. Once the partial stage is done, use plain `git add <file>` for any remaining hunks — no further interactivity needed. When the hunks aren't cleanly splittable (adjacent additions that collapse into one `git add -p` hunk, &c.), an alternative is to edit the file in-place to revert one change, commit the remaining one, then re-apply the reverted change for the next commit. Use this as a fallback when the changes are independent and the full text of both is recoverable from context — but verify the reverted state leaves the other change committable on its own, and don't reach for it when many hunks or files are in play (the manual juggling gets error-prone fast).

## Resolving the `Gemfile.lock` conflict when dependabot lands first

The preferred order is to land your own branches before merging dependabot's PRs, which pushes the lockfile resolution onto the bot (see `development-workflow.md`). When that order can't be had — dependabot merged first, and your branch now has to come onto the bumped `main` — the resolution is yours, and two choices matter.

**Merge, don't rebase.** A rebase re-hits the conflict once per lockfile-touching commit on your branch. A merge resolves it once. The user's default is to rebase feature branches freely, so this is the case that argues against the default.

**Regenerate, don't hand-merge.** Do not edit conflict markers in `Gemfile.lock` by hand. Take one side wholesale as the base and regenerate with `bundle`. Watch the `BUNDLED WITH` stanza afterwards — `bundle` can silently revert a deliberate pin to whatever the other side carried, and the revert is easy to miss in a lockfile diff that is already large.

## Branching off a remote-tracking ref (the `--no-track` artifact)

When branching off a remote-tracking ref to start from the current remote tip (`git switch -c retroactive-architecture-adrs origin/main`), pass `--no-track`. Otherwise git's default `branch.autoSetupMerge` sets `origin/main` as the new branch's upstream, so `git status` reports the branch tracking `main` (`[ahead N]` against it) and a bare `git pull` would pull main. The artifact clears on the first `git push -u`, but reads as misleading until then. The symptom that most often surfaces it — often sessions after creation — is a bare `git push` failing with `The upstream branch of your current branch does not match the name of your current branch` (under the default `push.default = simple`); that error is this artifact, not a problem with the commits, and `git push -u origin HEAD` both pushes to a same-named remote branch and re-points the upstream to clear it. Prevention belongs at creation (`--no-track`), not at this push. Alternative: advance the local ref first (`git fetch origin main:main`) and branch off local `main`, which doesn't auto-track. Branching off a stale local `main` without `--no-track` avoids the artifact but risks a stale base — the worse of the two. (`git checkout -b` behaves identically. The choice of verb doesn't change the tracking.)
