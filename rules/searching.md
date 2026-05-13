# Searching and Fetching

How to pick the right tool and scope when looking something up.

## Scope searches to the known location

When searching for a file or pattern, start from the most specific known directory — not a broad ancestor. Searching from a parent directory is slower, noisier, and risks touching unintended paths. If the search fails, widen incrementally.

When the exact path is known, use Read directly — do not use Glob. Globbing an already-known path adds noise and signals uncertainty that isn't there.

Also: when the target path is a symlink, `find` may not follow it without a trailing slash. Use `find /path/to/symlink/ ...` (with trailing slash) to ensure the symlink is resolved.

## Never search locally for external library documentation

When a question is about an external gem, package, or tool (e.g., solid_queue, Rails, an npm package), fetch its documentation directly — do not spawn a search agent or search the local filesystem. External library docs live online, not in the project directory or the user's home directory.

Never search under any home directory path for documentation or library information. Those directories contain personal files, not library docs.

## WebFetch vs curl

WebFetch processes content through a small model and returns a summary — it cannot return verbatim content. Use WebFetch when you need to understand or extract information from a page. Use `rtk proxy curl -s <url>` when you need the raw content unchanged (e.g., a spec file, a config template, any file where exact text matters). If RTK filters the curl output, `rtk proxy curl` bypasses all filters.
