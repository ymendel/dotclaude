# Feedback

Overflow for rules and feedback that don't fit an existing rule file. Periodically review this file — if an entry has grown into a pattern or belongs with a coherent topic, extract it into an appropriate rule file rather than leaving it here indefinitely.

## Scope searches to the known location

When searching for a file or pattern, start from the most specific known directory — not a broad ancestor. Searching from a parent directory is slower, noisier, and risks touching unintended paths. If the search fails, widen incrementally.

When the exact path is known, use Read directly — do not use Glob. Globbing an already-known path adds noise and signals uncertainty that isn't there.

Also: when the target path is a symlink, `find` may not follow it without a trailing slash. Use `find /path/to/symlink/ ...` (with trailing slash) to ensure the symlink is resolved.

## Never search locally for external library documentation

When a question is about an external gem, package, or tool (e.g., solid_queue, Rails, a npm package), fetch its documentation directly — do not spawn a search agent or search the local filesystem. External library docs live online, not in the project directory or the user's home directory.

Never search under any home directory path for documentation or library information. Those directories contain personal files, not library docs.

## WebFetch vs curl

WebFetch processes content through a small model and returns a summary — it cannot return verbatim content. Use WebFetch when you need to understand or extract information from a page. Use `rtk proxy curl -s <url>` when you need the raw content unchanged (e.g., a spec file, a config template, any file where exact text matters). If RTK filters the curl output, `rtk proxy curl` bypasses all filters.

## yUML style preference

Default to the `napkin` style for yUML diagrams unless context calls for something else (e.g., a formal presentation might warrant `clean` or `blueprint`).

## Stay within review scope

When reviewing or auditing, stay within the requested scope — do not propose or make code changes unless asked. A review request is a read-only task unless the user explicitly says to fix what's found.

## Don't bypass shell aliases with absolute paths

Reaching for `/bin/ls`, `/usr/bin/grep`, or similar absolute paths to sidestep aliases or shell configuration is a smell. The user's shell setup is intentional; bypassing it produces output that doesn't reflect their environment, may evade allowlists (since the allowlist matches the literal command string), and signals that something else is off. If a command isn't behaving as expected, diagnose why — don't route around the user's configuration.

