# Feedback

Overflow for rules and feedback that don't fit an existing rule file. Periodically review this file — if an entry has grown into a pattern or belongs with a coherent topic, extract it into an appropriate rule file rather than leaving it here indefinitely.

## Diagnose before retrying

When a command fails, read the error message and reason about it before trying again. Retrying the same command (or minor variants) without understanding the failure is a loop, not debugging.

Specific case: `fatal: bad revision '<file>'` in git means git is interpreting a path as a tree-ish. Fix: use `--` to separate revisions from paths (`git diff HEAD -- <file>`).

## Scope searches to the known location

When searching for a file or pattern, start from the most specific known directory — not a broad ancestor. Searching from a parent directory is slower, noisier, and risks touching unintended paths. If the search fails, widen incrementally.

Also: when the target path is a symlink, `find` may not follow it without a trailing slash. Use `find /path/to/symlink/ ...` (with trailing slash) to ensure the symlink is resolved.
