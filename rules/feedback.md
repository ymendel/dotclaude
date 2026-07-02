# Feedback

Overflow for rules and feedback that don't fit an existing rule file. When in doubt, capture a lesson here rather than agonizing over its permanent home or skipping it — but this file loads into context every session like any rule, so it's revisable staging, not free staging. Periodically review: if an entry has grown into a pattern or belongs with a coherent topic, extract it into an appropriate rule file. Prune what hasn't earned its place rather than letting the file accrete.

## Don't reflexively `cd` into the working directory

The Bash working directory is set to the project root at session start and persists across calls. Do not prefix commands with `cd /path/to/project` — it is unnecessary, and a `cd` combined with output redirection (`cd ... 2>/dev/null; <command>`) trips a security approval rule ("path resolution bypass"), forcing the user to manually approve every such command.

**Why:** the reflex tends to appear after working across multiple directories in one session (e.g. the project plus `~/.claude`), out of a wish to "be sure" of the cwd. But Read/Edit on a file elsewhere does not change the shell's cwd, and tool calls don't drift it. The `cd` adds nothing and costs an approval each time. This has recurred across sessions.

**A subtler consequence — silent wrong output, no approval prompt:** a `cd` into a *subdirectory of the project* (not just an unrelated dir) persists across calls exactly the same way, and cwd-dependent tools then act on the wrong location without erroring. Confirmed 2026-06-24: earlier `cd .../skills` commands — run only to scope a couple of greps, where absolute paths would have done — persisted, and `session-handoff`'s `create_handoff.py`, which writes relative to `os.getcwd()`, created the handoff under `skills/.claude/handoffs/` instead of the project-root `.claude/handoffs/`. There it would have been orphaned: the `SessionStart` hook and `list_handoffs.py` only scan the root. Nothing errored — the file just landed in the wrong subtree, and the mistake was visible only by reading the script's output path. This is distinct from the redirect/approval consequence above: that one is loud (an approval prompt), this one is silent.

**How to apply:** run commands directly — cwd is already the project root. If a command genuinely needs a different directory, pass it explicitly (`git -C <path>`, an absolute path) rather than `cd`-ing, and never combine `cd` with output redirection. This holds for project subdirectories too — a `cd` into `skills/` or `docs/` persists and will misdirect any cwd-relative tool (handoff scripts, generators, anything calling `getcwd`). When a tool's output lands somewhere unexpected, check `pwd` before assuming the tool is wrong.

## Use the skill-authoring skills when authoring a skill

When creating or modifying a skill — even when self-initiated, not because the user typed `/skill-architecture` — invoke the `skill-architecture` skill (to build and validate structure, frontmatter, and description-match firing) and `skill-judge` (to audit quality). Don't hand-roll a `SKILL.md` from nearby examples.

**Why:** On 2026-06-24, building the `knowledge-grill` skill, I wrote `SKILL.md`/`COMPANIONS.md`/`TODO.md` directly with Write, modeling them on existing skills, and never reached for skill-architecture or skill-judge. It wasn't a reasoned decision to skip them — skill creation pattern-matched to "authoring markdown", so the meta-step ("is there a skill for this?") never surfaced. The hand-write had real gaps a later validation pass caught: a missing negative trigger in the description, and a soft dependency on the `adr` skill that would dangle in a skills-only ship.

**How to apply:** Treat "create or edit a skill" as a task with a dedicated skill, the same way ADR work invokes the `adr` skill (which in turn mandates `adr-refine`). Build with skill-architecture, audit with skill-judge — a build → judge → fix loop. This holds especially when the work is self-initiated, which is exactly when the reflex to invoke a matching skill is weakest.

## Disambiguate global vs. project scope before editing

When the user refers to "the rule", "the skill", "settings.json", "the hook", or a similar artifact that exists in both global (`~/.claude/...`) and project-local (`.claude/...`, `CLAUDE.md`) forms, ask which scope is meant before editing — unless the surrounding context makes it unambiguous (e.g., the user just opened the global file, or just named a project-only artifact).

**Why:** Ambiguity here has consistently produced edit-and-revert cycles where Claude guessed the wrong scope. The user shouldn't have to talk like a robot ("the global naming-analyzer skill") to keep Claude from guessing — one disambiguating question is cheaper than a wrong edit.

**How to apply:** A one-line question is enough: "Global `~/.claude/settings.json` or project `.claude/settings.json`?" Do not begin editing or searching until the scope is settled. When the context truly is unambiguous, proceed without asking — over-asking is its own friction.

## Show templates in full, don't compress them

When reviewing or designing a skill, "don't restate what Claude already knows" (the standard knowledge-delta rubric) applies to *concepts and procedures*, not to *templates and reference artifacts*. A template is the artifact the model is supposed to produce — showing it in full is what makes the output reliable. Compressing it to "you know the standard shape, right?" risks drift in exactly the parts that matter (heading capitalization, status vocabulary, section ordering, project-specific overlays like a required prefix or label).

**Why:** Misapplied this on 2026-05-21 when reviewing the `adr` skill via `skill-judge`. Suggested cutting the Nygard template restatement as "Activation, Claude knows this" — but the template was the *artifact*, and the project-specific Consequences-valence prescription was baked into it inline. Cutting it would have undone work just done to make that prescription concrete. User caught it.

**How to apply:** When skill-judge or any similar review flags a section as "Claude already knows this", ask whether the section is a *template/example to copy* or *guidance to internalize*. If template/example, the right action is keep-and-tighten (drop redundant examples, keep the canonical one), not compress-to-pointer. If guidance, the standard compression rule applies.

