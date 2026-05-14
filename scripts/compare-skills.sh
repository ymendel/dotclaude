#!/usr/bin/env bash
# Compare skills between this repo (~/.claude → dotclaude) and the team skills repo.
# For each skill present in both, show whether they differ and which side has the
# newer commit, so you can decide which direction to propagate updates.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: compare-skills.sh [options] [skill-name ...]

Compare skills present in both ~/.claude (dotclaude) and the team skills repo.
For each skill, report whether the contents differ and which side has the
newer commit, so you can decide which direction to propagate updates.

Comparison respects each side's .gitignore (via `git ls-files`), so build
artifacts and other untracked-but-ignored files don't surface as drift.

Arguments:
  skill-name ...   Compare only the named skill(s). With no names, scan every
                   skill present on both sides.

Options:
  -v, --verbose    Show full unified diffs for skills that differ.
  -h, --help       Show this help and exit.

Environment:
  MINE             Path to the "mine" skills directory.
                   Default: $HOME/dev/projects/mine/dotclaude/skills
  THEIRS           Path to the "theirs" skills directory.
                   Default: $HOME/dev/team-skills/skills

Exit status:
  0  All compared skills are identical.
  1  At least one skill differs.
  2  A configured path is missing, arguments are invalid, or a named skill
     wasn't found in both repos.

Examples:
  compare-skills.sh
  compare-skills.sh adr adr-refine
  compare-skills.sh -v rails-test-discipline
EOF
}

verbose=0
positional=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)    usage; exit 0 ;;
    -v|--verbose) verbose=1; shift ;;
    --)           shift; positional+=("$@"); break ;;
    -*)           echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)            positional+=("$1"); shift ;;
  esac
done
set -- "${positional[@]+"${positional[@]}"}"

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

# Colors (skip if not a tty)
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GREEN=$'\033[32m'
  YELLOW=$'\033[33m'; BLUE=$'\033[34m'; RESET=$'\033[0m'
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi

last_commit_iso() {
  # $1 = repo root, $2 = path relative to repo root
  git -C "$1" log -1 --format='%aI' -- "$2" 2>/dev/null || true
}

last_commit_subject() {
  git -C "$1" log -1 --format='%s' -- "$2" 2>/dev/null || true
}

mine_root() { dirname "$MINE"; }
theirs_root() { dirname "$THEIRS"; }

# Emit each line of a multi-line string; emit nothing if the string is empty.
# Plain `printf '%s\n' "$var"` produces a single empty line for an empty
# string, which becomes a phantom entry in `comm` and here-string loops.
emit_lines() {
  [[ -n "$1" ]] && printf '%s\n' "$1"
}

# File names within a skill directory to ignore for comparison purposes.
# These are typically present on one side but not maintained on the other,
# so treating them as drift adds noise. Anything that should be ignored more
# broadly belongs in .gitignore on the relevant side — gitignore is respected
# automatically via `git ls-files` below.
#
# Entries are matched via bash `[[ == ]]`, so glob patterns work (e.g. "*.bak").
EXCLUDE_NAMES=("README.md")

# Enumerate non-gitignored files under $2 (a repo-relative path) within the
# repo rooted at $1. Returns one path per line, repo-relative.
non_ignored_files() {
  ( cd "$1" && git ls-files -co --exclude-standard -- "$2" 2>/dev/null )
}

# Top-level skill directory names under $1 (a skills/ directory), respecting
# the gitignore of the repo that contains it. Returns one name per line,
# sorted. Files directly under skills/ (e.g. a top-level README) are skipped;
# only entries that look like a skill subdirectory are returned.
top_level_skills() {
  local skills_dir="$1"
  local repo_root rel
  repo_root=$(dirname "$skills_dir")
  rel="skills"
  ( cd "$repo_root" && git ls-files -co --exclude-standard -- "$rel" 2>/dev/null ) \
    | sed "s|^${rel}/||" \
    | awk -F/ 'NF >= 2 {print $1}' \
    | sort -u \
    | while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        [[ -d "$skills_dir/$name" ]] && printf '%s\n' "$name"
      done
}

# Return one path per line, relative to $base (a skill directory), for files
# that exist on disk, aren't gitignored, and don't match any EXCLUDE_NAMES
# entry. Output is sorted.
skill_files() {
  local root="$1" rel="$2" base="$3"
  non_ignored_files "$root" "$rel" \
    | sed "s|^${rel}/||" \
    | while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        local skip=0
        for pat in "${EXCLUDE_NAMES[@]}"; do
          [[ "$f" == "$pat" ]] && { skip=1; break; }
        done
        [[ $skip -eq 1 ]] && continue
        [[ -f "$base/$f" ]] && printf '%s\n' "$f"
      done \
    | sort
}

