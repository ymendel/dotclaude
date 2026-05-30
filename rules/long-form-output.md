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

- Pick a sensible path inside the project (`docs/`, alongside related artifacts, or `.claude/handoffs/` for handoffs). Don't create a new top-level directory.
- Write the file, then post a short pointer in the chat: filename, one to three sentences of framing, and the specific things to look at. The pointer goes in the chat; the content goes in the file.
- If the output is genuinely throwaway / one-shot and unlikely to be re-read, ask before creating the file rather than defaulting to one.

## Failure mode this prevents

Long structured replies posted inline force the user to scroll back and forth in the terminal to re-read or compare sections, when opening the same content in their editor would be both easier and more durable. Files survive the conversation; inline content has to be quoted, screenshotted, or re-prompted to re-visit. The default tilts toward "inline" because it's the cheaper local action for the model; this rule corrects the tilt.
