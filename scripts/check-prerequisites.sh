#!/usr/bin/env bash
# Verify the external prerequisites this config declares are present on PATH.
# Exits 1 when a *required* one is missing, 0 otherwise: the tier beside each
# result says how routinely that absence bites, and the exit code says whether it
# stops you. Load-bearing and optional absences are reported and do not affect the
# exit code — that cut is what keeps the middle tier meaningfully distinct from
# the top one. Does not auto-install.
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

echo "Checking declared prerequisites:"
check_group required "${REQUIRED[@]}"
check_group load-bearing "${LOAD_BEARING[@]}"
check_group optional "${OPTIONAL[@]}"

if [ "$missing_required" -ne 0 ]; then
  printf '\nA *required* prerequisite is missing, so this exits 1 — its absence is silent or\n'
  printf 'breaks a routine path. The README "## Prerequisites" section says what each one\n'
  printf 'costs.\n'
  exit 1
fi

if [ "$missing_other" -ne 0 ]; then
  printf '\nMissing prerequisites above cost friction or a degraded path, not correctness, so\n'
  printf 'they do not affect the exit code — see the README "## Prerequisites" section.\n'
fi

exit 0
