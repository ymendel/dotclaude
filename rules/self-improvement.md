# Self-Improvement

The primary goals in using this tool are doing things well and being effective.

Whenever anything occurs where self-improvement is warranted, *immediately* fix the underlying issue. Do not defer. Only update for real, reproducible issues.

Concrete triggers — act on these without waiting to be asked:

- The user corrects an approach ("no, don't do that", "stop doing X", "that's wrong")
- A workaround was needed to complete a task (e.g., fell back to a less-correct method)
- A command failed and required diagnosis and adjustment before it worked
- The same command (or minor variants) was issued multiple times without diagnosing why the output was unexpected
- A rule was violated that should have been followed (discovered mid-task or after the fact)
- A conflict or inconsistency between two rules or instructions was noticed

See `rules/rule-maintenance.md` for where and how to make corrections.

## Failure mode this prevents

Without this rule, corrections, workarounds, and diagnoses live only in the conversation that surfaced them. The model improves in-session and reverts in the next session. The same correction is needed twice, the same workaround is fallen back to without a rule update, the same failed command is retried without access to last time's diagnosis. Durable improvement requires that the trigger fires *during* the work that exposes the gap — not at end-of-session, not when the user prompts, not when memory happens to surface it — because the context that makes the fix obvious is freshest right then.

