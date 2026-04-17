# Feedback

Overflow from feedback that doesn't fit an existing rule file.

## Diagnose before retrying

When a command fails, read the error message and reason about it before trying again. Retrying the same command (or minor variants) without understanding the failure is a loop, not debugging.

Specific case: `fatal: bad revision '<file>'` in git means git is interpreting a path as a tree-ish. Fix: use `--` to separate revisions from paths (`git diff HEAD -- <file>`).

