# Diagnosis

## Diagnose before retrying

When a command fails **or gives unexpected output**, diagnose why before trying again. Retrying the same command (or minor variants) without understanding is a loop, not debugging. This applies equally to unexpected output — if a command succeeds but the output isn't what was expected, reason about why rather than issuing variations hoping for different results.

Specific case: `fatal: bad revision '<file>'` in git means git is interpreting a path as a tree-ish. Fix: use `--` to separate revisions from paths (`git diff HEAD -- <file>`).

Specific case: when RTK's diff output doesn't show a change that's known to exist, RTK filtered it (e.g., a single-line change inside a long string). Do not retry diff variants — switch to `git diff --cached` to check the index, or read the file directly. Retrying `git diff` with different flags will not produce different output through the same filter.

## Don't route around the user's configuration

Reaching for `/bin/ls`, `/usr/bin/grep`, or similar absolute paths to sidestep aliases or shell configuration is a smell. The user's shell setup is intentional; bypassing it produces output that doesn't reflect their environment, may evade allowlists (since the allowlist matches the literal command string), and signals that something else is off. If a command isn't behaving as expected, diagnose why — don't route around the user's configuration.
