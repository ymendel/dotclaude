# Feedback

Overflow for rules and feedback that don't fit an existing rule file. When in doubt, capture a lesson here rather than agonizing over its permanent home or skipping it — but this file loads into context every session like any rule, so it's revisable staging, not free staging. Periodically review: if an entry has grown into a pattern or belongs with a coherent topic, extract it into an appropriate rule file. Prune what hasn't earned its place rather than letting the file accrete.

## Don't reflexively `cd` into the working directory

The Bash working directory is set to the project root at session start and persists across calls. Do not prefix commands with `cd /path/to/project` — it is unnecessary, and a `cd` combined with output redirection (`cd ... 2>/dev/null; <command>`) trips a security approval rule ("path resolution bypass"), forcing the user to manually approve every such command.

**Why:** the reflex tends to appear after working across multiple directories in one session (e.g. the project plus `~/.claude`), out of a wish to "be sure" of the cwd. But Read/Edit on a file elsewhere does not change the shell's cwd, and tool calls don't drift it. The `cd` adds nothing and costs an approval each time. This has recurred across sessions.

**A subtler consequence — silent wrong output, no approval prompt:** a `cd` into a *subdirectory of the project* (not just an unrelated dir) persists across calls the same way, and cwd-dependent tools then act on the wrong location without erroring — e.g. a handoff script writing relative to `os.getcwd()` lands its output in a subtree that the `SessionStart` hook and `list_handoffs.py` never scan (they see only the root), so nothing errors and the mistake is visible only by reading the tool's output path. This is distinct from the redirect/approval consequence above: that one is loud (an approval prompt), this one is silent.

**How to apply:** run commands directly — cwd is already the project root. If a command genuinely needs a different directory, pass it explicitly (`git -C <path>`, an absolute path) rather than `cd`-ing, and never combine `cd` with output redirection. This holds for project subdirectories too — a `cd` into `skills/` or `docs/` persists and will misdirect any cwd-relative tool (handoff scripts, generators, anything calling `getcwd`). When a tool's output lands somewhere unexpected, check `pwd` before assuming the tool is wrong.

