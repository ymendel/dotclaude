#!/usr/bin/env python3
"""Report per-`##`-section byte sizes for the always-loaded rule files.

Where rules-floor.sh answers "which file is carrying the weight", this answers
"which section of it" — the resolution a trimming or extraction pass needs.
Reads only rules/*.md that would load in a general session, by the same test
rules-floor.sh uses: no `paths:` frontmatter, not README.md.

    python3 scripts/rules-sections.py            # sections over 1200 bytes, all files
    python3 scripts/rules-sections.py <file.md>   # every section in one file

Reports only. Section size does not decide what to do: a big section may be all
directive (leave it), restatement (tighten it), or a lookup table (extract it),
and only reading it tells you which.
"""

import pathlib
import sys

RULES = pathlib.Path("rules")


def always_loaded(path):
    if path.name == "README.md":
        return False
    head = "".join(path.read_text().splitlines(keepends=True)[:10])
    return "\npaths:" not in "\n" + head


def sections(path):
    """Yield (heading, bytes) per `## ` section, with the preamble as '(preamble)'."""
    heading = "(preamble)"
    body = []
    for line in path.read_text().splitlines(keepends=True):
        if line.startswith("## "):
            yield heading, len("".join(body).encode())
            heading = line[3:].strip()
            body = [line]
        else:
            body.append(line)
    yield heading, len("".join(body).encode())


def main():
    if len(sys.argv) > 1:
        target = pathlib.Path(sys.argv[1])
        for heading, size in sections(target):
            print(f"{size:7d}  {heading}")
        return

    rows = []
    for path in sorted(RULES.glob("*.md")):
        if not always_loaded(path):
            continue
        for heading, size in sections(path):
            if size >= 1200:
                rows.append((size, path.name, heading))

    for size, name, heading in sorted(rows, reverse=True):
        print(f"{size:7d}  {name:32s}  {heading}")
    print(f"\n{len(rows)} sections at or over 1200 bytes, {sum(r[0] for r in rows)} bytes total")


main()
