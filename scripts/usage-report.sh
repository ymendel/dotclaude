#!/usr/bin/env bash
# Report how much of this repo's setup (skills and agents) actually gets used,
# by scanning Claude Code session transcripts for invocations.
#
# Transcripts rotate (~30 days of retention), so a single scan can only ever
# show usage within that window. To watch the trend over a longer horizon, each
# run appends a dated snapshot to a cumulative history file — the transcripts
# themselves can't preserve history past the rotation window, but the snapshot
# log can.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: usage-report.sh [options]

Scan Claude Code transcripts and report invocation counts for every skill
(skills/<name>/) and agent (agents/<name>.md) in this repo, highlighting the
ones that went unused in the available window. Appends a dated snapshot to the
history file so usage can be tracked over time despite transcript rotation.

Options:
  --no-snapshot   Print the report but do not append to the history file.
  -h, --help      Show this help and exit.

Environment:
  REPO            Path to this repo's root.
                  Default: the parent of this script's directory.
  PROJECTS_DIR    Where Claude Code stores session transcripts.
                  Default: $HOME/.claude/projects
  HISTORY_FILE    Cumulative snapshot log (TSV).
                  Default: $REPO/usage-data/usage-history.tsv

Exit status:
  0  Report produced.
  2  A configured path is missing or arguments are invalid.

Examples:
  usage-report.sh
  usage-report.sh --no-snapshot
EOF
}

snapshot=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)     usage; exit 0 ;;
    --no-snapshot) snapshot=0; shift ;;
    --)            shift; break ;;
    -*)            echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)             echo "error: unexpected argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${REPO:-$(dirname "$SCRIPT_DIR")}"
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/.claude/projects}"
HISTORY_FILE="${HISTORY_FILE:-$REPO/usage-data/usage-history.tsv}"

SKILLS_DIR="$REPO/skills"
AGENTS_DIR="$REPO/agents"

for d in "$SKILLS_DIR" "$AGENTS_DIR"; do
  if [[ ! -d "$d" ]]; then
    echo "error: not found: $d" >&2
    exit 2
  fi
done
if [[ ! -d "$PROJECTS_DIR" ]]; then
  echo "error: transcripts dir not found: $PROJECTS_DIR" >&2
  exit 2
fi

# Colors (skip if not a tty)
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; GREEN=$'\033[32m'
  YELLOW=$'\033[33m'; RESET=$'\033[0m'
else
  BOLD=""; DIM=""; GREEN=""; YELLOW=""; RESET=""
fi

# Portable mtime (BSD stat first, then GNU).
file_mtime() { stat -f '%m' "$1" 2>/dev/null || stat -c '%Y' "$1" 2>/dev/null; }

# --- Gather invocation counts from transcripts -----------------------------
# Skills appear as "skill":"<name>"; agents as "subagent_type":"<name>".
declare -A skill_counts agent_counts
while read -r cnt name; do
  [[ -n "${name:-}" ]] && skill_counts["$name"]=$cnt
done < <(grep -rohI '"skill":"[a-z0-9_-]\+"' "$PROJECTS_DIR" 2>/dev/null \
           | sed 's/.*"skill":"//; s/"$//' | sort | uniq -c)
while read -r cnt name; do
  [[ -n "${name:-}" ]] && agent_counts["$name"]=$cnt
done < <(grep -rohI '"subagent_type":"[a-z0-9_-]\+"' "$PROJECTS_DIR" 2>/dev/null \
           | sed 's/.*"subagent_type":"//; s/"$//' | sort | uniq -c)

# --- Inventory -------------------------------------------------------------
mapfile -t skills < <(find "$SKILLS_DIR" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort)
mapfile -t agents < <(find "$AGENTS_DIR" -maxdepth 1 -mindepth 1 -name '*.md' ! -name 'README.md' -exec basename {} .md \; | sort)

# --- Window ----------------------------------------------------------------
n_files=$(find "$PROJECTS_DIR" -name '*.jsonl' | wc -l | tr -d ' ')
oldest_ts=""; newest_ts=""
if [[ "$n_files" -gt 0 ]]; then
  read -r oldest_ts newest_ts < <(
    find "$PROJECTS_DIR" -name '*.jsonl' -print0 \
      | xargs -0 -n1 stat -f '%m' 2>/dev/null \
      | sort -n | sed -n '1p;$p' | paste -sd' ' -
  )