**Now gated:** `hooks/reflexive-cd-guard.sh` (a PreToolUse Bash hook, per ADR 0004's rule-vs-hook split) blocks both hazard shapes of this reflex — a leading `cd` whose target is the project root / cwd / `.` (redundant), *and* a leading `cd` into any project subdirectory (persists, misdirects cwd-relative tools) — with exit 2 and a pointer back to this rule. It resolves symlinks, so a `cd` through the `~/.claude → dotclaude` alias into a subdir is caught too. What still passes the gate, by design: a reverting subshell `(cd <dir> && <cmd>)` — the sanctioned way to run from another directory; a `cd` *out* of the project (`..`, an unrelated absolute path, `cd -`); a runtime-expansion target it can't resolve (`cd $VAR`); and a `cd` into a nonexistent subdir (the real `cd` fails, so no drift). This prose stays the discoverable *why*; the `git -C` / absolute-path / subshell preference is what the gate steers toward.

## Don't escape inside single-quoted heredocs

In a `<<'EOF'` heredoc (single-quoted delimiter), the shell preserves content literally — no parameter expansion, no command substitution, no backslash processing. Backticks, double-quotes, and dollar signs inside one don't need escaping. Doing so ships the literal backslash through to whatever consumes the heredoc.

**How to apply:** When writing inside `<<'EOF'`, write content as-is. The single-quoted delimiter is the explicit "treat this as a string literal" signal, so escaping inside it always overshoots. If you find yourself reaching for a backslash inside a heredoc, check the opening — if it's `'EOF'`, don't. (The same caution applies in reverse to `<<EOF` without quotes, where backticks and dollar signs *do* need escaping if you want them literal.)

## Copy off-disk state before overwriting it when a pending decision depends on it

Before overwriting or discarding on-disk-only state — uncommitted working-tree changes, gitignored or untracked files, scratch output — that an open decision or a proposed next step depends on, save a copy aside first. Git won't recover it: `git checkout` / `cp`-to-restore reflexes assume the thing being clobbered lives in history, and this state doesn't. The sharpest trigger is overwriting the very artifact an option *you just proposed* would need — that action quietly kills your own proposal.

This is not an always-do. Routine overwrites of regenerable or uninteresting files need no copy. It fires only when the on-disk-only state is load-bearing for a comparison or decision in play.

**How to apply:** when about to overwrite or discard uncommitted/untracked/scratch state, ask whether any decision currently in play — especially an option you just offered — would want to read that exact state later. If yes, copy it to a scratch path first (project `tmp/`, the session scratchpad). This composes with `honesty.md`'s *Surface Doubts Your Own Correction Reveals* — both catch an action that undermines a position you just took. That rule catches it in prose, this one catches it in a destructive file operation.

## Don't put decision-critical detail only in an AskUserQuestion preview — previews clip at a height you can't see

When passing `preview` content on an AskUserQuestion option, never rely on the preview to carry information the user needs in order to choose. The picker renders previews in a pane sized to the user's terminal — a height you can't observe — and clips overflow to a "N lines hidden" marker with no scroll. On a short terminal even a two-or-three-line preview can collapse to a single visible line, so no preview length reliably fits.

**Why:** the available height of the preview pane can't be detected, so there's no judging what length will fit — even a two-or-three-line preview can collapse to a single visible line. The user can enlarge the pane, but that's not something to count on or measure.

**How to apply:** treat previews as an optional visual aid whose absence would not block the decision — a mockup or snippet the user compares *if* it renders. Keep everything load-bearing (what each option means, tradeoffs, the recommendation) in the chat message accompanying the question, where nothing is clipped. When in doubt, skip the preview and rely on labels + descriptions + prose framing in chat.

## A malformed path won't error in Write the way it does in the shell — verify where it landed

File tools take absolute paths. Build each one clean from the project root. Don't splice a `../` segment into the middle. Such a path resolves differently depending on who handles it, and Write is the permissive one:

- **The shell and filesystem resolve `..` against real directories.** `a/b/../c` requires `a/b` to exist — if it doesn't, the command errors. A garbled path passed to `ls`, `cat`, or `rtk read` fails loudly, catching the mistake.
- **Write normalizes `..` lexically, then creates parents.** It collapses `b/..` as text without checking `a/b` exists, then `mkdir -p`'s the result. A garble the filesystem would reject instead resolves to a *different* real location, gets a full directory tree built there, and returns success — nothing pushes back at write time.

So Write offers *less* protection than a shell command here, not more. After writing to any path you assembled rather than copied verbatim from a known-good source, confirm it landed where intended — a quick `ls` of the expected path — instead of trusting the success message.

**How to apply:** build file-tool paths as clean absolutes from the project root, no `..` segments. Treat a mid-path `..` as a signal to re-derive, not submit. After any assembled Write, `ls` the location — Write's success confirms *a* write happened, not that it happened where you meant.

## Don't point at tool output as a shared visible surface

When claiming there's a finding to see — "the standout is X", "as the table above shows", "the output confirms" — reproduce the load-bearing part *in the chat message itself*. Do not reference "the table above" / "the output above" pointing at a Bash result or other tool output. Tool outputs are not a reliable shared surface: depending on the user's interface they may be collapsed, scrolled off, or not rendered as the model imagined (a sorted plaintext dump is not a "table" the user sees). So "see above" points at something the user may not have in front of them.

**Why:** this has recurred — the user flags "another time you said there's something to see and I don't see it." The model treats its own tool output as if it were part of the conversation the user reads, but the user reads the *messages*. A claimed-visible finding whose data lives only in a tool result is, to the user, an assertion with no visible support.

**How to apply:** when a tool call produces data a decision rides on, restate the load-bearing part in the message — a short markdown table, the ranked list, the specific numbers — even if it duplicates the tool output. The tool output is scratch. The message is the artifact. Sibling of the AskUserQuestion-preview lesson above (decision-critical detail must live where the user reliably sees it, not in a clipped preview) and of `long-form-output.md` (which governs *where* long content goes — file vs. inline; this governs *not* offloading a visible claim onto ephemeral tool output at all).
