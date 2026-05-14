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

## `sync-skill.sh`

Copy one skill between the two repos, in either direction.

```
./scripts/sync-skill.sh <skill-name> --to-mine | --to-theirs [--dry-run]
```

Overwrites the destination with the source's contents, including deletions,
so the two skill directories match exactly afterward. The set of files to
copy is the source side's `git ls-files -co --exclude-standard` view of the
skill (same definition `compare-skills.sh` uses). Destination-side
gitignored files (build artifacts, local notes) are left alone.

The destination's working tree must be clean for the skill: if
`git status --porcelain -- skills/<name>` is non-empty on the destination
side, the sync is refused (exit 1). Commit, stash, or discard those changes
first.

Each run prints the file-level change set (`+` added, `~` modified,
`-` removed) and a count. `--dry-run` shows the same output without applying
anything.

### Dependency warning

`sync-skill.sh` runs two heuristic checks before applying, and prints a
warning if either fires:

- **Outward references:** the source skill's files mention `rules/`,
  `hooks/`, or `settings.json`. Catches skills that explicitly call out
  their dependencies.
- **Inward references:** files under the source repo's `rules/`, `hooks/`,
  `agents/`, or `settings.json` mention the skill name. Catches dependencies
  that point *into* the skill from outside.

Either check can produce false positives (a skill that just happens to
mention "rules/" in passing) or false negatives (an implicit dependency
not named anywhere). The warning lists likely-affected paths — none of
them are copied by the sync; bring them across by hand if the destination
needs them. See [ADR 0001](../docs/adr/0001-skill-maintenance-via-parallel-repos.md)
for the reasoning.

### Exit status

- `0` Sync (or dry-run) completed.
- `1` Destination has uncommitted changes for this skill; refused.
- `2` Invalid arguments, missing paths, or skill not found on source side.
