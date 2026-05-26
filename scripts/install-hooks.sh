#!/usr/bin/env bash
# install-hooks.sh — wire repo-tracked hooks into this clone's .git/hooks/.
#
# Run once after cloning (or whenever a new hook is added). Idempotent — safe
# to re-run. Symlinks each hook in scripts/hooks/ into .git/hooks/ so updates
# to the repo automatically apply.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_SRC="$SCRIPT_DIR/hooks"
HOOKS_DST="$(git -C "$REPO_DIR" rev-parse --git-path hooks)"

mkdir -p "$HOOKS_DST"

shopt -s nullglob
installed=0
for src in "$HOOKS_SRC"/*; do
  hook_name="$(basename "$src")"
  dst="$HOOKS_DST/$hook_name"

  chmod +x "$src"

  if [[ -L "$dst" ]] || [[ -e "$dst" ]]; then
    rm "$dst"
  fi
  ln -s "$src" "$dst"
  echo "Installed: $hook_name -> $src"
  installed=$((installed + 1))
done

if [[ $installed -eq 0 ]]; then
  echo "No hooks found in $HOOKS_SRC"
  exit 0
fi

echo ""
echo "Done. $installed hook(s) active for this clone."
