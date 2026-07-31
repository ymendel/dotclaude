#!/usr/bin/env bash
# Report how much of this repo's setup (skills and agents) actually gets used,
# by scanning Claude Code session transcripts for invocations.
#
# Transcripts rotate, so a single scan only sees recent sessions. Counts are
# restricted to a fixed lookback (WINDOW_DAYS, default 30) so every run measures
# the same span and the label can't drift with retention quirks. Even so, a run
# made late undercounts — transcripts that rotated out before the scan are gone.
# So don't compare raw counts between two runs; watch the trend in the
# cumulative history file (usage-data/usage-history.tsv), which keeps one dated
# snapshot per run past the rotation horizon.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: usage-report.sh [options]

Scan Claude Code transcripts from the last WINDOW_DAYS and report invocation
counts for every skill (skills/<name>/) and agent (agents/<name>.md) in this
repo, highlighting the ones that went unused in that window. Appends a dated
snapshot to the history file so the trend can be tracked despite transcript
rotation — read the TSV for the trend rather than comparing raw counts between
two runs, which drift as transcripts rotate.

Options:
  --no-snapshot   Print the report but do not append to the history file.
  -h, --help      Show this help and exit.

Environment:
  REPO            Path to this repo's root.
                  Default: the parent of this script's directory.
  PROJECTS_DIR    Where Claude Code stores session transcripts.
                  Default: $HOME/.claude/projects
  WINDOW_DAYS     Fixed lookback in days for counting transcripts. Default: 30.
                  Keeps the window constant across runs so counts stay
                  comparable regardless of when the run happens.
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
WINDOW_DAYS="${WINDOW_DAYS:-30}"

if ! [[ "$WINDOW_DAYS" =~ ^[1-9][0-9]*$ ]]; then
  echo "error: WINDOW_DAYS must be a positive integer, got: $WINDOW_DAYS" >&2
  exit 2
fi

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

# --- Window (fixed lookback) -----------------------------------------------
# Count only transcripts modified within the last WINDOW_DAYS, so every run
# measures the same span. This fixes a bug in an earlier version: it counted
# every surviving transcript and labelled the span by min/max file date, so a
# run made after some transcripts had rotated out could show a *longer* labelled
# window with *fewer* counts than a prior run. A fixed lookback can't recover
# rotated data, but it keeps the window — and the label — constant across runs.
now_ts="$(date '+%s')"
cutoff_ts=$(( now_ts - WINDOW_DAYS * 86400 ))
total_files=$(find "$PROJECTS_DIR" -name '*.jsonl' | wc -l | tr -d ' ')
mapfile -t window_files < <(
  find "$PROJECTS_DIR" -name '*.jsonl' -print0 \
    | xargs -0 stat -f '%m %N' 2>/dev/null \
    | awk -v cutoff="$cutoff_ts" '$1 >= cutoff { sub(/^[0-9]+ /, ""); print }'
)
n_files="${#window_files[@]}"
window_start="$(date -r "$cutoff_ts" '+%Y-%m-%d' 2>/dev/null || true)"
window_end="$(date '+%Y-%m-%d')"

# --- Inventory -------------------------------------------------------------
mapfile -t skills < <(find "$SKILLS_DIR" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort)
mapfile -t agents < <(find "$AGENTS_DIR" -maxdepth 1 -mindepth 1 -name '*.md' ! -name 'README.md' -exec basename {} .md \; | sort)

# --- Gather invocation counts from in-window transcripts -------------------
# Skills appear as "skill":"<name>"; agents as "subagent_type":"<name>".
declare -A skill_counts agent_counts
if [[ "$n_files" -gt 0 ]]; then
  while read -r cnt name; do
    [[ -n "${name:-}" ]] && skill_counts["$name"]=$cnt
  done < <(printf '%s\0' "${window_files[@]}" \
             | xargs -0 grep -ohI '"skill":"[a-z0-9_-]\+"' 2>/dev/null \
             | sed 's/.*"skill":"//; s/"$//' | sort | uniq -c)
  while read -r cnt name; do
    [[ -n "${name:-}" ]] && agent_counts["$name"]=$cnt
  done < <(printf '%s\0' "${window_files[@]}" \
             | xargs -0 grep -ohI '"subagent_type":"[a-z0-9_-]\+"' 2>/dev/null \
             | sed 's/.*"subagent_type":"//; s/"$//' | sort | uniq -c)
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
echo "Transcripts in window: ${n_files} (of ${total_files} present) in ${PROJECTS_DIR}"
echo "Window: last ${WINDOW_DAYS}d (${window_start} → ${window_end})."
echo "${DIM}Retention-limited — a run made late undercounts as transcripts rotate out. Track the trend in the history TSV; don't compare raw counts across runs.${RESET}"
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
