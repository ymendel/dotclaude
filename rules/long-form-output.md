# Long-Form Output

When a turn's output is long enough that the user would have to scroll back and forth in the conversation to re-read or compare sections, write it to a file and post a short pointer in the chat instead of dumping it inline.

## What counts as long enough

- **Anything the user is likely to want to respond to point-by-point.** This is the primary case — putting it in a file makes redlining possible. Inline content has to be quoted back to be addressed, which costs the user a step every time.
- Multi-section structured documents — plans, design docs, audits, code review findings, post-implementation reports.
- Output worth sharing or coming back to over multiple turns.

## What does not need a file

- Short answers, even when they include a small code block.
- Tool-call updates and status sentences.
- A single explanation paragraph, a short list, or a brief decision summary.

## How to apply

- Pick a sensible path inside the project (`docs/`, alongside related artifacts, `.claude/handoffs/` for handoffs, `.claude/reviews/` for code reviews). Don't create a new top-level directory.
- Write the file, then post a short pointer in the chat: filename, one to three sentences of framing, and the specific things to look at. The pointer goes in the chat; the content goes in the file.
- If the output is genuinely throwaway / one-shot and unlikely to be re-read, ask before creating the file rather than defaulting to one.

## Alternatives and rewrites go to a new file

When the user has an existing filed draft and asks to see an alternative version, a rewrite, or a different angle — "show me a version that's more in my voice", "what would this look like if we cut X", "give me a tighter version" — write the new version to a new file with a short suffix that signals what it is (`-voice`, `-tight`, `-v2`, &c.), not over the existing one. Surface both paths in the pointer so the user can compare.

The same applies to incremental drafts the user is *still reading*: if they say "I'm reading this now", don't overwrite while they're reading. Wait for feedback, or branch to a new file if you have edits to make in the meantime.

Once the user picks a direction, default to keeping both files. The discarded file may still be useful as a reference for what didn't work. Only merge into one or delete the rejected version when the user explicitly says to.

**Failure mode this prevents:** overwriting the original forces the user to reconstruct it from chat history or git to compare against the new version — the exact "scroll back and forth" cost the main rule is meant to remove. Comparison is the whole point of asking for an alternative; preserving both versions is what makes the comparison possible.

## Skill-prescribed output formats do not exempt content from this rule

A skill's prescribed output format — JSON findings, a structured report, anything multi-section — is a contract for *shape*, not for *placement*. The file-it threshold above still applies. Default to filing: write a markdown narrative to a file with the prescribed-format payload inside (a fenced block, or appended at the end), and post the usual pointer in chat.

## Failure mode this prevents

Long structured replies posted inline force the user to scroll back and forth in the terminal to re-read or compare sections, when opening the same content in their editor would be both easier and more durable. Files survive the conversation; inline content has to be quoted, screenshotted, or re-prompted to re-visit. The default tilts toward "inline" because it's the cheaper local action for the model; this rule corrects the tilt.
