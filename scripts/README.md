# scripts/

Tooling for maintaining skills across this personal repo and a separate team
skills repo. See [ADR 0001](../docs/adr/0001-skill-maintenance-via-parallel-repos.md)
for the why.

## `compare-skills.sh`

Report drift between the two repos.

For each skill present in both, prints whether the contents differ and which
side has the more recent commit (so you can decide which direction to
propagate). For skills present on only one side, lists them at the bottom so
you can decide whether to share or pull.

Comparison respects each side's `.gitignore` by enumerating files via
`git ls-files`, so build artifacts (`__pycache__/`, `*.pyc`, etc.) and other
local-only files don't surface as drift.

### Usage

```
./scripts/compare-skills.sh [-v] [skill-name ...]
```

Pass skill names to compare only those; with no arguments, scans every skill
present on both sides. `-v` prints unified diffs for files that differ.

Exit status: `0` if all compared skills are identical, `1` if at least one
differs, `2` for invalid arguments or missing paths.

### Configuration

Defaults assume the team checkout lives at `$HOME/dev/team-skills/`. Override
via environment variables:

```
MINE=$HOME/dev/projects/mine/dotclaude/skills    # default
THEIRS=$HOME/path/to/team-skills/skills          # override as needed
```

Both repos must be working git checkouts — commit-date arrows and gitignore
filtering both rely on `git` running inside each tree.
