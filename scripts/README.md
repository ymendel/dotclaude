# scripts/

Tooling for maintaining this repo's setup — keeping skills in sync with a
separate team skills repo (`compare-skills.sh`, `sync-skill.sh` — see
[ADR 0001](../docs/adr/0001-skill-maintenance-via-parallel-repos.md) for the
why), and tracking which skills and agents actually get used
(`usage-report.sh`). Also includes runtime workarounds for Claude Code
bugs (`enospc-workaround.sh`).

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

`sync-skill.sh` runs three heuristic checks before applying, and prints a
warning when any fire:

- **Outward references:** the source skill's files mention `rules/`,
  `hooks/`, or `settings.json`. Catches skills that explicitly call out
  their dependencies.
- **Inward references:** files under the source repo's `rules/`, `hooks/`,
  `agents/`, or `settings.json` mention the skill name. Catches dependencies
  that point *into* the skill from outside.
- **Missing companions:** code/script filenames (`.sh`, `.py`, etc.) named
  in the skill's markdown docs that don't exist anywhere inside the skill
  directory. Catches the "documented but not shipped" shape — e.g. setup.md
  tells the adopter to copy a script that lives elsewhere in the source
  repo and won't travel with the skill.

Each check can produce false positives (a skill that just happens to
mention "rules/" in passing; a markdown code-block example name like
`test.py`) or false negatives (an implicit dependency not named anywhere).
The warnings list likely-affected paths — none of them are copied by the
sync; bring them across by hand if the destination needs them. See
[ADR 0001](../docs/adr/0001-skill-maintenance-via-parallel-repos.md) for
the reasoning.

### Exit status

- `0` Sync (or dry-run) completed.
- `1` Destination has uncommitted changes for this skill; refused.
- `2` Invalid arguments, missing paths, or skill not found on source side.

## `usage-report.sh`

Report how much of the setup actually gets used.

```
./scripts/usage-report.sh [--no-snapshot]
```

Scans Claude Code session transcripts (`$HOME/.claude/projects`) for skill
invocations (`"skill":"<name>"`) and agent invocations
(`"subagent_type":"<name>"`), cross-references them against the `skills/` and
`agents/` inventory, and prints each item's count — with the unused ones
called out per section. Items invoked but absent from the inventory
(built-in agents, removed skills) are listed separately.

### Snapshots and the retention window

Transcripts rotate after roughly 30 days, so any single scan only sees usage
within that window — a one-off run can never show a longer trend. To work
around that, each run appends a dated snapshot (one row per skill/agent) to
`usage-data/usage-history.tsv`, accumulating history the transcripts
themselves discard. `--no-snapshot` prints the report without writing.

The history file lives under `usage-data/`, which the repo's allowlist
`.gitignore` excludes — it's local working data, not committed. The report
header states the actual window covered, so a `0` reads as "not invoked in
the window," not "never."

### Configuration

```
REPO=...           # repo root; default is the script's parent dir
PROJECTS_DIR=...   # transcripts; default $HOME/.claude/projects
HISTORY_FILE=...   # snapshot log; default $REPO/usage-data/usage-history.tsv
```

Requires bash 4+ (associative arrays, `mapfile`, namerefs).

### Exit status

- `0` Report produced.
- `2` A configured path is missing or arguments are invalid.

## `enospc-workaround.sh`

Workaround for a Claude Code preflight ENOSPC false-positive on macOS
x86_64 APFS.

Bun 1.3.14 (embedded in Claude Code ~2.1.153 through 2.1.163) has a
`statfs` alignment bug that returns `bsize=0`. Claude Code's preflight
check, which runs when a child process exits non-zero with empty stdout,
then computes `0 MB free` regardless of actual free space, kills the
process, and reports a misleading `ENOSPC` error. The trigger in practice
is any command that legitimately exits non-zero with no output — `grep`
with no match, `ls` against a missing file, &c.

The script sets an `EXIT` trap that prints a newline on any non-zero exit,
so the "empty stdout AND non-zero exit" pattern never holds. Successful
commands are unaffected.

### Usage

Source the script via `BASH_ENV` in your shell rc:

```sh
export BASH_ENV="$HOME/.claude/scripts/enospc-workaround.sh"
```

Restart Claude Code (new terminal) after adding. Remove once Claude Code
ships with Bun >= 1.3.15.

### References

- [claude-code#63877](https://github.com/anthropics/claude-code/issues/63877) — the original ENOSPC preflight bug.
- [Comment with this specific workaround](https://github.com/anthropics/claude-code/issues/63877#issuecomment-4627467164) — the Bun `bsize=0` variant on macOS x86_64 APFS.
