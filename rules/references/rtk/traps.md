# RTK — `find` and `grep` Result Traps

> Not loaded in context by default. See `rules/RTK.md` for behavioral guidance.

Four mechanisms in `rtk find` and `rtk grep` turn a real match into a clean-looking miss. None of
them errors, so the result reads as the answer.

## `rtk find` suppresses output to save tokens

`rtk find` suppresses output the same way `rtk git diff` does — fine for navigating ("does this
directory have a README?"), wrong when an exact count or full list matters. Counting via
`rtk find ... | wc -l` returns the *filtered* count and silently underreports the real one.
When the answer feeds a quantitative check — file counts after a copy, an audit of every
match, anything where a decision rides on the total — use `rtk proxy find` instead. Failure
mode this prevents: a filtered `find | wc -l` looks authoritative and makes plausible-but-wrong
counts feel like ground truth, leading to false alarms (or worse, missed real ones) when the
delta between filtered and real is large.

## `rtk find` also respects `.gitignore`

A distinct trap from the token-suppression above. It omits gitignored paths entirely, not just
some lines of output. In a repo that is gitignored-by-default (this repo, `dotclaude`, uses an
allowlist `.gitignore` per ADR 0003 — only explicitly re-included paths are tracked), that means a
`find` for anything *not* on the allowlist (a stray PDF, a scratch note, a downloaded asset dropped
into the tree) comes back empty even though the file is sitting right there. The empty result reads
as "file absent" when the truth is "file present but gitignored." When searching for a file that may
not be tracked — and especially in an allowlist repo, where *most* files aren't — use
`rtk proxy find` (raw `find`, no gitignore filtering) or the built-in Glob tool. Failure mode this
prevents: concluding a file doesn't exist here (e.g. "it must be in the home directory") from an
`rtk find` miss, when the hook silently rewrote `find`→`rtk find` and gitignore hid the file.

## `rtk find` matches a glob *pattern*, not a directory

A third trap, upstream of both filters above. `rtk find <pattern>` globs filenames (grouped by
directory), like the built-in Glob tool. It is *not* real `find <dir>`, which lists a directory. So
`rtk find docs/adr/` treats the directory path as a pattern, matches no file *named* that, and
returns empty with exit 0 — even when the directory is full of tracked files. The hook makes it
silent: a bare `find docs/adr/`, typed for real-find's listing behavior, gets rewritten to
`rtk find docs/adr/` before anyone types `rtk`. To list a directory use `rtk ls <dir>` (or
`rtk proxy find <dir>`, or Glob `docs/adr/*`). Reserve `rtk find` for filename globs like
`rtk find '*.md'`. Failure mode this prevents: reading an empty `rtk find docs/adr/` as "the files
aren't here" and reaching for the gitignore or token-suppression explanations above, when neither
applies.

## `rtk grep` swallows some short flags

`-h` prints rtk's help instead of suppressing filenames, and exits 0 doing it. rtk's own options
shadow grep's, so `-h` (help), `-m` (max results) and `-t` (file type) never reach grep. `-l` is the
exception that makes guessing unsafe: rtk defines it too (max line length) and yet it *does* reach
grep, so which flags leak cannot be read off rtk's `--help`. Position counts as much as the flag —
only a *leading* flag hits rtk's parser, and the same flag placed after the pattern and paths passes
through and works. The exit code is what keeps this quiet, because the help path returns 0, so a
chained `rtk grep -h … && <next>` runs on as though the search succeeded. Three fixes, cheapest
first. Use the long form (`grep --no-filename`), which code-style.md wants anyway and rtk passes
through untouched. Move the short flag after the positional args. Or go around the wrapper with
`rtk proxy grep`. Verified on rtk 0.44.2 and for `grep` alone — other subcommands define their own
short flags, so assume nothing about which of theirs leak. Failure mode this prevents: reading rtk's
usage block as "I got the grep syntax wrong" and retyping variants when the flag was correct and
never arrived — or taking the exit 0 for a successful search that found nothing.
