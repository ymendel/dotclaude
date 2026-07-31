# Long-Form Output

The principle: **content the user needs in order to read or decide must live where they reliably see it.**

The main case is long output: when a turn's output is long enough that the user would have to scroll back and forth in the conversation to re-read or compare sections, write it to a file and post a short pointer in the chat instead of dumping it inline. The two non-file cases — a decision-critical option and a claimed-visible finding — get their own sections near the end: those belong in the chat message itself, never in an ephemeral tool result or a preview pane that clips.

## What counts as long enough

- **Content the user will want to respond to point-by-point.** A file makes redlining possible without quoting each part back. On its own this is now a weak trigger — a fullscreen TUI lets the user work an inline list in place — so file when the content *also* meets one of the bars below.
- Multi-section structured documents — plans, design docs, audits, code review findings, post-implementation reports.
- Output worth sharing or coming back to over multiple turns.

## What does not need a file

- Short answers, even when they include a small code block.
- Tool-call updates and status sentences.
- A single explanation paragraph, a short list, or a brief decision summary.

## How to apply

- Pick a sensible path inside the project (`docs/`, alongside related artifacts, `.claude/handoffs/` for handoffs, `.claude/reviews/` for code reviews). Don't create a new top-level directory.
- Write the file, then post a short pointer in the chat: filename, one to three sentences of framing, and the specific things to look at. The pointer goes in the chat, the content goes in the file.
- If the output is genuinely throwaway / one-shot and unlikely to be re-read, ask before creating the file rather than defaulting to one.

## Alternatives and rewrites go to a new file

When the user has an existing filed draft and asks to see an alternative version, a rewrite, or a different angle — "show me a version that's more in my voice", "what would this look like if we cut X", "give me a tighter version" — write the new version to a new file with a short suffix that signals what it is (`-voice`, `-tight`, `-v2`, &c.), not over the existing one. Surface both paths in the pointer so the user can compare.

The same applies to incremental drafts the user is *still reading*: if they say "I'm reading this now", don't overwrite while they're reading. Wait for feedback, or branch to a new file if you have edits to make in the meantime.

Once the user picks a direction, default to keeping both files. The discarded file may still be useful as a reference for what didn't work. Only merge into one or delete the rejected version when the user explicitly says to.

**Failure mode this prevents:** overwriting the original forces the user to reconstruct it from chat history or git to compare against the new version — the exact "scroll back and forth" cost the main rule is meant to remove. Comparison is the whole point of asking for an alternative. Preserving both versions is what makes the comparison possible.

## Skill-prescribed output formats do not exempt content from this rule

A skill's prescribed output format — JSON findings, a structured report, anything multi-section — is a contract for *shape*, not for *placement*. The file-it threshold above still applies. Default to filing: write a markdown narrative to a file with the prescribed-format payload inside (a fenced block, or appended at the end), and post the usual pointer in chat.

## Don't put decision-critical detail only in an AskUserQuestion preview — previews clip at a height you can't see

When passing `preview` content on an AskUserQuestion option, never rely on the preview to carry information the user needs in order to choose. The picker renders previews in a pane sized to the user's terminal — a height you can't observe — and clips overflow to a "N lines hidden" marker with no scroll. On a short terminal even a two-or-three-line preview can collapse to a single visible line, so no preview length reliably fits.

**Why:** the available height of the preview pane can't be detected, so there's no judging what length will fit — even a two-or-three-line preview can collapse to a single visible line. The user can enlarge the pane, but that's not something to count on or measure.

**How to apply:** treat previews as an optional visual aid whose absence would not block the decision — a mockup or snippet the user compares *if* it renders. Keep everything load-bearing (what each option means, tradeoffs, the recommendation) in the chat message accompanying the question, where nothing is clipped. When in doubt, skip the preview and rely on labels + descriptions + prose framing in chat.

## Don't point at tool output as a shared visible surface

When claiming there's a finding to see — "the standout is X", "as the table above shows", "the output confirms" — reproduce the load-bearing part *in the chat message itself*. Do not reference "the table above" / "the output above" pointing at a Bash result or other tool output. Tool outputs are not a reliable shared surface: depending on the user's interface they may be collapsed, scrolled off, or not rendered as the model imagined (a sorted plaintext dump is not a "table" the user sees). So "see above" points at something the user may not have in front of them.

**Why:** this has recurred — the user flags "another time you said there's something to see and I don't see it." The model treats its own tool output as if it were part of the conversation the user reads, but the user reads the *messages*. A claimed-visible finding whose data lives only in a tool result is, to the user, an assertion with no visible support.

**How to apply:** when a tool call produces data a decision rides on, restate the load-bearing part in the message — a short markdown table, the ranked list, the specific numbers — even if it duplicates the tool output. The tool output is scratch. The message is the artifact. Sibling of the AskUserQuestion-preview lesson above (decision-critical detail must live where the user reliably sees it, not in a clipped preview) and of the long-output rule at the top of this file (which governs *where* long content goes — file vs. inline; this governs *not* offloading a visible claim onto ephemeral tool output at all).

## Failure mode this prevents

Long structured replies posted inline force the user to scroll back and forth in the terminal to re-read or compare sections, when opening the same content in their editor would be both easier and more durable. Files survive the conversation. Inline content has to be quoted, screenshotted, or re-prompted to re-visit. The default tilts toward "inline" because it's the cheaper local action for the model. This rule corrects the tilt.
