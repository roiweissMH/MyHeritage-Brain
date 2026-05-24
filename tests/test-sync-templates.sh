#!/usr/bin/env bash
# Verifies that sync-templates.sh produces parameterized templates from mh-billing-brain.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Run sync into a temp output dir (don't pollute the real templates/).
TMP_OUT="$(mktemp -d)"
trap 'rm -rf "$TMP_OUT"' EXIT

bash "$REPO_DIR/scripts/sync-templates.sh" --out "$TMP_OUT" >/dev/null

# --- Files produced ---
assert_file_exists "$TMP_OUT/SKILL.md.tmpl" "SKILL.md.tmpl missing"
assert_file_exists "$TMP_OUT/install.sh.tmpl" "install.sh.tmpl missing"
assert_file_exists "$TMP_OUT/README.md.tmpl" "README.md.tmpl missing"

# --- README.md.tmpl shape ---
readme_tmpl="$(cat "$TMP_OUT/README.md.tmpl")"
assert_contains "$readme_tmpl" "<DOMAIN>" "README.md.tmpl should use <DOMAIN> placeholder"
assert_not_contains "$readme_tmpl" "Status of the brain" "README.md.tmpl should strip the snapshot section"
assert_not_contains "$readme_tmpl" "& Payments" "README.md.tmpl should strip Billing-specific '& Payments' phrase"
assert_not_contains "$readme_tmpl" "Billing-Brain" "README.md.tmpl should not contain Billing-Brain"
assert_not_contains "$readme_tmpl" "expand to <DOMAIN> and Site" "README.md.tmpl should strip the Billing pilot/roadmap sentence"
assert_file_exists "$TMP_OUT/.gitignore" ".gitignore missing"
assert_file_exists "$TMP_OUT/brain/_meta.md.tmpl" "_meta.md.tmpl missing"
assert_file_exists "$TMP_OUT/brain/brain.md.tmpl" "brain.md.tmpl missing"
assert_file_exists "$TMP_OUT/brain/interview-log.md.tmpl" "interview-log.md.tmpl missing"
assert_file_exists "$TMP_OUT/brain/references/.gitkeep" "references/.gitkeep missing"

# --- SKILL.md.tmpl substitutions ---
skill_tmpl="$(cat "$TMP_OUT/SKILL.md.tmpl")"
assert_contains "$skill_tmpl" "<Skill-Name>" "SKILL.md.tmpl should use <Skill-Name> placeholder"
assert_contains "$skill_tmpl" "<domain-slug>" "SKILL.md.tmpl should use <domain-slug> placeholder"
assert_not_contains "$skill_tmpl" "Billing-Brain" "SKILL.md.tmpl should not contain Billing-Brain"
assert_not_contains "$skill_tmpl" "brains/billing/" "SKILL.md.tmpl should not contain brains/billing/"

# --- install.sh.tmpl substitutions ---
install_tmpl="$(cat "$TMP_OUT/install.sh.tmpl")"
assert_contains "$install_tmpl" "<Skill-Name>" "install.sh.tmpl should use <Skill-Name> placeholder"
assert_contains "$install_tmpl" "<domain-slug>" "install.sh.tmpl should use <domain-slug> placeholder"
assert_not_contains "$install_tmpl" "Billing-Brain" "install.sh.tmpl should not contain Billing-Brain"
assert_not_contains "$install_tmpl" "brains/billing" "install.sh.tmpl should not contain brains/billing"

# --- _meta.md.tmpl shape ---
meta_tmpl="$(cat "$TMP_OUT/brain/_meta.md.tmpl")"
assert_contains "$meta_tmpl" "<DOMAIN>" "_meta.md.tmpl should use <DOMAIN> placeholder"
assert_contains "$meta_tmpl" "**Domain:**" "_meta.md.tmpl should declare Domain field"
assert_contains "$meta_tmpl" "**Description:**" "_meta.md.tmpl should declare Description field"
assert_contains "$meta_tmpl" "**Audience:**" "_meta.md.tmpl should declare Audience field"
assert_contains "$meta_tmpl" "**Owner:**" "_meta.md.tmpl should declare Owner field"
assert_contains "$meta_tmpl" "**Bootstrapped:**" "_meta.md.tmpl should declare Bootstrapped field"
assert_contains "$meta_tmpl" "## Topic Index" "_meta.md.tmpl should have topic index"
assert_contains "$meta_tmpl" "<!-- TOPIC_TABLE -->" "_meta.md.tmpl should mark topic table insertion point"
assert_contains "$meta_tmpl" "<!-- REFERENCE_STUB_BACKLOG -->" "_meta.md.tmpl should mark stub backlog insertion point"
assert_not_contains "$meta_tmpl" "Lyad" "_meta.md.tmpl should not contain Billing-specific names"
assert_not_contains "$meta_tmpl" "Roi Weiss" "_meta.md.tmpl should not contain Billing owner name"

# --- brain.md.tmpl shape ---
brain_tmpl="$(cat "$TMP_OUT/brain/brain.md.tmpl")"
assert_contains "$brain_tmpl" "<DOMAIN>" "brain.md.tmpl should use <DOMAIN> placeholder"
assert_contains "$brain_tmpl" "## Topic template" "brain.md.tmpl should include topic template comment"
assert_not_contains "$brain_tmpl" "## Band & Team" "brain.md.tmpl should not contain Billing's Band & Team H2"

# --- interview-log.md.tmpl shape ---
log_tmpl="$(cat "$TMP_OUT/brain/interview-log.md.tmpl")"
assert_contains "$log_tmpl" "<DOMAIN>" "interview-log.md.tmpl should use <DOMAIN> placeholder"
assert_contains "$log_tmpl" "Raw transcripts" "interview-log.md.tmpl should include header explanation"
assert_not_contains "$log_tmpl" "Band & Team — 2026" "interview-log.md.tmpl should not contain Billing transcripts"

test_summary "sync-templates"
