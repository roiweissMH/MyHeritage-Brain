#!/usr/bin/env bash
# Verifies that install.sh deploys SKILL.md to a New-Brain skill location.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Override the install destination via env var.
export NEW_BRAIN_SKILL_DST_DIR="$WORK/skills/New-Brain"

# Need a placeholder SKILL.md in the repo for install to copy.
# (The real one is written in Task 5; here we use a stub.)
PLACEHOLDER_SKILL="$WORK/placeholder-SKILL.md"
echo "stub" > "$PLACEHOLDER_SKILL"
ORIG_SKILL="$REPO_DIR/SKILL.md"
ORIG_SKILL_BACKUP=""
if [[ -f "$ORIG_SKILL" ]]; then
  ORIG_SKILL_BACKUP="$WORK/orig-SKILL.md.bak"
  cp "$ORIG_SKILL" "$ORIG_SKILL_BACKUP"
fi
cp "$PLACEHOLDER_SKILL" "$ORIG_SKILL"

restore_orig() {
  if [[ -n "$ORIG_SKILL_BACKUP" ]]; then
    cp "$ORIG_SKILL_BACKUP" "$ORIG_SKILL"
  else
    rm -f "$ORIG_SKILL"
  fi
}
trap 'rm -rf "$WORK"; restore_orig' EXIT

# --- Default (copy) mode ---
bash "$REPO_DIR/install.sh" >/dev/null
assert_file_exists "$NEW_BRAIN_SKILL_DST_DIR/SKILL.md" "SKILL.md should be deployed"
deployed="$(cat "$NEW_BRAIN_SKILL_DST_DIR/SKILL.md")"
assert_eq "$deployed" "stub" "deployed SKILL.md should match source"
# In copy mode the destination is a regular file, not a symlink.
if [[ -L "$NEW_BRAIN_SKILL_DST_DIR/SKILL.md" ]]; then
  TESTS_RUN=$((TESTS_RUN + 1)); TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: default mode should copy, not symlink"
else
  TESTS_RUN=$((TESTS_RUN + 1))
fi

# --- Idempotent re-install backs up existing file ---
echo "different" > "$NEW_BRAIN_SKILL_DST_DIR/SKILL.md"
bash "$REPO_DIR/install.sh" >/dev/null
BAK_COUNT="$(find "$NEW_BRAIN_SKILL_DST_DIR" -name 'SKILL.md.bak.*' | wc -l | tr -d ' ')"
assert_eq "$BAK_COUNT" "1" "second install should create one backup"

# --- Symlink mode ---
rm -rf "$NEW_BRAIN_SKILL_DST_DIR"
bash "$REPO_DIR/install.sh" --symlink >/dev/null
if [[ ! -L "$NEW_BRAIN_SKILL_DST_DIR/SKILL.md" ]]; then
  TESTS_RUN=$((TESTS_RUN + 1)); TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: --symlink mode should create a symlink"
else
  TESTS_RUN=$((TESTS_RUN + 1))
fi

# --- Unknown arg returns non-zero ---
TESTS_RUN=$((TESTS_RUN + 1))
if bash "$REPO_DIR/install.sh" --bogus-flag >/dev/null 2>&1; then
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: unknown arg should exit non-zero"
fi

test_summary "install"
