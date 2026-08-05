#!/usr/bin/env bash
# Report the always-loaded rule set's size, so growth is visible before it
# needs a trimming pass. Reports only — never fails, never edits.
#
# Bytes are a proxy. The authoritative number is the memory-files figure from
# /context in a fresh session, which no script can reach; ADR 0007 measured
# with that. Track the delta here, confirm with /context around a pass.
#
# A file is always-loaded when it is a rules/*.md that settings.json's
# claudeMdExcludes does not match and that carries no `paths:` frontmatter.
# See rules/rule-maintenance.md "How rules load".
#
# Only jq is used beyond bash builtins and coreutils — no bc, no bash-4
# features, so /bin/bash 3.2 runs this too.

set -u

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)" || exit 0

BASELINE=scripts/rules-floor.baseline

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not on PATH — cannot read claudeMdExcludes from settings.json." >&2
  exit 0
fi

# Paths here are repo-relative, so a leading `**/` has to collapse to a `*`
# that can match empty — keeping the slash would demand a parent directory
# `rules/README.md` doesn't have. Remaining `**` become `*`, which already
# crosses `/` in bash's [[ == ]] matching.
excludes=$(jq -r '.claudeMdExcludes[]? | gsub("\\*\\*/"; "*") | gsub("\\*\\*"; "*")' settings.json)

is_excluded() {
  local path=$1 pattern
  while IFS= read -r pattern; do
    [ -n "$pattern" ] || continue
    # shellcheck disable=SC2053  # pattern is a glob on purpose
    [[ $path == $pattern ]] && return 0
  done <<<"$excludes"
  return 1
}

# Sets the globals `rows` (size<TAB>path, descending) and `total`.
collect() {
  local dir=$1 file size
  rows=""
  total=0
  for file in "$dir"/*.md; do
    [ -e "$file" ] || continue
    is_excluded "$file" && continue
    head -n 10 "$file" | grep -q '^paths:' && continue
    size=$(wc -c <"$file" | tr -d ' ')
    rows="$rows$size	$file
"
    total=$((total + size))
  done
  rows=$(printf '%s' "$rows" | sort -rn)
}

report() {
  local label=$1 dir=$2 size path
  collect "$dir"
  [ "$total" -gt 0 ] || return 0
  printf '\n%s — %s bytes\n' "$label" "$total"
  while IFS="	" read -r size path; do
    [ -n "$path" ] || continue
    printf '  %7s  %3d%%  %s\n' "$size" "$((100 * size / total))" "$path"
  done <<<"$rows"
}

report "Always-loaded (this repo)" rules
owned=$total
report "Always-loaded (private companion, tracked elsewhere)" rules/private

if [ "${1:-}" = "--record" ]; then
  printf 'total=%s\nrecorded=%s\n' "$owned" "$(date +%F)" >"$BASELINE"
  printf '\nBaseline recorded: %s bytes on %s\n' "$owned" "$(date +%F)"
  exit 0
fi

if [ -f "$BASELINE" ]; then
  # shellcheck disable=SC1090
  . "$BASELINE"
  delta=$((owned - total))
  printf '\nBaseline %s bytes (%s) — now %s, delta %+d (%+d%%)\n' \
    "$total" "$recorded" "$owned" "$delta" "$((100 * delta / total))"
  printf 'Re-baseline after a trimming pass: scripts/rules-floor.sh --record\n'
else
  printf '\nNo baseline yet. Record one: scripts/rules-floor.sh --record\n'
fi

exit 0
