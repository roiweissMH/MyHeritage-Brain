#!/usr/bin/env bash
# release.sh — cut a new release: sync templates, run tests, bump version,
# update CHANGELOG, commit, and push to origin/main.
#
# Usage:
#   ./scripts/release.sh "<commit message>"          # patch bump (0.0.X)
#   ./scripts/release.sh --minor "<commit message>"  # minor bump (0.X.0)
#   ./scripts/release.sh --major "<commit message>"  # major bump (X.0.0)
#   ./scripts/release.sh --dry-run "<commit message>" # do everything except push
#
# Run from anywhere; the script cd's to the repo root.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_DIR"

BUMP="patch"
DRY_RUN=0
MESSAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --major)   BUMP="major";   shift;;
    --minor)   BUMP="minor";   shift;;
    --patch)   BUMP="patch";   shift;;
    --dry-run) DRY_RUN=1;    shift;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0;;
    -*) echo "Unknown flag: $1" >&2; exit 2;;
    *)  MESSAGE="$1"; shift;;
  esac
done

if [[ -z "$MESSAGE" ]]; then
  echo "Usage: $0 [--major|--minor|--patch] [--dry-run] \"<commit message>\"" >&2
  exit 2
fi

# --- Preconditions --------------------------------------------------------

current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$current_branch" != "main" ]]; then
  echo "✗ release.sh: must be on 'main' (currently '$current_branch')." >&2
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "✗ release.sh: uncommitted changes detected. Commit or stash first:" >&2
  git status --short >&2
  exit 1
fi

if [[ ! -f VERSION ]]; then
  echo "0.0.0" > VERSION
fi

# --- 1. Sync templates from mh-billing-brain ------------------------------

echo "→ Syncing templates from mh-billing-brain..."
./scripts/sync-templates.sh >/dev/null

# --- 2. Run the test suite (abort on failure) -----------------------------

echo "→ Running tests..."
if ! bash tests/run-all.sh >/dev/null 2>&1; then
  echo "✗ release.sh: tests failed. Aborting release. Re-run tests to see the failures:" >&2
  echo "    bash tests/run-all.sh" >&2
  # Revert any template changes we just made so the working tree is clean again.
  git checkout -- templates/ >/dev/null 2>&1 || true
  exit 1
fi

# --- 3. Bump the version --------------------------------------------------

old_version="$(tr -d '[:space:]' < VERSION)"
IFS='.' read -r MAJ MIN PAT <<<"$old_version"
case "$BUMP" in
  major) MAJ=$((MAJ+1)); MIN=0; PAT=0;;
  minor) MIN=$((MIN+1)); PAT=0;;
  patch) PAT=$((PAT+1));;
esac
new_version="$MAJ.$MIN.$PAT"
echo "$new_version" > VERSION

# --- 4. Prepend a CHANGELOG entry -----------------------------------------

today="$(date +%Y-%m-%d)"
tmp_changelog="$(mktemp)"
marker='<!-- release.sh inserts new entries below this line -->'

if ! grep -qF "$marker" CHANGELOG.md 2>/dev/null; then
  echo "✗ release.sh: marker not found in CHANGELOG.md. Add this line under the H1:" >&2
  echo "    $marker" >&2
  # Revert version bump + template changes.
  echo "$old_version" > VERSION
  git checkout -- templates/ >/dev/null 2>&1 || true
  exit 1
fi

awk -v entry_header="## $new_version — $today" \
    -v entry_body="- $MESSAGE" \
    -v marker="$marker" '
  {
    print
    if ($0 ~ marker) {
      print ""
      print entry_header
      print ""
      print entry_body
    }
  }
' CHANGELOG.md > "$tmp_changelog"
mv "$tmp_changelog" CHANGELOG.md

# --- 5. Commit ------------------------------------------------------------

echo "→ Version: $old_version → $new_version"
echo "→ Committing..."
git add templates/ VERSION CHANGELOG.md
git commit -m "$(cat <<EOF
Release $new_version: $MESSAGE

$MESSAGE
EOF
)" >/dev/null

# --- 6. Push (unless --dry-run) -------------------------------------------

if [[ $DRY_RUN -eq 1 ]]; then
  echo ""
  echo "✓ Dry run complete. $new_version committed locally; NOT pushed."
  echo "  To push:   git push origin main"
  echo "  To revert: git reset --hard HEAD~1 && rm -f VERSION && git checkout -- ."
  exit 0
fi

echo "→ Pushing to origin/main..."
git push origin main

echo ""
echo "✓ Released $new_version"
git log -1 --oneline
echo ""
echo "Consumers pick up the change with:"
echo "    cd ~/Claude/mh-new-brain && ./update.sh"
