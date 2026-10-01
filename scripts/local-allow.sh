#!/usr/bin/env bash
# Review the allow entries that pile up in every project's .claude/settings.local.json, in two modes
# that make one loop: `candidates` lists what might earn a user-level grant, a human decides, user
# settings gain the entry, and `prune` then removes the local copies the promotion now covers.
#
# The decision in the middle stays a human one. An entry turning up in many projects is evidence it
# recurs, not a reason to grant it: whether a grant earns user-level reach is about what it permits
# (settings.md, "What Earns a Standing Grant"), and `python3:*` recurs as readily as `gem list *`.
# So `candidates` labels each entry narrow or broad and stops there.
#
# The coverage and broadness rules live in hooks/lib/permission-rules.jq, shared with
# hooks/broad-grant-notice.sh, so the hook and this script agree on what "broad" means.
#
# `prune --apply` rewrites gitignored files in other repos, which no git history can restore, so it
# backs up every file it changes first. Only permissions.allow is touched.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: local-allow.sh candidates
       local-allow.sh prune [--apply]

candidates  List allow entries found in at least MIN_PROJECTS projects' settings.local.json that
            user settings do not already cover, each labeled narrow or broad. Read-only.

prune       Show, per project, the entries that can go without changing behavior:
              covered  user settings already permit everything the entry does
              dead     can never fire (`git status`, shell loop fragments)
              one-off  a Bash entry naming a .claude/scratch/ path, an absolute home or temp
                       path, or a `git -C`
            Dry run unless --apply, which backs each changed file up first.

Environment:
  SEARCH_ROOT    Where to look for .claude/settings.local.json. Default: $HOME/dev
  USER_SETTINGS  The user-level settings file. Default: $HOME/.claude/settings.json
  BACKUP_DIR     Where --apply puts backups, one timestamped folder per run.
                 Default: $HOME/.claude/.local-allow-backups
  MIN_PROJECTS   Fewest projects an entry must appear in to be a candidate. Default: 2

Exit status:
  0  Report produced, or prune applied.
  2  A configured path is missing or arguments are invalid.
EOF
}

mode=""
apply=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)  usage; exit 0 ;;
    candidates) [ -z "$mode" ] || { usage >&2; exit 2; }; mode=candidates; shift ;;
    prune)      [ -z "$mode" ] || { usage >&2; exit 2; }; mode=prune; shift ;;
    --apply)    apply=true; shift ;;
    *)          echo "error: unexpected argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$mode" ]; then
  usage >&2
  exit 2
fi
if $apply && [ "$mode" != prune ]; then
  echo "error: --apply only goes with prune" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/hooks/lib"
SEARCH_ROOT="${SEARCH_ROOT:-$HOME/dev}"
USER_SETTINGS="${USER_SETTINGS:-$HOME/.claude/settings.json}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.claude/.local-allow-backups}"
MIN_PROJECTS="${MIN_PROJECTS:-2}"

for required in "$SEARCH_ROOT" "$USER_SETTINGS" "$LIB_DIR/permission-rules.jq"; do
  if [ ! -e "$required" ]; then
    echo "error: not found: $required" >&2
    exit 2
  fi
done
if ! [[ "$MIN_PROJECTS" =~ ^[1-9][0-9]*$ ]]; then
  echo "error: MIN_PROJECTS must be a positive integer, got: $MIN_PROJECTS" >&2
  exit 2
fi

USER_ALLOW=$(jq -c '.permissions.allow // []' "$USER_SETTINGS")

# Backups are excluded by folder name rather than by path. The default BACKUP_DIR is spelled through
# the ~/.claude symlink while find reports real paths, so a path comparison never matches, and the
# backups themselves hold settings.local.json files that would otherwise be counted as projects.
mapfile -t FILES < <(find "$SEARCH_ROOT" -path '*/.claude/settings.local.json' \
  -not -path '*/node_modules/*' -not -path "*/$(basename "$BACKUP_DIR")/*" | sort)

# project_of <file> — the project's path relative to SEARCH_ROOT, which is how it is reported.
project_of() {
  local relative=${1#"$SEARCH_ROOT"/}
  printf '%s' "${relative%/.claude/settings.local.json}"
}

if [ "$mode" = candidates ]; then
  # One {project, allow} object per readable file; a malformed one is reported and skipped.
  collected=$(
    for file in "${FILES[@]}"; do
      jq -c --arg project "$(project_of "$file")" \
        '{project: $project, allow: (.permissions.allow // [])}' "$file" 2>/dev/null \
        || echo "warning: skipped unreadable $file" >&2
    done
  )

  report=$(printf '%s\n' "$collected" | jq -s -r -L "$LIB_DIR" \
    --argjson user "$USER_ALLOW" --arg home "$HOME" --argjson min "$MIN_PROJECTS" '
    include "permission-rules";
    [.[] | .project as $p | .allow[] | {entry: ., project: $p}]
    | group_by(.entry)
    | map({entry: .[0].entry, projects: (map(.project) | unique)})
    | map(select((.projects | length) >= $min))
    | map(select(.entry as $e | ($e | covered($user) or dead or oneoff($home)) | not))
    | sort_by(-(.projects | length), .entry)
    | .[]
    | [(.projects | length), (if (.entry | broad) then "broad" else "narrow" end), .entry,
       (.projects | join(", "))]
    | @tsv')

  if [ -z "$report" ]; then
    printf 'No candidates: nothing uncovered appears in %s or more projects (%s files read).\n' \
      "$MIN_PROJECTS" "${#FILES[@]}"
    exit 0
  fi

  printf 'Candidates for user settings, found in %s or more of %s files:\n\n' "$MIN_PROJECTS" "${#FILES[@]}"
  while IFS=$'\t' read -r count class entry projects; do
    printf '%3s  %-6s  %s\n             %s\n' "$count" "$class" "$entry" "$projects"
  done <<<"$report"
  exit 0
fi

# --- prune ------------------------------------------------------------------------

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
total=0
changed=0
for file in "${FILES[@]}"; do
  project=$(project_of "$file")
  if ! removals=$(jq -r -L "$LIB_DIR" --argjson user "$USER_ALLOW" --arg home "$HOME" '
      include "permission-rules";
      (.permissions.allow // [])[]
      | . as $e
      | (if covered($user) then "covered" elif dead then "dead" elif oneoff($home) then "one-off" else empty end)
      | "\(.)\t\($e)"' "$file" 2>/dev/null); then
    echo "warning: skipped unreadable $file" >&2
    continue
  fi

  [ -n "$removals" ] || continue
  count=$(printf '%s\n' "$removals" | wc -l | tr -d ' ')
  total=$((total + count))
  changed=$((changed + 1))
  printf '\n== %s  (%s)\n%s\n' "$project" "$count" "$removals"

  if $apply; then
    mkdir -p "$BACKUP_DIR/$STAMP/$project/.claude"
    cp "$file" "$BACKUP_DIR/$STAMP/$project/.claude/settings.local.json"
    updated=$(jq -L "$LIB_DIR" --argjson user "$USER_ALLOW" --arg home "$HOME" '
      include "permission-rules";
      .permissions.allow |= map(select((covered($user) or dead or oneoff($home)) | not))' "$file")
    printf '%s\n' "$updated" > "$file"
  fi
done

if $apply; then
  printf '\nRemoved %s entries from %s of %s files. Backups: %s\n' "$total" "$changed" "${#FILES[@]}" "$BACKUP_DIR/$STAMP"
else
  printf '\nWould remove %s entries from %s of %s files. Dry run: pass --apply to write.\n' "$total" "$changed" "${#FILES[@]}"
fi
