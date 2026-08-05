#!/usr/bin/env bash
# Sync one skill between this repo (~/.claude → dotclaude) and the team skills
# repo. Overwrites the destination side with the source side's contents,
# including deletions, so the two skill directories match exactly (according
# to each side's git-tracked-or-untracked-but-not-gitignored view).
#
# See ADR 0001 (docs/adr/0001-skill-maintenance-via-parallel-repos.md) for
# the why.
#
# Requires bash 4+ (empty-array expansion under `set -u` aborts on bash 3.2,
# which is stock macOS — install a current bash via Homebrew if needed).

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: sync-skill.sh <skill-name> --to-mine | --to-theirs [--dry-run]

Copy one skill between ~/.claude (dotclaude) and the team skills repo,
overwriting the destination so its contents match the source. Files that
exist on the destination but not the source are removed.

The set of files to copy is the source side's tracked + untracked-but-not-
gitignored files (matches compare-skills.sh's notion of "the skill").
Destination-side gitignored files (build artifacts, local notes) are left
alone, and so are local uncommitted modifications: if the destination has
uncommitted changes for this skill, the sync is refused.

Arguments:
  skill-name       The skill directory under skills/ to sync.

Options:
  --to-mine        Direction: theirs → mine.
  --to-theirs      Direction: mine → theirs.
  --dry-run        Show what would change, do nothing.
  -h, --help       Show this help and exit.

Environment:
  MINE             Path to the "mine" skills directory.
                   Default: $HOME/dev/projects/mine/dotclaude/skills
  THEIRS           Path to the "theirs" skills directory.
                   Default: $HOME/dev/team-skills/skills

Exit status:
  0  Sync (or dry-run) completed successfully.
  1  Destination has uncommitted changes for this skill; refused.
  2  Invalid arguments, missing paths, or skill not found on source side.

Examples:
  sync-skill.sh adr --to-theirs
  sync-skill.sh session-handoff --to-mine --dry-run
EOF
}

skill=""
direction=""
dry_run=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)   usage; exit 0 ;;
    --to-mine)   direction="to-mine"; shift ;;
    --to-theirs) direction="to-theirs"; shift ;;
    --dry-run)   dry_run=1; shift ;;
    --)          shift; break ;;
    -*)          echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)
      if [[ -z "$skill" ]]; then
        skill="$1"; shift
      else
        echo "error: unexpected argument: $1" >&2; usage >&2; exit 2
      fi
      ;;
  esac
done

if [[ -z "$skill" ]]; then
  echo "error: skill name required" >&2
  usage >&2
  exit 2
fi
if [[ -z "$direction" ]]; then
  echo "error: one of --to-mine or --to-theirs is required" >&2
  usage >&2
  exit 2
fi

MINE="${MINE:-$HOME/dev/projects/mine/dotclaude/skills}"
THEIRS="${THEIRS:-$HOME/dev/team-skills/skills}"

if [[ ! -d "$MINE" ]]; then
  echo "error: mine not found: $MINE" >&2
  exit 2
fi
if [[ ! -d "$THEIRS" ]]; then
  echo "error: theirs not found: $THEIRS" >&2
  exit 2
fi

mine_root="$(dirname "$MINE")"
theirs_root="$(dirname "$THEIRS")"

if [[ "$direction" == "to-theirs" ]]; then
  src_label="mine"; dst_label="theirs"
  src="$MINE/$skill"; dst="$THEIRS/$skill"
  src_root="$mine_root"; dst_root="$theirs_root"
else
  src_label="theirs"; dst_label="mine"
  src="$THEIRS/$skill"; dst="$MINE/$skill"
  src_root="$theirs_root"; dst_root="$mine_root"
fi

rel="skills/$skill"

if [[ ! -d "$src" ]]; then
  echo "error: skill '$skill' not found on $src_label side: $src" >&2
  exit 2
fi

# Colors (skip if not a tty)
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GREEN=$'\033[32m'
  YELLOW=$'\033[33m'; RESET=$'\033[0m'
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; RESET=""
fi

# File names within a skill directory to ignore for sync purposes. Mirrors
# compare-skills.sh: these are typically present on one side but not
# maintained on the other (e.g. a side-specific README), so neither copying
# them nor deleting them on the destination is appropriate.
#
# Entries are matched via bash `[[ == ]]`, so glob patterns work.
EXCLUDE_NAMES=("README.md")

is_excluded() {
  local f="$1" pat
  for pat in "${EXCLUDE_NAMES[@]}"; do
    [[ "$f" == "$pat" ]] && return 0
  done
  return 1
}

# Emit each line of a multi-line string; emit nothing if empty.
emit_lines() {
  [[ -n "$1" ]] && printf '%s\n' "$1"
}

