# Feedback

Overflow for rules and feedback that don't fit an existing rule file. When in doubt, capture a lesson here rather than agonizing over its permanent home or skipping it — but this file loads into context every session like any rule, so it's revisable staging, not free staging. Periodically review: if an entry has grown into a pattern or belongs with a coherent topic, extract it into an appropriate rule file. Prune what hasn't earned its place rather than letting the file accrete.

## Don't reflexively `cd` into the working directory

The Bash working directory is set to the project root at session start and persists across calls. Do not prefix commands with `cd /path/to/project` — it is unnecessary, and a `cd` combined with output redirection (`cd ... 2>/dev/null; <command>`) trips a security approval rule ("path resolution bypass"), forcing the user to manually approve every such command.

**Why:** the reflex tends to appear after working across multiple directories in one session (e.g. the project plus `~/.claude`), out of a wish to "be sure" of the cwd. But Read/Edit on a file elsewhere does not change the shell's cwd, and tool calls don't drift it. The `cd` adds nothing and costs an approval each time. This has recurred across sessions.

**A subtler consequence — silent wrong output, no approval prompt:** a `cd` into a *subdirectory of the project* (not just an unrelated dir) persists across calls the same way, and cwd-dependent tools then act on the wrong location without erroring — e.g. a handoff script writing relative to `os.getcwd()` lands its output in a subtree that the `SessionStart` hook and `list_handoffs.py` never scan (they see only the root), so nothing errors and the mistake is visible only by reading the tool's output path. This is distinct from the redirect/approval consequence above: that one is loud (an approval prompt), this one is silent.

**How to apply:** run commands directly — cwd is already the project root. If a command genuinely needs a different directory, pass it explicitly (`git -C <path>`, an absolute path) rather than `cd`-ing, and never combine `cd` with output redirection. This holds for project subdirectories too — a `cd` into `skills/` or `docs/` persists and will misdirect any cwd-relative tool (handoff scripts, generators, anything calling `getcwd`). When a tool's output lands somewhere unexpected, check `pwd` before assuming the tool is wrong.

