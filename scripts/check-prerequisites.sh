#!/usr/bin/env bash
# Verify the external prerequisites this config declares are present on PATH.
# Warns on anything missing but never fails, and does not auto-install — the
# tier beside each result says what that particular absence costs, which is the
# part a bare present/absent list left the reader to work out.
# Keep these lists and their tiers in sync with the repo README
# "## Prerequisites" ledger.

set -u

REQUIRED=(jq python3)
LOAD_BEARING=(rtk gh)
OPTIONAL=(uv trafilatura)

missing_required=0
missing_other=0

# check_group <tier> <dep>...
check_group() {
  local tier=$1
  shift
  local dep
  for dep in "$@"; do
    if command -v "$dep" >/dev/null 2>&1; then
      printf '  ok       %-14s %s\n' "$dep" "$tier"
    else
      printf '  MISSING  %-14s %s\n' "$dep" "$tier"
      if [ "$tier" = "required" ]; then
        missing_required=1
      else
        missing_other=1
      fi
    fi
  done
}

echo "Checking declared prerequisites (warns, does not fail):"
check_group required "${REQUIRED[@]}"
check_group load-bearing "${LOAD_BEARING[@]}"
check_group optional "${OPTIONAL[@]}"

if [ "$missing_required" -ne 0 ]; then
  printf '\nA missing *required* prerequisite is the one worth acting on — its absence is\n'
  printf 'silent or breaks a routine path. The README "## Prerequisites" section says what\n'
  printf 'each one costs.\n'
elif [ "$missing_other" -ne 0 ]; then
  printf '\nMissing prerequisites above cost friction or a degraded path, not correctness —\n'
  printf 'see the README "## Prerequisites" section.\n'
fi

exit 0