# Refuse if destination has uncommitted changes for this skill. Anything
# `git status --porcelain` would report — modifications, staged changes,
# untracked-but-not-ignored files — counts.
if [[ -d "$dst" ]]; then
  dst_dirty=$(git -C "$dst_root" status --porcelain -- "$rel" 2>/dev/null || true)
  if [[ -n "$dst_dirty" ]]; then
    echo "${RED}error:${RESET} $dst_label has uncommitted changes for $rel:" >&2
    printf '%s\n' "$dst_dirty" | sed 's/^/  /' >&2
    echo "commit, stash, or discard them before syncing." >&2
    exit 1
  fi
fi

# Enumerate non-gitignored files within the source skill, as paths relative
# to the skill directory (so they can be classified and shown without the
# `skills/<name>/` prefix).
skill_relative_files() {
  local root="$1"
  ( cd "$root" && git ls-files -co --exclude-standard -- "$rel" 2>/dev/null ) \
    | sed "s|^${rel}/||" \
    | while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        is_excluded "$f" && continue
        # ls-files can list paths whose on-disk entry is gone (rare; e.g.
        # deletions not yet staged). Filter to existing regular files.
        [[ -f "$root/$rel/$f" ]] && printf '%s\n' "$f"
      done \
    | sort
}

src_files=$(skill_relative_files "$src_root")

if [[ -z "$src_files" ]]; then
  echo "error: no files to sync under $src (empty or all excluded/gitignored)" >&2
  exit 2
fi

if [[ -d "$dst" ]]; then
  dst_files=$(skill_relative_files "$dst_root")
else
  dst_files=""
fi

# Classify each src file: add (not on dst), modify (differs), unchanged (cmp equal).
added=()
modified=()
unchanged=()
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if [[ -e "$dst/$f" ]]; then
    if cmp -s "$src/$f" "$dst/$f"; then
      unchanged+=("$f")
    else
      modified+=("$f")
    fi
  else
    added+=("$f")
  fi
done < <(emit_lines "$src_files")

# Files on the destination but not the source are deleted.
deleted=()
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if ! grep -Fxq -- "$f" <(emit_lines "$src_files"); then
    deleted+=("$f")
  fi
done < <(emit_lines "$dst_files")