**Now gated:** `hooks/reflexive-cd-guard.sh` (a PreToolUse Bash hook, per ADR 0004's rule-vs-hook split) blocks the narrowest slice of this reflex — a leading `cd` whose target is the project root, the cwd, or `.` — with exit 2 and a pointer back to this rule. The gate enforces the mechanical case. This prose stays the discoverable *why*. A `cd` to any *other* directory still passes the gate, so the rest of this rule (subdir persistence, the `git -C` preference) remains prose-enforced.

## Disambiguate global vs. project scope before editing

When the user refers to "the rule", "the skill", "settings.json", "the hook", or a similar artifact that exists in both global (`~/.claude/...`) and project-local (`.claude/...`, `CLAUDE.md`) forms, ask which scope is meant before editing — unless the surrounding context makes it unambiguous (e.g., the user just opened the global file, or just named a project-only artifact).

**Why:** Ambiguity here has consistently produced edit-and-revert cycles where Claude guessed the wrong scope. The user shouldn't have to talk like a robot ("the global naming-analyzer skill") to keep Claude from guessing — one disambiguating question is cheaper than a wrong edit.

**How to apply:** A one-line question is enough: "Global `~/.claude/settings.json` or project `.claude/settings.json`?" Do not begin editing or searching until the scope is settled. When the context truly is unambiguous, proceed without asking — over-asking is its own friction.

**Exception — the `dotclaude` repo itself:** `~/.claude` is a symlink to this repo (per its Makefile). The two paths are one tree, one set of files — there is no global-vs-project distinction to resolve. Don't diff `~/.claude/X` against `dotclaude/X`, and don't ask which scope. Editing either edits the live config. When the answer to "how do these two paths relate" is wanted, it's structural (the symlink) and documented (Makefile, README) — reach for those, not an empirical diff. See `settings.md`'s `~/.claude → dotclaude` section for the permission-matching consequences of the symlink.

## Show templates in full, don't compress them

When reviewing or designing a skill, "don't restate what Claude already knows" (the standard knowledge-delta rubric) applies to *concepts and procedures*, not to *templates and reference artifacts*. A template is the artifact the model is supposed to produce — showing it in full is what makes the output reliable. Compressing it to "you know the standard shape, right?" risks drift in exactly the parts that matter (heading capitalization, status vocabulary, section ordering, project-specific overlays like a required prefix or label).

**How to apply:** When skill-judge or any similar review flags a section as "Claude already knows this", ask whether the section is a *template/example to copy* or *guidance to internalize*. If template/example, the right action is keep-and-tighten (drop redundant examples, keep the canonical one), not compress-to-pointer. If guidance, the standard compression rule applies.

## Don't escape inside single-quoted heredocs

In a `<<'EOF'` heredoc (single-quoted delimiter), the shell preserves content literally — no parameter expansion, no command substitution, no backslash processing. Backticks, double-quotes, and dollar signs inside one don't need escaping. Doing so ships the literal backslash through to whatever consumes the heredoc.

**How to apply:** When writing inside `<<'EOF'`, write content as-is. The single-quoted delimiter is the explicit "treat this as a string literal" signal, so escaping inside it always overshoots. If you find yourself reaching for a backslash inside a heredoc, check the opening — if it's `'EOF'`, don't. (The same caution applies in reverse to `<<EOF` without quotes, where backticks and dollar signs *do* need escaping if you want them literal.)

## Surface env-specific values via tooling output

When a setup or operational doc needs the reader to obtain an environment-specific value (an ID, mapping key, token-equivalent, &c. that differs across environments and isn't part of baseline or seed data), check first whether existing tooling already produces or can produce that value as part of its normal output. If it does, structure the documented workflow around that output: run the tool → read the values from its output → plug them back in → continue. Only fall back to "look it up in the admin UI" when no tooling path exists.

**Why:** the reflex when writing "you need value X" is to point the reader at the external system that owns X. That works but costs context switches, makes the doc dependent on whatever the external UI looks like this week, and breaks when the reader doesn't have access to that UI. Tooling output as the source of truth has fewer moving parts, fewer stale screenshots, and the workflow becomes self-checking — if the value the tooling shows doesn't match what's expected, the discrepancy is visible in the same shell session.

**How to apply:** at any setup step that says (or wants to say) "now go look up X in <admin UI>", ask: does any command we already document for this system surface X — even as part of error output, an "unmatched" / "diff" / "stale" report, a dry-run, or a list/inspect mode? If yes, restructure the step to use that command's output. The structure usually looks like: (1) run command — produces output listing the needed values; (2) update local data with those values; (3) re-run command — now succeeds. Honest about its own limits: when no tooling path exists, the admin-UI lookup is the right answer, not a fallback to apologize for.

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

## Format the fragile markdown constructs at generation time

Markdown has no notion of an error — a CommonMark parser maps *any* input to *some* output. So there is no "invalid markdown" a check rejects — there is only a small set of **fragile constructs** that different implementations resolve differently, so the same source renders one way in a lenient renderer and another in a strict one. These bite only in *durable deliverables opened by a strict renderer* — a committed doc, a README, an IDE preview (Zed), a PR body — never in the terminal where most generated markdown is judged. Format them deliberately when generating markdown bound for such a destination. Don't rely on a post-hoc linter to catch them — see the last point.

The fragile constructs, most-common first:

- **Fenced code inside a list item** — the headline case. Indent the fence markers *and every code line* to the list-item content column (2 spaces after `- `). A mismatch — fence at 2 spaces, code at column 0 — makes strict parsers mis-pair the fences: the code escapes into a paragraph and the following block gets swallowed into a phantom code box. Alternative: lift the code out of the bullet into its own top-level block. When the recipe is more than a line or two, lifting it out reads better anyway.
- **Continuation content in a list** (a second paragraph, a nested list, a blockquote under a bullet) — must align to the parent item's content column, same discipline as the fenced-code case.
- **Tables** — cells cannot hold block content (no fenced code, no lists inside a cell). Alignment-row and pipe-escaping handling also varies across renderers.
- **Raw HTML mixed into markdown** — renderer-dependent and often sanitized/stripped (GitHub strips much of it), so don't rely on it rendering.
- **Nested blockquotes and blockquote-plus-code combinations** — indentation and `>` nesting are inconsistently handled.
- **Missing blank lines around fenced blocks and lists** — a fence or list run directly against surrounding prose (no blank line) is a frequent trip — `markdownlint` flags it as MD031/MD032.

**Why:** the failure is invisible at generation time. The terminal and chat surfaces render leniently (or not at all), markdown never errors, so nothing pushes back — the defect only appears once the artifact is opened downstream in a strict renderer, by which point it has shipped.

**A linter is a weak check, not the fix.** `markdownlint` and its kin catch this only obliquely — they flag *where* something is structurally off (a mis-paired fence trips MD040 plus the MD031/MD032 blank-line rules) but never name the cause, and out of the box they bury that signal under line-length noise unless the config is tuned. Reserve them, tuned, for committed deliverables where a specific renderer matters — not as a net over everything generated. The durable guard is knowing the fragile-construct list above and formatting for it up front.

## Don't point at tool output as a shared visible surface

When claiming there's a finding to see — "the standout is X", "as the table above shows", "the output confirms" — reproduce the load-bearing part *in the chat message itself*. Do not reference "the table above" / "the output above" pointing at a Bash result or other tool output. Tool outputs are not a reliable shared surface: depending on the user's interface they may be collapsed, scrolled off, or not rendered as the model imagined (a sorted plaintext dump is not a "table" the user sees). So "see above" points at something the user may not have in front of them.

**Why:** this has recurred — the user flags "another time you said there's something to see and I don't see it." The model treats its own tool output as if it were part of the conversation the user reads, but the user reads the *messages*. A claimed-visible finding whose data lives only in a tool result is, to the user, an assertion with no visible support.

**How to apply:** when a tool call produces data a decision rides on, restate the load-bearing part in the message — a short markdown table, the ranked list, the specific numbers — even if it duplicates the tool output. The tool output is scratch. The message is the artifact. Sibling of the AskUserQuestion-preview lesson above (decision-critical detail must live where the user reliably sees it, not in a clipped preview) and of `long-form-output.md` (which governs *where* long content goes — file vs. inline; this governs *not* offloading a visible claim onto ephemeral tool output at all).
