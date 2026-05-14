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
  2  A configured path is missing or arguments are invalid.

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
set -- "${positional[@]:-}"
# Drop the placeholder empty arg that bash produces when positional is empty.
[[ $# -eq 1 && -z "${1:-}" ]] && shift

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

# Files present in the team skills repo but not maintained on my side — ignore
# so they don't show up as drift.
DIFF_EXCLUDES=(--exclude=README.md)

compare_one() {
  local skill="$1"
  local mine_dir="$MINE/$skill"
  local theirs_dir="$THEIRS/$skill"

  local mine_rel="skills/$skill"
  local theirs_rel="skills/$skill"

  local mine_date theirs_date mine_msg theirs_msg
  mine_date=$(last_commit_iso "$(mine_root)" "$mine_rel")
  theirs_date=$(last_commit_iso "$(theirs_root)" "$theirs_rel")
  mine_msg=$(last_commit_subject "$(mine_root)" "$mine_rel")
  theirs_msg=$(last_commit_subject "$(theirs_root)" "$theirs_rel")

  # Quiet recursive diff; capture file-level differences.
  local diff_out
  diff_out=$(diff -rq "${DIFF_EXCLUDES[@]}" "$mine_dir" "$theirs_dir" 2>&1 || true)

  if [[ -z "$diff_out" ]]; then
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
  if [[ $verbose -eq 1 ]]; then
    # Unified diff already includes "Only in" lines, so don't print the -rq
    # summary above it.
    echo
    diff -ru "${DIFF_EXCLUDES[@]}" "$mine_dir" "$theirs_dir" | sed 's/^/    /'
    echo
  else
    # Indent the file-level diff list.
    printf "%s\n" "$diff_out" | sed 's/^/    /'
  fi
  return 1
}

skills_to_check=()
scan_all=0
if [[ $# -gt 0 ]]; then
  skills_to_check=("$@")
else
  scan_all=1
  # Intersection of skill directories.
  while IFS= read -r name; do
    [[ -d "$MINE/$name" ]] && skills_to_check+=("$name")
  done < <(cd "$THEIRS" && ls -1)
fi

drift=0
for skill in "${skills_to_check[@]}"; do
  if [[ ! -d "$MINE/$skill" || ! -d "$THEIRS/$skill" ]]; then
    printf "%b%-30s%b  %bnot in both%b\n" "$BOLD" "$skill" "$RESET" "$DIM" "$RESET"
    continue
  fi
  compare_one "$skill" || drift=1
done

# Skills unique to each side (only when scanning all).
if [[ $scan_all -eq 1 ]]; then
  echo
  echo "${BOLD}Only in mine:${RESET}"
  comm -23 <(cd "$MINE" && ls -1 | sort) <(cd "$THEIRS" && ls -1 | sort) \
    | sed 's/^/  /' || true
  echo "${BOLD}Only in theirs:${RESET}"
  comm -13 <(cd "$MINE" && ls -1 | sort) <(cd "$THEIRS" && ls -1 | sort) \
    | sed 's/^/  /' || true
fi

exit $drift
