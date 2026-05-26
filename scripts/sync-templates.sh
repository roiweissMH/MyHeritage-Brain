#!/usr/bin/env bash
# sync-templates.sh — regenerates templates/ from the canonical mh-billing-brain files.
#
# Usage: ./scripts/sync-templates.sh [--out <dir>] [--check]
#   --out <dir>   write to <dir> instead of ./templates (used by tests)
#   --check       do not write to ./templates; run sync into a temp dir and
#                 compare against the current templates/. Exit 0 if in sync,
#                 exit 1 (and print the diff) if drift is detected. Used by
#                 the pre-commit hook and CI.
#
# This script is run by the maintainer whenever mh-billing-brain's SKILL.md,
# install.sh, README.md, or brain/ files change. The output is committed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BILLING_DIR="${BILLING_DIR:-$HOME/Claude/mh-billing-brain}"
OUT_DIR="$REPO_DIR/templates"
CHECK_MODE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT_DIR="$2"; shift 2;;
    --check) CHECK_MODE=1; shift;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

# In --check mode, redirect sync output to a temp dir; remember the real
# templates dir so we can diff against it after the sync runs.
REAL_OUT_DIR=""
if [[ $CHECK_MODE -eq 1 ]]; then
  REAL_OUT_DIR="$OUT_DIR"
  OUT_DIR="$(mktemp -d)"
  trap 'rm -rf "$OUT_DIR"' EXIT
fi

if [[ ! -d "$BILLING_DIR" ]]; then
  echo "Error: BILLING_DIR not found: $BILLING_DIR" >&2
  echo "Set BILLING_DIR env var or ensure mh-billing-brain is cloned at \$HOME/Claude/mh-billing-brain." >&2
  exit 1
fi

mkdir -p "$OUT_DIR/brain/references"
touch "$OUT_DIR/brain/references/.gitkeep"

# Helper: substitute Billing-specific tokens with placeholders.
# Uses sed with '|' delimiter to avoid escaping forward slashes in paths.
substitute() {
  sed \
    -e 's| & Payments||g' \
    -e 's|skills/Billing-Brain|skills/<Skill-Name>|g' \
    -e 's|/Billing-Brain|<skill-cmd>|g' \
    -e 's|Billing-Brain|<Skill-Name>|g' \
    -e 's|brains/billing/|brains/<domain-slug>/|g' \
    -e 's|brains/billing|brains/<domain-slug>|g' \
    -e 's|mh-billing-brain|mh-<domain-slug>-brain|g' \
    -e 's|Billing|<DOMAIN>|g'
}

# 1. .gitignore — copy as-is (no substitutions needed).
cp "$BILLING_DIR/.gitignore" "$OUT_DIR/.gitignore"

# 2. SKILL.md.tmpl — substitute domain tokens. Also rewrite the description line.
substitute < "$BILLING_DIR/SKILL.md" > "$OUT_DIR/SKILL.md.tmpl"
# Replace the description line with a parameterized version.
# The Billing SKILL.md has "description: Query, interview, verify, audit, capture, or refresh the <DOMAIN> domain brain..."
# After the generic substitution above, "Billing" became "<DOMAIN>" so the line is already valid.

# 3. install.sh.tmpl — substitute path tokens.
substitute < "$BILLING_DIR/install.sh" > "$OUT_DIR/install.sh.tmpl"
chmod +x "$OUT_DIR/install.sh.tmpl"

# 4. README.md.tmpl — substitute. Strip the "Status of the brain (snapshot)" section
#    since it's Billing-specific; the scaffolder regenerates a fresh snapshot.
substitute < "$BILLING_DIR/README.md" \
  | sed -e 's|This is the pilot domain of a broader \*\*MH Product Brain\*\* initiative\. The same pattern is intended to expand to Backoffice and Site domains\.|This brain follows the **MH Product Brain** pattern described in `docs/design-spec.md`.|' \
  | awk '
      /^## Status of the brain/ { skip=1 }
      !skip { print }
    ' > "$OUT_DIR/README.md.tmpl"

# 5. brain/brain.md.tmpl — preserve the topic template comment block, strip any
#    actual topic H2 sections (Billing-specific content).
awk '
  /^## Topic template/ { in_template=1 }
  /^<!-- Topics begin below this line -->/ { print; in_template=0; in_topics=1; next }
  in_topics && /^## / { skip_topic=1 }
  skip_topic { next }
  { print }
' "$BILLING_DIR/brain/brain.md" | substitute > "$OUT_DIR/brain/brain.md.tmpl"

# 6. brain/_meta.md.tmpl — write a fresh parameterized header + topic table marker.
#    We do NOT carry over Billing's topic rows.
cat > "$OUT_DIR/brain/_meta.md.tmpl" <<'EOF'
# <DOMAIN> Brain — Meta Index

The `<skill-cmd>` skill reads this file first on every invocation. Edit only via skill commands or carefully by hand.

**Domain:** <DOMAIN>
**Description:** <DESCRIPTION>
**Audience:** <AUDIENCE>
**Owner:** <OWNER>
**Bootstrapped:** <BOOTSTRAP_DATE>
**Brain file:** `brain.md`
**References folder:** `references/`
**Last reviewed:** <BOOTSTRAP_DATE>

<!--
Optional: enable the Layer 4 codebase knowledge source. Uncomment and fill in
to let the brain query a GitHub repo as a live source of truth for current-
behavior facts (product IDs, prices, configs, flags, etc.). See "Domain
codebase layer" in SKILL.md.

**Codebase:**
- primary_repo: <owner>/<repo>
- paths_of_interest:
  - <path/within/repo>
- access: requires `gh auth login` with read access to <owner>/<repo>.
-->

---

## Topic Index

| # | Topic | Status | Last-updated | Refs | Summary |
|---|-------|--------|--------------|------|---------|
<!-- TOPIC_TABLE -->

---

## Status legend

- **empty** — topic has no narrative yet; needs an interview.
- **interviewed** — narrative + facts captured; not cross-checked against any reference doc.
- **verified** — facts cross-checked against at least one reference doc.
- **stale** — derived flag (not a stored status). Surfaced by audit mode when `last-updated` is >90 days old.

---

## Reference stub backlog

Stub references (named during interviews but not yet provided) appear here automatically. Each line: `- references/<slug>.md — requested by Topic <name> on YYYY-MM-DD`.

<!-- REFERENCE_STUB_BACKLOG -->
EOF

# 7. brain/interview-log.md.tmpl — fresh header.
cat > "$OUT_DIR/brain/interview-log.md.tmpl" <<'EOF'
# <DOMAIN> Brain — Interview Log

Raw transcripts from interview sessions, in reverse chronological order. Each session is tagged with topic and date. Do not edit by hand — the `<skill-cmd>` skill appends here during interviews.

---
EOF

if [[ $CHECK_MODE -eq 1 ]]; then
  if diff -rq "$REAL_OUT_DIR" "$OUT_DIR" >/dev/null 2>&1; then
    echo "Templates are in sync with $BILLING_DIR"
    exit 0
  fi
  echo "Drift detected: templates/ does not match what sync-templates.sh would produce from $BILLING_DIR" >&2
  echo "" >&2
  diff -ru "$REAL_OUT_DIR" "$OUT_DIR" >&2 || true
  exit 1
fi

echo "Templates synced to $OUT_DIR"
