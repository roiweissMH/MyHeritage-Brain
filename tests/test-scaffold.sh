#!/usr/bin/env bash
# Verifies that scaffold.sh produces a structurally complete mh-<domain>-brain/ repo
# from the templates and the PM-provided values.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Workspace: a sandboxed HOME-equivalent.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Test inputs.
TOPICS_FILE="$WORK/topics.txt"
ANCHORS_FILE="$WORK/anchors.txt"
LOG_FILE="$WORK/bootstrap-log.md"

cat > "$TOPICS_FILE" <<'EOF'
Onboarding|How new hires get set up in the backoffice
Reporting|How reports are generated, tracked, and delivered
Permissions|Who can access what
EOF

cat > "$ANCHORS_FILE" <<'EOF'
Backoffice onboarding guide|https://confluence.example.com/backoffice-onboarding
Permissions matrix|
EOF

cat > "$LOG_FILE" <<'EOF'
## Bootstrap — 2026-05-24

### Phase 1: Identity
Q: What's the domain called?
A: Backoffice
EOF

# Run the scaffolder.
bash "$REPO_DIR/scripts/scaffold.sh" \
  --root "$WORK" \
  --domain "Backoffice" \
  --slug "backoffice" \
  --skill-name "Backoffice-Brain" \
  --description "Internal tools used by Support, Sales, and Ops to manage user accounts." \
  --audience "Backoffice PMs + Support liaisons" \
  --owner "Roi Weiss" \
  --bootstrap-date "2026-05-24" \
  --topics-file "$TOPICS_FILE" \
  --anchors-file "$ANCHORS_FILE" \
  --interview-log-file "$LOG_FILE" \
  > /dev/null

# --- Repo skeleton ---
NEW_REPO="$WORK/mh-backoffice-brain"
assert_file_exists "$NEW_REPO/README.md" "new repo README missing"
assert_file_exists "$NEW_REPO/SKILL.md" "new repo SKILL.md missing"
assert_file_exists "$NEW_REPO/install.sh" "new repo install.sh missing"
assert_file_exists "$NEW_REPO/.gitignore" "new repo .gitignore missing"
assert_file_exists "$NEW_REPO/brain/_meta.md" "new repo _meta.md missing"
assert_file_exists "$NEW_REPO/brain/brain.md" "new repo brain.md missing"
assert_file_exists "$NEW_REPO/brain/interview-log.md" "new repo interview-log.md missing"
assert_file_exists "$NEW_REPO/brain/references/.gitkeep" "new repo .gitkeep missing"
assert_file_exists "$NEW_REPO/brain/references/backoffice-onboarding-guide.md" "first anchor stub missing"
assert_file_exists "$NEW_REPO/brain/references/permissions-matrix.md" "second anchor stub missing"

# --- Substitutions in SKILL.md ---
skill="$(cat "$NEW_REPO/SKILL.md")"
assert_contains "$skill" "Backoffice-Brain" "SKILL.md should contain Backoffice-Brain"
assert_not_contains "$skill" "<Skill-Name>" "SKILL.md should not contain unresolved placeholder"
assert_not_contains "$skill" "<domain-slug>" "SKILL.md should not contain unresolved placeholder"
assert_not_contains "$skill" "<DOMAIN>" "SKILL.md should not contain unresolved placeholder"
assert_not_contains "$skill" "Billing-Brain" "SKILL.md should not contain Billing-Brain"

# --- _meta.md content ---
meta="$(cat "$NEW_REPO/brain/_meta.md")"
assert_contains "$meta" "**Domain:** Backoffice" "_meta.md should record domain"
assert_contains "$meta" "**Owner:** Roi Weiss" "_meta.md should record owner"
assert_contains "$meta" "**Bootstrapped:** 2026-05-24" "_meta.md should record bootstrap date"
assert_contains "$meta" "| 1 | Onboarding |" "_meta.md should list first topic"
assert_contains "$meta" "| 2 | Reporting |" "_meta.md should list second topic"
assert_contains "$meta" "| 3 | Permissions |" "_meta.md should list third topic"
assert_contains "$meta" "references/backoffice-onboarding-guide.md" "_meta.md backlog should list first anchor"
assert_contains "$meta" "references/permissions-matrix.md" "_meta.md backlog should list second anchor"
assert_not_contains "$meta" "<!-- TOPIC_TABLE -->" "_meta.md should not contain raw marker"
assert_not_contains "$meta" "<!-- REFERENCE_STUB_BACKLOG -->" "_meta.md should not contain raw marker"

