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

