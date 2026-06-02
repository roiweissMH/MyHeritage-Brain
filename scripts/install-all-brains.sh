#!/usr/bin/env bash
# install-all-brains.sh — install every brain in the catalog you have access to.
#
# Usage:
#   ./scripts/install-all-brains.sh
#
# Behavior:
#   - For each brain in brains.txt, checks GitHub access via `gh repo view`.
#   - If you have access, runs install-brain.sh for that brain.
#   - If you don't, prints a one-line "no access — ping <owner>" and moves on.
#   - At the end, prints a summary of how many installed vs skipped.
#
# Requires git + the `gh` CLI authenticated. Without gh, the script can't
# pre-check access; it will instead let git clone fail with a clear message
# for each brain you can't reach.

set -uo pipefail   # no -e — one brain failing must not abort the whole batch

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CATALOG="$REPO_DIR/brains.txt"

if [[ ! -f "$CATALOG" ]]; then
  echo "✗ Catalog not found at $CATALOG" >&2
  exit 1
fi

GH_OK=1
command -v gh >/dev/null 2>&1 || GH_OK=0

installed=0
skipped_no_access=0
skipped_install_failed=0

while IFS='|' read -r name skill repo owner description; do
  [[ "$name" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${name// }" ]] && continue

  echo ""
  echo "==> $name ($skill — $repo)"

  if [[ $GH_OK -eq 1 ]] && ! gh repo view "$repo" >/dev/null 2>&1; then
    echo "    ✗ No access. Ping $owner to be added as a GitHub collaborator. Skipping."
    skipped_no_access=$((skipped_no_access + 1))
    continue
  fi

  if "$SCRIPT_DIR/install-brain.sh" "$name"; then
    installed=$((installed + 1))
  else
    echo "    ✗ install-brain.sh failed for '$name'. Continuing with next brain."
    skipped_install_failed=$((skipped_install_failed + 1))
  fi
done < "$CATALOG"

echo ""
echo "─────────────────────────────────────────────"
echo "Done."
echo "  Installed:               $installed"
echo "  Skipped (no access):     $skipped_no_access"
echo "  Skipped (install error): $skipped_install_failed"
echo ""
echo "Restart Claude Code to pick up the newly-installed skills."
