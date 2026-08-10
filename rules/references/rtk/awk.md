# When Not to Use awk

> Not loaded in context by default. See `rules/RTK.md` for behavioral guidance.

awk is fine for the case it was built for — a per-line or per-field transformation where the line's
*content* is wanted alongside a computed value, e.g. `awk '{ print length": "$0 }'` to see which
commit-body lines exceed a wrap width and what they say. Three cases where it is the wrong reach:

- **A dedicated tool already answers the question.** For a single number, prefer the single-purpose
  tool: `wc -L` for the longest line's length, `wc -l` for a line count, `grep -c` for a match count.
  `… | wc -L` beats `… | awk '{ if (length>m) m=length } END { print m }'` for "is anything over 72?"
  — shorter, clearer, and `wc` has no destructive form so it is safely allow-listed (`Bash(wc:*)`),
  where awk is not.
- **In-file editing.** Same rule as `sed` — use the Edit tool, never `awk -i inplace` or an
  awk-to-tempfile-and-move dance.
- **Parsing structured formats.** Use a real parser (`jq` for JSON, &c.), not awk field-splitting.
  This is the shell-pipeline echo of code-style's "parse with parser libraries, not regex" —
  column-counting breaks on quoted delimiters, escapes, and embedded newlines exactly where it
  matters.
