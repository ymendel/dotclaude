# Searching and Fetching

How to pick the right tool and scope when looking something up.

## Scope searches to the known location

When searching for a file or pattern, start from the most specific known directory — not a broad ancestor. Searching from a parent directory is slower, noisier, and risks touching unintended paths. If the search fails, widen incrementally.

When the exact path is known, use Read directly — do not use Glob. Globbing an already-known path adds noise and signals uncertainty that isn't there.

Also: when the target path is a symlink, `find` may not follow it without a trailing slash. Use `find /path/to/symlink/ ...` (with trailing slash) to ensure the symlink is resolved.

## Do not reach into the user's home directory unprompted

Do not search, list, find, glob, or read anything under `~` / `$HOME` / `/Users/yossef/` outside the current project directory. This holds regardless of how narrow or fast the search would be, and regardless of whether the access is direct or delegated to a sub-agent. If a task plausibly needs something from there, ask — the user will say so explicitly when home-directory access is intended.

**Why:** the user's home directory contains personal files, configuration, and unrelated projects. Reaching into it without explicit permission is a violation regardless of intent. The narrower "no home-dir search for library docs" rule below is one instance of this broader prohibition.

**How to apply:** when constructing a search command, check the target path. If it starts with `~`, `$HOME`, or `/Users/yossef/` (or expands to one), stop and ask. Same for `Glob` patterns, `Read` targets, `Explore` agent prompts that mention home-dir paths, &c.

## Never search locally for external library documentation

When a question is about an external gem, package, or tool (e.g., solid_queue, Rails, an npm package), fetch its documentation directly — do not spawn a search agent or search the local filesystem. External library docs live online, not in the project directory.

## WebFetch vs curl

WebFetch processes content through a small model and returns a summary — it cannot return verbatim content. Use WebFetch when you need to understand or extract information from a page. Use `rtk proxy curl -s <url>` when you need the raw content unchanged (e.g., a spec file, a config template, any file where exact text matters). If RTK filters the curl output, `rtk proxy curl` bypasses all filters.
