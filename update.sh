#!/usr/bin/env bash
# update.sh — pull the latest /New-Brain from origin and reinstall the skill.
#
# Run this whenever you want to upgrade your local /New-Brain to the latest
# version on GitHub. Idempotent — safe to re-run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

old_version="(unknown)"
[[ -f VERSION ]] && old_version="$(tr -d '[:space:]' < VERSION)"

echo "→ Pulling latest from origin..."
git pull --rebase --autostash

echo "→ Reinstalling /New-Brain skill..."
./install.sh

echo "→ Propagating engine to installed brain skills..."
./scripts/propagate.sh || echo "  (propagate reported issues — see above; /New-Brain itself is up to date)"

new_version="(unknown)"
[[ -f VERSION ]] && new_version="$(tr -d '[:space:]' < VERSION)"

echo ""
if [[ "$old_version" == "$new_version" ]]; then
  echo "✓ Already on $new_version — no changes pulled."
else
  echo "✓ Updated: $old_version → $new_version"
fi

if [[ -f CHANGELOG.md ]]; then
  echo ""
  echo "Recent changes:"
  # Print the changelog from the marker forward, capped at ~20 lines so we
  # don't dump the whole history into the user's terminal.
  awk '/<!-- release.sh inserts new entries below this line -->/{flag=1; next} flag' CHANGELOG.md \
    | sed '/^$/N;/^\n$/D' \
    | head -20
fi

echo ""
echo "Restart Claude Code if you want it to pick up SKILL.md changes."