## Don't escape inside single-quoted heredocs

In a `<<'EOF'` heredoc (single-quoted delimiter), the shell preserves content literally — no parameter expansion, no command substitution, no backslash processing. Backticks, double-quotes, and dollar signs inside one don't need escaping. Doing so ships the literal backslash through to whatever consumes the heredoc.

**Why:** On 2026-05-31, I filed a GitHub issue with `gh issue create --body "$(cat <<'EOF' ... EOF)"` and reflexively escaped backtick fences (`` \`\`\` ``) and quoted Ruby strings (`\"`) inside the body. The result rendered with literal backslashes wherever markdown was supposed to format — broken code fences, broken quotes. User caught it and asked for a fix. The escaping was a reflex carried over from double-quoted contexts, where backslashes do matter.

**How to apply:** When writing inside `<<'EOF'`, write content as-is. The single-quoted delimiter is the explicit "treat this as a string literal" signal, so escaping inside it always overshoots. If you find yourself reaching for a backslash inside a heredoc, check the opening — if it's `'EOF'`, don't. (The same caution applies in reverse to `<<EOF` without quotes, where backticks and dollar signs *do* need escaping if you want them literal.)

## Surface env-specific values via tooling output

When a setup or operational doc needs the reader to obtain an environment-specific value (an ID, mapping key, token-equivalent, &c. that differs across environments and isn't part of baseline or seed data), check first whether existing tooling already produces or can produce that value as part of its normal output. If it does, structure the documented workflow around that output: run the tool → read the values from its output → plug them back in → continue. Only fall back to "look it up in the admin UI" when no tooling path exists.

**Why:** the reflex when writing "you need value X" is to point the reader at the external system that owns X. That works but costs context switches, makes the doc dependent on whatever the external UI looks like this week, and breaks when the reader doesn't have access to that UI. Tooling output as the source of truth has fewer moving parts, fewer stale screenshots, and the workflow becomes self-checking — if the value the tooling shows doesn't match what's expected, the discrepancy is visible in the same shell session. Confirmed on 2026-06-06 when documenting a setup step that needed environment-specific identifiers: the tool's existing "unmatched" output was repurposed as the discovery mechanism for the values needed, then re-running it after updates verified the linkage. User explicitly validated the choice ("clever, in not a bad way").

**How to apply:** at any setup step that says (or wants to say) "now go look up X in <admin UI>", ask: does any command we already document for this system surface X — even as part of error output, an "unmatched" / "diff" / "stale" report, a dry-run, or a list/inspect mode? If yes, restructure the step to use that command's output. The structure usually looks like: (1) run command — produces output listing the needed values; (2) update local data with those values; (3) re-run command — now succeeds. Honest about its own limits: when no tooling path exists, the admin-UI lookup is the right answer, not a fallback to apologize for.

## Copy off-disk state before overwriting it when a pending decision depends on it

Before overwriting or discarding on-disk-only state — uncommitted working-tree changes, gitignored or untracked files, scratch output — that an open decision or a proposed next step depends on, save a copy aside first. Git won't recover it: `git checkout` / `cp`-to-restore reflexes assume the thing being clobbered lives in history, and this state doesn't. The sharpest trigger is overwriting the very artifact an option *you just proposed* would need — that action quietly kills your own proposal.

This is not an always-do. Routine overwrites of regenerable or uninteresting files need no copy. It fires only when the on-disk-only state is load-bearing for a comparison or decision in play.

**Why:** On 2026-07-01, restoring a TUI-scrambled `settings.json` to its original key order, I had *just* proposed "Option B" — adopt the TUI's key order as canonical, which structurally needs the scrambled version as its reference. Then I `cp`'d the original back over the working tree to do Option A, destroying the only on-disk copy of the scrambled version. The loss was invisible until the user asked where I'd saved it. I got lucky: I'd Read the full file into context and could reconstruct it with `jq`. The dependency became real the moment I floated Option B — that was the point to preserve the file, not after.

**How to apply:** when about to overwrite or discard uncommitted/untracked/scratch state, ask whether any decision currently in play — especially an option you just offered — would want to read that exact state later. If yes, copy it to a scratch path first (project `tmp/`, the session scratchpad). This composes with `honesty.md`'s *Surface Doubts Your Own Correction Reveals* — both catch an action that undermines a position you just took; that rule catches it in prose, this one catches it in a destructive file operation.

## Don't put decision-critical detail only in an AskUserQuestion preview — previews clip at a height you can't see

When passing `preview` content on an AskUserQuestion option, never rely on the preview to carry information the user needs in order to choose. The picker renders previews in a pane sized to the user's terminal — a height you can't observe — and clips overflow to a "N lines hidden" marker with no scroll. On a short terminal even a two-or-three-line preview can collapse to a single visible line, so no preview length reliably fits.

**Why:** On 2026-07-02, offering three next-step options with multi-line previews, the previews clipped to one visible line each ("N lines hidden") on the user's short terminal, hiding the content meant to inform the choice. My first correction blamed "overloading" the preview — wrong, because the available height can't be detected, so there's no judging what fits. The user can enlarge the pane, but that's not something you can count on or measure.

**How to apply:** treat previews as an optional visual aid whose absence would not block the decision — a mockup or snippet the user compares *if* it renders. Keep everything load-bearing (what each option means, tradeoffs, the recommendation) in the chat message accompanying the question, where nothing is clipped. When in doubt, skip the preview and rely on labels + descriptions + prose framing in chat.
