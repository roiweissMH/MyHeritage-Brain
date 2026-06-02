#!/usr/bin/env bash
# install-brain.sh <name> — clone a domain brain from the catalog and install it.
#
# Usage:
#   ./scripts/install-brain.sh <name>
#
# Examples:
#   ./scripts/install-brain.sh billing
#
# Behavior:
#   1. Looks up <name> in brains.txt to get repo, skill, owner, description.
#   2. Clones the repo to ~/mh-<name>-brain/ (or runs `git pull` if it already exists).
#   3. Runs the brain's own install.sh, which deploys the skill into
#      ~/.claude/skills/<Skill-Name>/ and the brain content into
#      ~/Claude/brains/<name>/.
#   4. Reminds you to restart Claude Code.
#
# Requires git + the brain's repo to be accessible (you must be invited as a
# GitHub collaborator on private brain repos). For access checks, also requires
# the `gh` CLI authenticated.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CATALOG="$REPO_DIR/brains.txt"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <name>" >&2
  echo "       Run ./scripts/list-brains.sh to see available brain names." >&2
  exit 2
fi

NAME="$1"

if [[ ! -f "$CATALOG" ]]; then
  echo "✗ Catalog not found at $CATALOG" >&2
  exit 1
fi

# Look up the brain in the catalog.
SKILL=""; REPO=""; OWNER=""; DESC=""
while IFS='|' read -r name skill repo owner description; do
  [[ "$name" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${name// }" ]] && continue
  if [[ "$name" == "$NAME" ]]; then
    SKILL="$skill"; REPO="$repo"; OWNER="$owner"; DESC="$description"
    break
  fi
done < "$CATALOG"

if [[ -z "$SKILL" ]]; then
  echo "✗ Brain '$NAME' not found in $CATALOG" >&2
  echo "  Run ./scripts/list-brains.sh to see known brain names." >&2
  exit 1
fi

CLONE_DIR="$HOME/mh-${NAME}-brain"

echo "→ Brain:       $SKILL"
echo "  Repository:  $REPO"
echo "  Owner:       $OWNER"
echo "  Description: $DESC"
echo "  Clone path:  $CLONE_DIR"
echo ""

if [[ -d "$CLONE_DIR/.git" ]]; then
  echo "→ $CLONE_DIR already exists — fetching latest from origin"
  (cd "$CLONE_DIR" && git pull --rebase --autostash)
elif [[ -e "$CLONE_DIR" ]]; then
  echo "✗ $CLONE_DIR exists but isn't a git repo — refusing to overwrite." >&2
  echo "  Move or delete it and re-run." >&2
  exit 1
else
  echo "→ Cloning https://github.com/$REPO.git → $CLONE_DIR"
  if ! git clone "https://github.com/$REPO.git" "$CLONE_DIR"; then
    echo "" >&2
    echo "✗ Clone failed. Likely cause: you don't have access to $REPO." >&2
    echo "  Ping $OWNER to be added as a GitHub collaborator on $REPO." >&2
    exit 1
  fi
fi

if [[ ! -x "$CLONE_DIR/install.sh" ]]; then
  echo "✗ No executable install.sh in $CLONE_DIR" >&2
  exit 1
fi

echo ""
echo "→ Running $CLONE_DIR/install.sh"
(cd "$CLONE_DIR" && ./install.sh)

echo ""
echo "✓ $SKILL installed."
echo "  Restart Claude Code to start using /$SKILL."
