# Development Workflow — Edge-Case Git Recipes

> Not loaded in context by default. See `rules/development-workflow.md` for behavioral guidance.

## Changing a non-HEAD commit

Split by whether the change touches the *message* or only the *content*.

**Rewording** — ask the user to run `git rebase -i` interactively. Scripted workarounds (GIT_EDITOR overrides, chained amends) are unreliable and cause cascading message corruption.

**Folding content in** — do it yourself, no interactivity required. Stage the change, `git commit --fixup <target-sha>`, then `git rebase --autosquash <target-sha>^`. A `fixup!` commit keeps the target's message verbatim, so no editor is ever invoked, and `--autosquash` has worked outside `-i` since git 2.38. This is the case for "that hunk belongs in an earlier commit" — an allowlist entry the rule it implements arrived without, a file the commit should have carried.

**Add `--autostash` when the working tree is dirty**, which it usually is, since the fixup is being folded in mid-session with other work still in progress. Rebase refuses to start against unstaged changes to tracked files, and that refusal is the common way this recipe stalls. The flag stashes and reapplies around the rebase, so unrelated in-flight edits come back untouched. Confirm they did rather than assuming: a stash that cannot reapply is left behind as an entry, which is the one case that puts work in the stash space the user otherwise avoids (`development-workflow.md` on branches over `git stash`).

### Fixup or a new commit?

Fixup when the target was **incomplete as authored** — the hunk was always meant to be in it and its absence was an oversight. A new commit when you **learned something after it landed**.

The test is whether the earlier commit was *wrong* or merely *earlier*. Folding a later discovery backwards rewrites history to claim knowledge the commit did not have, and erases that the decision was taken without it — which is often the more useful half of the record. Repair belongs in the target. A record belongs after it.

Failure mode this prevents: the reword restriction gets read as covering every non-HEAD change, so a mechanical fixup is handed back to the user as though it needed their hands — or worse, gets abandoned and the hunk lands as a stray follow-up commit that has to be explained. And in the other direction, `--fixup` gets reached for on anything touching an earlier commit's subject matter, quietly backdating discoveries into commits that predate them.

## Promoting a run of unpushed commits

The practice this serves: commit often and small while work is unpushed, treating each commit as a checkpoint rather than a finished unit, then promote the run into real commits once the work reaches a good spot. Every promotion shape is scriptable without `git rebase -i`.

- **Squash a contiguous run into one commit** — `git reset --soft <first-checkpoint>^`, then commit the collected tree with `git commit -F <file>`. This is the one-commit `reset --soft HEAD~1` recipe in `development-workflow.md` generalized to a range.
- **Fold a stray hunk into an earlier commit** — see *Changing a non-HEAD commit* above.
- **Split one checkpoint into two** — `git reset --soft <checkpoint>^` puts its whole tree back in the index; stage and commit in pieces from there. The within-a-single-file case is the section below.
- **Reorder** — cherry-pick the checkpoints onto a fresh base in the order wanted, rather than moving them in place.

Promotion *authors* messages rather than editing existing ones, which is why it never hits the reword restriction above — `reset --soft` writes a fresh commit and `--fixup` reuses its target's message verbatim. Only a commit that must keep its content and change nothing but its text needs the user.

The promotion step is load-bearing, not cosmetic: a long run of unpromoted checkpoints is harder to review than a few good commits, so the practice only pays if promotion happens before anything is pushed. Once pushed, the run is history — leave it alone.

## Splitting one file's changes across commits

To split a file's changes across commits, ask the user to run `git add -p` interactively. Once the partial stage is done, use plain `git add <file>` for any remaining hunks — no further interactivity needed. When the hunks aren't cleanly splittable (adjacent additions that collapse into one `git add -p` hunk, &c.), an alternative is to edit the file in-place to revert one change, commit the remaining one, then re-apply the reverted change for the next commit. Use this as a fallback when the changes are independent and the full text of both is recoverable from context — but verify the reverted state leaves the other change committable on its own, and don't reach for it when many hunks or files are in play (the manual juggling gets error-prone fast).

## Resolving the `Gemfile.lock` conflict when dependabot lands first

The preferred order is to land your own branches before merging dependabot's PRs, which pushes the lockfile resolution onto the bot (see `development-workflow.md`). When that order can't be had — dependabot merged first, and your branch now has to come onto the bumped `main` — the resolution is yours, and two choices matter.

**Merge, don't rebase.** A rebase re-hits the conflict once per lockfile-touching commit on your branch. A merge resolves it once. The user's default is to rebase feature branches freely, so this is the case that argues against the default.

**Regenerate, don't hand-merge.** Do not edit conflict markers in `Gemfile.lock` by hand. Take one side wholesale as the base and regenerate with `bundle`. Watch the `BUNDLED WITH` stanza afterwards — `bundle` can silently revert a deliberate pin to whatever the other side carried, and the revert is easy to miss in a lockfile diff that is already large.

## Branching off a remote-tracking ref (the `--no-track` artifact)

When branching off a remote-tracking ref to start from the current remote tip (`git switch -c retroactive-architecture-adrs origin/main`), pass `--no-track`. Otherwise git's default `branch.autoSetupMerge` sets `origin/main` as the new branch's upstream, so `git status` reports the branch tracking `main` (`[ahead N]` against it) and a bare `git pull` would pull main. The artifact clears on the first `git push -u`, but reads as misleading until then. The symptom that most often surfaces it — often sessions after creation — is a bare `git push` failing with `The upstream branch of your current branch does not match the name of your current branch` (under the default `push.default = simple`); that error is this artifact, not a problem with the commits, and `git push -u origin HEAD` both pushes to a same-named remote branch and re-points the upstream to clear it. Prevention belongs at creation (`--no-track`), not at this push. Alternative: advance the local ref first (`git fetch origin main:main`) and branch off local `main`, which doesn't auto-track. Branching off a stale local `main` without `--no-track` avoids the artifact but risks a stale base — the worse of the two. (`git checkout -b` behaves identically. The choice of verb doesn't change the tracking.)
