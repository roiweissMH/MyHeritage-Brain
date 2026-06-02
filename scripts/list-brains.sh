#!/usr/bin/env bash
# list-brains.sh — print the catalog of known MyHeritage domain brains and
# whether you currently have access on GitHub.
#
# Usage:
#   ./scripts/list-brains.sh
#
# Output columns: NAME, SKILL, ACCESS, OWNER, DESCRIPTION.
# Requires `gh` CLI authenticated (`gh auth login`). Without gh, the script
# still prints the catalog but marks every row as "?? (gh missing)".

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CATALOG="$REPO_DIR/brains.txt"

if [[ ! -f "$CATALOG" ]]; then
  echo "✗ Catalog not found at $CATALOG" >&2
  exit 1
fi

GH_OK=1
if ! command -v gh >/dev/null 2>&1; then
  GH_OK=0
  echo "(gh CLI not installed — install with 'brew install gh && gh auth login' to enable access checks)" >&2
  echo ""
fi

printf "%-12s  %-22s  %-22s  %-18s  %s\n" "NAME" "SKILL" "ACCESS" "OWNER" "DESCRIPTION"
printf "%-12s  %-22s  %-22s  %-18s  %s\n" "------------" "----------------------" "----------------------" "------------------" "-----------"

while IFS='|' read -r name skill repo owner description; do
  # Skip comments and blank lines
  [[ "$name" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${name// }" ]] && continue

  if [[ $GH_OK -eq 0 ]]; then
    access="?? gh missing"
  elif gh repo view "$repo" >/dev/null 2>&1; then
    access="✓ have access"
  else
    access="✗ no access"
  fi

  printf "%-12s  %-22s  %-22s  %-18s  %s\n" "$name" "$skill" "$access" "$owner" "$description"
done < "$CATALOG"

echo ""
echo "To install one:           ./scripts/install-brain.sh <name>"
echo "To install all you can:   ./scripts/install-all-brains.sh"
echo "To request access:        contact the owner listed above; they'll add you on GitHub."