compare_one() {
  local skill="$1"
  local mine_dir="$MINE/$skill"
  local theirs_dir="$THEIRS/$skill"
  local rel="skills/$skill"

  local mine_date theirs_date mine_msg theirs_msg
  mine_date=$(last_commit_iso "$(mine_root)" "$rel")
  theirs_date=$(last_commit_iso "$(theirs_root)" "$rel")
  mine_msg=$(last_commit_subject "$(mine_root)" "$rel")
  theirs_msg=$(last_commit_subject "$(theirs_root)" "$rel")

  local mine_files theirs_files
  mine_files=$(skill_files "$(mine_root)" "$rel" "$mine_dir")
  theirs_files=$(skill_files "$(theirs_root)" "$rel" "$theirs_dir")

  local only_mine only_theirs in_both
  only_mine=$(comm -23 <(emit_lines "$mine_files") <(emit_lines "$theirs_files"))
  only_theirs=$(comm -13 <(emit_lines "$mine_files") <(emit_lines "$theirs_files"))
  in_both=$(comm -12 <(emit_lines "$mine_files") <(emit_lines "$theirs_files"))

  # Of the files present on both sides, find the ones that actually differ.
  local diff_files=""
  while IFS= read -r f; do
    if ! cmp -s "$mine_dir/$f" "$theirs_dir/$f"; then
      diff_files+="$f"$'\n'
    fi
  done < <(emit_lines "$in_both")
  diff_files="${diff_files%$'\n'}"

  if [[ -z "$only_mine" && -z "$only_theirs" && -z "$diff_files" ]]; then
    printf "%b%-30s%b  %bidentical%b\n" "$BOLD" "$skill" "$RESET" "$GREEN" "$RESET"
    return 0
  fi

  # Determine "newer" by commit date (string-comparable ISO 8601).
  local newer
  if [[ -z "$mine_date" && -z "$theirs_date" ]]; then
    newer="unknown"
  elif [[ -z "$mine_date" ]]; then
    newer="theirs"
  elif [[ -z "$theirs_date" ]]; then
    newer="mine"
  elif [[ "$mine_date" > "$theirs_date" ]]; then
    newer="mine"
  elif [[ "$theirs_date" > "$mine_date" ]]; then
    newer="theirs"
  else
    newer="same-time"
  fi

  local arrow
  case "$newer" in
    mine)      arrow="${BLUE}mine →  push to theirs?${RESET}" ;;
    theirs)    arrow="${YELLOW}theirs →  pull into mine?${RESET}" ;;
    same-time) arrow="${DIM}commits at same time — inspect${RESET}" ;;
    unknown)   arrow="${DIM}no git history — inspect${RESET}" ;;
  esac

  printf "%b%-30s%b  %bdiffers%b  %s\n" "$BOLD" "$skill" "$RESET" "$RED" "$RESET" "$arrow"
  printf "  %bmine%b    %s  %s\n" "$DIM" "$RESET" "${mine_date:-—}" "${mine_msg:-—}"
  printf "  %btheirs%b  %s  %s\n" "$DIM" "$RESET" "${theirs_date:-—}" "${theirs_msg:-—}"

  while IFS= read -r f; do
    printf "    only in mine:    %s\n" "$f"
  done < <(emit_lines "$only_mine")
  while IFS= read -r f; do
    printf "    only in theirs:  %s\n" "$f"
  done < <(emit_lines "$only_theirs")
  while IFS= read -r f; do
    printf "    differs:         %s\n" "$f"
  done < <(emit_lines "$diff_files")

  if [[ $verbose -eq 1 && -n "$diff_files" ]]; then
    echo
    while IFS= read -r f; do
      echo "    --- $f ---"
      diff -u "$mine_dir/$f" "$theirs_dir/$f" | sed 's/^/    /'
    done < <(emit_lines "$diff_files")
    echo
  fi
  return 1
}

skills_to_check=()
scan_all=0
if [[ $# -gt 0 ]]; then
  skills_to_check=("$@")
else
  scan_all=1
  # Intersection of skill directories (gitignore-aware on the theirs side;
  # mine-side existence check handles the other half of the intersection).
  while IFS= read -r name; do
    [[ -d "$MINE/$name" ]] && skills_to_check+=("$name")
  done < <(top_level_skills "$THEIRS")
fi

drift=0
missing=0
for skill in "${skills_to_check[@]}"; do
  if [[ ! -d "$MINE/$skill" || ! -d "$THEIRS/$skill" ]]; then
    printf "%b%-30s%b  %bnot in both%b\n" "$BOLD" "$skill" "$RESET" "$DIM" "$RESET"
    missing=1
    continue
  fi
  compare_one "$skill" || drift=1
done

# Skills unique to each side (only when scanning all).
if [[ $scan_all -eq 1 ]]; then
  echo
  echo "${BOLD}Only in mine:${RESET}"
  comm -23 <(top_level_skills "$MINE") <(top_level_skills "$THEIRS") \
    | sed 's/^/  /' || true
  echo "${BOLD}Only in theirs:${RESET}"
  comm -13 <(top_level_skills "$MINE") <(top_level_skills "$THEIRS") \
    | sed 's/^/  /' || true
fi

if [[ $missing -eq 1 ]]; then
  exit 2
fi
exit $drift