fi
window_start="n/a"; window_end="n/a"; window_days="?"
if [[ -n "$oldest_ts" && -n "$newest_ts" ]]; then
  window_start="$(date -r "$oldest_ts" '+%Y-%m-%d' 2>/dev/null || true)"
  window_end="$(date -r "$newest_ts" '+%Y-%m-%d' 2>/dev/null || true)"
  window_days=$(( (newest_ts - oldest_ts) / 86400 ))
fi

# --- Report a section ------------------------------------------------------
# $1 = label, $2 = name of the counts assoc array, rest = inventory names
report_section() {
  local label="$1" arrname="$2"; shift 2
  local -n counts="$arrname"
  local items=("$@")
  local used=0 unused=0 unused_names=()

  echo "${BOLD}${label} (${#items[@]})${RESET}"
  # Sort inventory by count desc, then name.
  local line
  while IFS=$'\t' read -r cnt name; do
    if [[ "$cnt" -eq 0 ]]; then
      printf '  %-32s %s%4d%s\n' "$name" "$DIM" "$cnt" "$RESET"
      unused=$((unused + 1)); unused_names+=("$name")
    else
      printf '  %-32s %s%4d%s\n' "$name" "$GREEN" "$cnt" "$RESET"
      used=$((used + 1))
    fi
  done < <(
    for name in "${items[@]}"; do
      printf '%d\t%s\n' "${counts[$name]:-0}" "$name"
    done | sort -t$'\t' -k1,1nr -k2,2
  )
  echo "  ${DIM}── ${used} used, ${unused} unused in window${RESET}"
  if [[ "$unused" -gt 0 ]]; then
    echo "  ${YELLOW}unused:${RESET} ${unused_names[*]}"
  fi
  echo
}

# --- Inventory invoked-but-absent (built-ins / removed) --------------------
report_external() {
  local label="$1" arrname="$2"; shift 2
  local -n counts="$arrname"
  local inv=("$@")
  declare -A in_inventory=()
  local name
  for name in "${inv[@]}"; do in_inventory["$name"]=1; done
  local ext=()
  for name in "${!counts[@]}"; do
    [[ -z "${in_inventory[$name]:-}" ]] && ext+=("$name (${counts[$name]})")
  done
  if [[ "${#ext[@]}" -gt 0 ]]; then
    printf '%s\n' "${DIM}${label} invoked but not in inventory (built-ins / external):${RESET}"
    printf '  %s\n\n' "$(printf '%s, ' "${ext[@]}" | sed 's/, $//')"
  fi
}

# --- Output ----------------------------------------------------------------
echo "${BOLD}Usage report — dotclaude skills & agents${RESET}"
echo "Transcripts: ${n_files} files in ${PROJECTS_DIR}"
echo "Window: ${window_start} → ${window_end} (~${window_days}d) — counts below cover this window only."
echo

report_section "SKILLS" skill_counts "${skills[@]}"
report_section "AGENTS" agent_counts "${agents[@]}"
report_external "Skills" skill_counts "${skills[@]}"
report_external "Agents" agent_counts "${agents[@]}"

# --- Snapshot --------------------------------------------------------------
# TODO: revisit TSV → CSV once https://github.com/zed-industries/zed/pull/48207
# is accessible directly. TSV is fine for now.
if [[ "$snapshot" -eq 1 ]]; then
  mkdir -p "$(dirname "$HISTORY_FILE")"
  if [[ ! -f "$HISTORY_FILE" ]]; then
    printf 'date\tkind\tname\tinvocations\twindow_start\twindow_end\n' > "$HISTORY_FILE"
  fi
  today="$(date '+%Y-%m-%d')"
  {
    for name in "${skills[@]}"; do
      printf '%s\tskill\t%s\t%d\t%s\t%s\n' "$today" "$name" "${skill_counts[$name]:-0}" "$window_start" "$window_end"
    done
    for name in "${agents[@]}"; do
      printf '%s\tagent\t%s\t%d\t%s\t%s\n' "$today" "$name" "${agent_counts[$name]:-0}" "$window_start" "$window_end"
    done
  } >> "$HISTORY_FILE"
  echo "${DIM}Snapshot appended to ${HISTORY_FILE} (${today}).${RESET}"
fi
