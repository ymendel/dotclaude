#!/usr/bin/env bash
# Verify the external prerequisites this config declares are present on PATH.
# Warns on anything missing but never fails — each prerequisite degrades
# gracefully, so a missing one is a notice, not an error. Does not auto-install.
# Keep DEPS in sync with the repo README "## Prerequisites" ledger.

set -u

DEPS=(rtk jq gh python3 uv trafilatura)

echo "Checking declared prerequisites (warns, does not fail):"

missing=0
for dep in "${DEPS[@]}"; do
  if command -v "$dep" >/dev/null 2>&1; then
    printf '  ok       %s\n' "$dep"
  else
    printf '  MISSING  %s\n' "$dep"
    missing=1
  fi
done

if [ "$missing" -ne 0 ]; then
  printf '\nMissing prerequisites above are a warning, not an error — see the README "## Prerequisites" section.\n'
fi

exit 0