# --- brain.md content ---
brain="$(cat "$NEW_REPO/brain/brain.md")"
assert_contains "$brain" "# Backoffice Brain" "brain.md should have domain title"
assert_contains "$brain" "## Topic template" "brain.md should preserve topic template comment"
assert_not_contains "$brain" "<DOMAIN>" "brain.md should not contain unresolved placeholder"

# --- interview-log.md content ---
log="$(cat "$NEW_REPO/brain/interview-log.md")"
assert_contains "$log" "# Backoffice Brain — Interview Log" "log should have domain header"
assert_contains "$log" "## Bootstrap — 2026-05-24" "log should contain the bootstrap entry"
assert_contains "$log" "### Phase 1: Identity" "log should contain phase markers"

# --- reference stub content ---
stub="$(cat "$NEW_REPO/brain/references/backoffice-onboarding-guide.md")"
assert_contains "$stub" "# Backoffice onboarding guide" "stub should record original title"
assert_contains "$stub" "status: linked" "stub with URL should be marked linked"
assert_contains "$stub" "https://confluence.example.com/backoffice-onboarding" "stub should record URL"

stub2="$(cat "$NEW_REPO/brain/references/permissions-matrix.md")"
assert_contains "$stub2" "status: missing" "stub without URL should be marked missing"

# --- install.sh content ---
inst="$(cat "$NEW_REPO/install.sh")"
assert_contains "$inst" "Backoffice-Brain" "install.sh should reference Backoffice-Brain"
assert_contains "$inst" "brains/backoffice" "install.sh should reference brains/backoffice"
assert_not_contains "$inst" "<domain-slug>" "install.sh should not contain unresolved placeholder"

# --- git repo initialized with initial commit ---
cd "$NEW_REPO"
assert_file_exists "$NEW_REPO/.git/HEAD" ".git directory should exist"
COMMIT_COUNT="$(git rev-list --count HEAD 2>/dev/null || echo 0)"
assert_eq "$COMMIT_COUNT" "1" "should have exactly one initial commit"

# --- no remote configured ---
REMOTES="$(git remote)"
assert_eq "$REMOTES" "" "no remotes should be configured"

# --- second invocation against existing repo fails safely ---
cd "$WORK"
if bash "$REPO_DIR/scripts/scaffold.sh" \
  --root "$WORK" \
  --domain "Backoffice" \
  --slug "backoffice" \
  --skill-name "Backoffice-Brain" \
  --description "Internal tools..." \
  --audience "..." \
  --owner "Roi Weiss" \
  --bootstrap-date "2026-05-24" \
  --topics-file "$TOPICS_FILE" \
  --anchors-file "$ANCHORS_FILE" \
  --interview-log-file "$LOG_FILE" \
  >/dev/null 2>&1; then
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: scaffold.sh should refuse to overwrite an existing repo without --force"
else
  TESTS_RUN=$((TESTS_RUN + 1))
fi

# --- Multi-line description survives via newline flattening ---
WORK2="$(mktemp -d)"
TOPICS2="$WORK2/topics.txt"
ANCHORS2="$WORK2/anchors.txt"
LOG2="$WORK2/bootstrap-log.md"
cat > "$TOPICS2" <<'EOF'
SingleTopic|just one
EOF
cat > "$ANCHORS2" <<'EOF'
Single Anchor|
EOF
printf '## Bootstrap — 2026-05-24\n' > "$LOG2"

MULTI_LINE_DESC="$(printf 'First line of description.\nSecond line of description.')"

bash "$REPO_DIR/scripts/scaffold.sh" \
  --root "$WORK2" \
  --domain "Multiline" \
  --slug "multiline" \
  --skill-name "Multiline-Brain" \
  --description "$MULTI_LINE_DESC" \
  --audience "x" \
  --owner "y" \
  --bootstrap-date "2026-05-24" \
  --topics-file "$TOPICS2" \
  --anchors-file "$ANCHORS2" \
  --interview-log-file "$LOG2" \
  > /dev/null

MULTI_META="$(cat "$WORK2/mh-multiline-brain/brain/_meta.md")"
assert_contains "$MULTI_META" "First line of description. Second line of description." \
  "multi-line description should be flattened with a space"
rm -rf "$WORK2"

test_summary "scaffold"
