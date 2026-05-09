# Feedback

Overflow for rules and feedback that don't fit an existing rule file. Periodically review this file — if an entry has grown into a pattern or belongs with a coherent topic, extract it into an appropriate rule file rather than leaving it here indefinitely.

## Diagnose before retrying

When a command fails **or gives unexpected output**, diagnose why before trying again. Retrying the same command (or minor variants) without understanding is a loop, not debugging. This applies equally to unexpected output — if a command succeeds but the output isn't what was expected, reason about why rather than issuing variations hoping for different results.

Specific case: `fatal: bad revision '<file>'` in git means git is interpreting a path as a tree-ish. Fix: use `--` to separate revisions from paths (`git diff HEAD -- <file>`).

Specific case: when RTK's diff output doesn't show a change that's known to exist, RTK filtered it (e.g., a single-line change inside a long string). Do not retry diff variants — switch to `git diff --cached` to check the index, or read the file directly. Retrying `git diff` with different flags will not produce different output through the same filter.

## Scope searches to the known location

When searching for a file or pattern, start from the most specific known directory — not a broad ancestor. Searching from a parent directory is slower, noisier, and risks touching unintended paths. If the search fails, widen incrementally.

When the exact path is known, use Read directly — do not use Glob. Globbing an already-known path adds noise and signals uncertainty that isn't there.

Also: when the target path is a symlink, `find` may not follow it without a trailing slash. Use `find /path/to/symlink/ ...` (with trailing slash) to ensure the symlink is resolved.

## Never search locally for external library documentation

When a question is about an external gem, package, or tool (e.g., solid_queue, Rails, a npm package), fetch its documentation directly — do not spawn a search agent or search the local filesystem. External library docs live online, not in the project directory or the user's home directory.

Never search under any home directory path for documentation or library information. Those directories contain personal files, not library docs.

**WebFetch vs curl**: WebFetch processes content through a small model and returns a summary — it cannot return verbatim content. Use WebFetch when you need to understand or extract information from a page. Use `rtk proxy curl -s <url>` when you need the raw content unchanged (e.g., a spec file, a config template, any file where exact text matters). If RTK filters the curl output, `rtk proxy curl` bypasses all filters.

## yUML style preference

Default to the `napkin` style for yUML diagrams unless context calls for something else (e.g., a formal presentation might warrant `clean` or `blueprint`).

## Stay within review scope

When reviewing or auditing, stay within the requested scope — do not propose or make code changes unless asked. A review request is a read-only task unless the user explicitly says to fix what's found.