change_count=$(( ${#added[@]} + ${#modified[@]} + ${#deleted[@]} ))

# Dependency warning: two heuristic checks for resources outside the skill
# directory that won't be copied by this sync. Both are best-effort; either
# can produce false positives and miss implicit dependencies. The ADR names
# this category of risk as a known limitation — these warnings just make the
# easy-to-spot cases visible at the moment of sync.
#
# 1. Outward references: source-skill files that mention `rules/`, `hooks/`,
#    or `settings.json`. Catches skills that explicitly call out their deps.
# 2. Inward references: source-repo-root locations (rules/, hooks/, agents/,
#    settings.json) that mention the skill name. Catches deps pointing into
#    the skill from outside (e.g. a top-level rule file named after the
#    skill, or a hook in settings.json that references the skill).

outward_matches=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  match=$(grep -InE '(^|[^A-Za-z0-9_-])(rules/|hooks/|settings\.json)' "$src/$f" 2>/dev/null || true)
  if [[ -n "$match" ]]; then
    while IFS= read -r line; do
      outward_matches+="  $f:$line"$'\n'
    done < <(printf '%s\n' "$match")
  fi
done < <(emit_lines "$src_files")

# Escape ERE metacharacters in the skill name so unusual names (`.`, `+`,
# `*`, etc.) are treated literally inside the `\b...\b` pattern.
skill_re=$(printf '%s' "$skill" | sed 's/[][\\.^$*+?(){}|]/\\&/g')

inward_matches=""
inward_targets=("rules" "hooks" "agents" "settings.json")
for target in "${inward_targets[@]}"; do
  path="$src_root/$target"
  [[ ! -e "$path" ]] && continue
  if [[ -d "$path" ]]; then
    hits=$(grep -rlnE "\\b${skill_re}\\b" "$path" 2>/dev/null || true)
  else
    grep -qnE "\\b${skill_re}\\b" "$path" 2>/dev/null && hits="$path" || hits=""
  fi
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    count=$(grep -cE "\\b${skill_re}\\b" "$hit" 2>/dev/null || echo 0)
    rel_hit="${hit#"$src_root/"}"
    inward_matches+="  $rel_hit ($count match$([[ $count -eq 1 ]] || echo es))"$'\n'
  done < <(emit_lines "$hits")
done

if [[ -n "$outward_matches" || -n "$inward_matches" ]]; then
  if [[ -f "$src/COMPANIONS.md" ]]; then
    # The skill ships a COMPANIONS.md — adopters have an explicit contract for
    # the manual setup, so the heuristic match is informational rather than
    # urgent. One-line note, no detail dump.
    echo "${DIM}note:${RESET} $skill has external dependencies (heuristic detected); see $skill/COMPANIONS.md for the manual setup contract." >&2
  else
    # No COMPANIONS.md — the adopter has nothing to consult, so surface the
    # full match detail at warning weight.
    echo "${YELLOW}warning:${RESET} $skill has likely external dependencies that will NOT be copied:" >&2
    if [[ -n "$outward_matches" ]]; then
      echo "  source-skill references to outside resources:" >&2
      printf '%s' "$outward_matches" | sed 's/^  /    /' >&2
    fi
    if [[ -n "$inward_matches" ]]; then
      echo "  $src_label-side files that reference this skill by name:" >&2
      printf '%s' "$inward_matches" | sed 's/^  /    /' >&2
    fi
    echo "  handle these manually if the $dst_label side needs them." >&2
  fi
  echo >&2
fi

# Completeness check: script/code filenames mentioned in skill markdown that
# don't ship inside the skill. Catches the "documented but not present" shape
# — e.g. SKILL.md or setup.md references `validate.sh` but no validate.sh exists
# anywhere in the skill directory. Distinct from the outward/inward dep check
# above: that one is about deps *outside* the skill; this one is about
# completeness *inside* it. COMPANIONS.md presence does not mute this — the
# failure mode is "the file the docs name doesn't ship," and a COMPANIONS.md
# contract describing how to install something that isn't there is exactly
# the situation this catches.
#
# Scoped to `.md` files outside `tests/` and `evals/` — that's where skill
# docs make claims about what ships. Code files (Python test helpers) and
# fixture markdown (eval scenarios narrating fake project setups) frequently
# contain filenames that aren't real references; those would noise the
# warning without adding signal.
#
# Heuristic, with the usual caveats: a generic example name (`test.py`)
# inside a markdown code block, or a tool the adopter is expected to already
# have on PATH, will also trip this. Tolerate the false positives.
mentioned_names=$(
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    [[ "$f" != *.md ]] && continue
    [[ "$f" == tests/* || "$f" == evals/* ]] && continue
    grep -hoE '\b[A-Za-z0-9_.-]+\.(sh|py|rb|js|ts|mjs|cjs|sql|rake)\b' "$src/$f" 2>/dev/null || true
  done < <(emit_lines "$src_files") | sort -u
)

missing_files=""
while IFS= read -r name; do
  [[ -z "$name" ]] && continue
  if ! find "$src" -name "$name" -print -quit 2>/dev/null | grep -q .; then
    missing_files+="  $name"$'\n'
  fi
done < <(emit_lines "$mentioned_names")

if [[ -n "$missing_files" ]]; then
  echo "${YELLOW}warning:${RESET} $skill mentions code/script files that don't ship with the skill:" >&2
  printf '%s' "$missing_files" | sed 's/^  /    /' >&2
  echo "  if these are companion files the skill needs, consider shipping them inside the skill directory." >&2
  echo >&2
fi

# Print header + change list.
if [[ $dry_run -eq 1 ]]; then
  printf "%b[dry-run]%b %s (%s → %s)\n" "$DIM" "$RESET" "$skill" "$src_label" "$dst_label"
else
  printf "%bsyncing%b %s (%s → %s)\n" "$BOLD" "$RESET" "$skill" "$src_label" "$dst_label"
fi

if [[ $change_count -eq 0 ]]; then
  echo "  (already in sync; nothing to do)"
  exit 0
fi

for f in "${added[@]}";    do printf "  %b+%b %s\n" "$GREEN"  "$RESET" "$f"; done
for f in "${modified[@]}"; do printf "  %b~%b %s\n" "$YELLOW" "$RESET" "$f"; done
for f in "${deleted[@]}";  do printf "  %b-%b %s\n" "$RED"    "$RESET" "$f"; done

if [[ $dry_run -eq 1 ]]; then
  printf "%d file%s would change\n" "$change_count" "$([[ $change_count -eq 1 ]] || echo s)"
  exit 0
fi

# Apply changes.
apply_copy() {
  local f="$1"
  local target="$dst/$f"
  mkdir -p "$(dirname "$target")"
  # -p preserves mode/timestamps so executable scripts stay executable and
  # diffs after sync reflect content only. Symlinks within a skill aren't
  # currently a thing; macOS cp without -R follows them, which would silently
  # turn a symlink into a regular file — flag the day a skill needs one.
  cp -p "$src/$f" "$target"
}

apply_delete() {
  local f="$1"
  local target="$dst/$f"
  rm -f "$target"
  # Tidy up empty parent directories under $dst (but never $dst itself, and
  # never anything above it). Stops as soon as a non-empty dir is found,
  # which also protects local-only gitignored files (`__pycache__/` etc.).
  local d
  d="$(dirname "$target")"
  while [[ "$d" == "$dst"/* ]]; do
    if [[ -d "$d" ]] && [[ -z "$(ls -A "$d" 2>/dev/null)" ]]; then
      rmdir "$d"
      d="$(dirname "$d")"
    else
      break
    fi
  done
}

# Ensure destination dir exists for first-time shares.
mkdir -p "$dst"

for f in "${added[@]}";    do apply_copy   "$f"; done
for f in "${modified[@]}"; do apply_copy   "$f"; done
for f in "${deleted[@]}";  do apply_delete "$f"; done

printf "%d file%s changed\n" "$change_count" "$([[ $change_count -eq 1 ]] || echo s)"
