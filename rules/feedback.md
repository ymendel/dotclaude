# Feedback

Overflow for rules and feedback that don't fit an existing rule file. When in doubt, capture a lesson here rather than agonizing over its permanent home or skipping it — but this file loads into context every session like any rule, so it's revisable staging, not free staging. Periodically review: if an entry has grown into a pattern or belongs with a coherent topic, extract it into an appropriate rule file. Prune what hasn't earned its place rather than letting the file accrete.

## Reproduce anchor lines byte-for-byte in an Edit

An Edit's `old_string` often extends past the text being changed to reach a unique match, pulling in
a neighboring line as an anchor. Reproduce every such anchor byte-for-byte in `new_string` —
trailing spaces, tabs-vs-spaces, and all. Prefer ending the match at a line boundary over cutting
mid-line, since a partial trailing line is where the whitespace slip happens.

Edit reports success on any exact match, so a mangled anchor never surfaces as an error, and whether
the damage shows depends entirely on the target format's tolerance. Git config trims whitespace
around `=`, so clipping the trailing space off `logg = log --graph …` left the alias working and the
edit looking clean; Makefiles, YAML, Python, and heredocs would each have broken instead.

**How to apply:** when `old_string` includes a line you aren't changing, copy it into `new_string`
rather than retyping it. After editing a whitespace-sensitive format, read back the lines adjacent to
the change, not just the changed ones.

Failure mode this prevents: an edit silently alters a line it was never meant to touch, and nothing
in the diff marks it as unintentional — or, in a tolerant format, it is never noticed and ships as an
unexplained whitespace diff in an otherwise focused commit.

## Inserting a block into markdown reparents what follows it

Markdown has no closing tags, so a heading owns everything down to the next heading of equal or
higher level. Insert an `###` after a `##` section's opening prose and every remaining paragraph in
that section becomes its content, including examples that were illustrating something else.
Inserting a paragraph does the smaller version of this: a sentence that closed the previous block
ends up closing the new one instead.

The damage occupies no diff lines. `git diff` reports only the insertion, and every reparented line
is byte-identical, so reviewing the diff — the obvious check, and the one most likely to be run —
cannot reveal it.

**How to apply:** after inserting a block, read forward from it to the next heading of the same or
higher level and ask whether that content still belongs under what it now sits beneath. When it
doesn't, placing the new block at the *end* of the section usually fixes it without rewording
anything. Sibling of the entry above: that one covers the text an Edit matches on, this one the text
after it, and in both the Edit reports success while the damage sits where nobody looked.

Failure mode this prevents: a section's worth of established guidance is silently re-scoped under a
narrow new subheading. Because nothing about that guidance changed, it survives review and reads as
deliberate to every reader afterward.

