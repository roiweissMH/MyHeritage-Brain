#!/usr/bin/env bash
# install.sh — deploy /New-Brain's SKILL.md into Claude Code's standard skills path.
#
# Usage:
#   ./install.sh            Copy SKILL.md (default; safe — your clone can move/delete without breaking the install)
#   ./install.sh --symlink  Symlink instead of copy (changes to the deployed file propagate back to your clone)
#
# Env vars (test/override):
#   NEW_BRAIN_SKILL_DST_DIR   override destination dir (default: ~/.claude/skills/New-Brain)
#
# After running, restart Claude Code so it discovers the new skill, then run
# `/New-Brain` to verify.

set -euo pipefail

MODE="copy"
if [[ "${1:-}" == "--symlink" ]]; then
  MODE="symlink"
elif [[ -n "${1:-}" ]]; then
  echo "Unknown argument: $1" >&2
  echo "Usage: $0 [--symlink]" >&2
  exit 2
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SKILL_SRC="$REPO_DIR/SKILL.md"
SKILL_DST_DIR="${NEW_BRAIN_SKILL_DST_DIR:-$HOME/.claude/skills/New-Brain}"
SKILL_DST="$SKILL_DST_DIR/SKILL.md"

if [[ ! -f "$SKILL_SRC" ]]; then
  echo "Error: SKILL.md not found at $SKILL_SRC. Run from inside a checkout of mh-new-brain." >&2
  exit 1
fi

mkdir -p "$SKILL_DST_DIR"

backup_if_exists() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    local backup
    backup="${path}.bak.$(date +%Y%m%d-%H%M%S)"
    echo "  Backing up existing $path → $backup"
    mv "$path" "$backup"
  fi
}

backup_if_exists "$SKILL_DST"

if [[ "$MODE" == "symlink" ]]; then
  ln -s "$SKILL_SRC" "$SKILL_DST"
  echo "Symlinked: $SKILL_DST → $SKILL_SRC"
else
  cp "$SKILL_SRC" "$SKILL_DST"
  echo "Copied: $SKILL_SRC → $SKILL_DST"
fi

echo
echo "Install complete. Restart Claude Code, then run:"
echo "  /New-Brain"
