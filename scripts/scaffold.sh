#!/usr/bin/env bash
# scaffold.sh — generates a new mh-<slug>-brain/ repo from templates/, filling
# placeholders with values supplied by the /New-Brain skill.
#
# Required flags:
#   --domain "<DOMAIN>"                 (e.g. "Backoffice")
#   --slug "<domain-slug>"              (e.g. "backoffice")
#   --skill-name "<Skill-Name>"         (e.g. "Backoffice-Brain")
#   --description "<paragraph>"         one-paragraph description
#   --audience "<text>"                 audience description
#   --owner "<name>"                    owner name
#   --bootstrap-date "YYYY-MM-DD"       today's date
#   --topics-file <path>                lines: "<name>|<one-line summary>"
#   --anchors-file <path>               lines: "<title>|<optional URL>"
#   --interview-log-file <path>         markdown content to embed as first log entry
#
# Optional:
#   --root <dir>                        write under <dir> instead of $HOME/Claude (used by tests)
#   --force                             overwrite existing repo
#
# Exit codes:
#   0 success
#   1 error (missing template / missing input file / bad arg)
#   2 conflict (target repo exists and --force not given)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$REPO_DIR/templates"

DOMAIN=""
SLUG=""
SKILL_NAME=""
DESCRIPTION=""
AUDIENCE=""
OWNER=""
BOOTSTRAP_DATE=""
TOPICS_FILE=""
ANCHORS_FILE=""
LOG_FILE=""
ROOT="$HOME/Claude"
FORCE=0

usage() {
  sed -n '2,30p' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain) DOMAIN="$2"; shift 2;;
    --slug) SLUG="$2"; shift 2;;
    --skill-name) SKILL_NAME="$2"; shift 2;;
    --description) DESCRIPTION="$2"; shift 2;;
    --audience) AUDIENCE="$2"; shift 2;;
    --owner) OWNER="$2"; shift 2;;
    --bootstrap-date) BOOTSTRAP_DATE="$2"; shift 2;;
    --topics-file) TOPICS_FILE="$2"; shift 2;;
    --anchors-file) ANCHORS_FILE="$2"; shift 2;;
    --interview-log-file) LOG_FILE="$2"; shift 2;;
    --root) ROOT="$2"; shift 2;;
    --force) FORCE=1; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1;;
  esac
done

# Validate required flags.
# Note: bash 3.2 (macOS default) does not support ${var,,} lowercase expansion.
# Use tr instead.
for var in DOMAIN SLUG SKILL_NAME DESCRIPTION AUDIENCE OWNER BOOTSTRAP_DATE TOPICS_FILE ANCHORS_FILE LOG_FILE; do
  if [[ -z "${!var}" ]]; then
    flag="$(echo "$var" | tr '[:upper:]' '[:lower:]' | tr '_' '-')"
    echo "Missing required flag: --${flag}" >&2
    exit 1
  fi
done

# Validate templates exist.
for tmpl in SKILL.md.tmpl install.sh.tmpl README.md.tmpl .gitignore \
            brain/_meta.md.tmpl brain/brain.md.tmpl brain/interview-log.md.tmpl; do
  if [[ ! -f "$TEMPLATES_DIR/$tmpl" ]]; then
    echo "Missing template: $TEMPLATES_DIR/$tmpl" >&2
    exit 1
  fi
done

# Validate input files exist.
for f in "$TOPICS_FILE" "$ANCHORS_FILE" "$LOG_FILE"; do
  if [[ ! -f "$f" ]]; then
    echo "Input file not found: $f" >&2
    exit 1
  fi
done

NEW_REPO="$ROOT/mh-${SLUG}-brain"

# Conflict check.
if [[ -d "$NEW_REPO" && "$FORCE" -ne 1 ]]; then
  echo "Target repo already exists: $NEW_REPO (pass --force to overwrite)" >&2
  exit 2
fi
if [[ "$FORCE" -eq 1 && -d "$NEW_REPO" ]]; then
  rm -rf "$NEW_REPO"
fi

mkdir -p "$NEW_REPO/brain/references" "$NEW_REPO/docs"
touch "$NEW_REPO/brain/references/.gitkeep"

# Substitution: write input to stdin, replace placeholders, write to stdout.
# Uses sed with the `|` delimiter; values are escaped for that delimiter.
escape_sed() {
  # Escape ampersand, pipe, and backslash for sed replacement.
  printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'
}

DOMAIN_ESC="$(escape_sed "$DOMAIN")"
SLUG_ESC="$(escape_sed "$SLUG")"
SKILL_NAME_ESC="$(escape_sed "$SKILL_NAME")"
DESCRIPTION_ESC="$(escape_sed "$DESCRIPTION")"
AUDIENCE_ESC="$(escape_sed "$AUDIENCE")"
OWNER_ESC="$(escape_sed "$OWNER")"
DATE_ESC="$(escape_sed "$BOOTSTRAP_DATE")"

substitute_placeholders() {
  sed \
    -e "s|<Skill-Name>|$SKILL_NAME_ESC|g" \
    -e "s|<skill-cmd>|/$SKILL_NAME_ESC|g" \
    -e "s|<domain-slug>|$SLUG_ESC|g" \
    -e "s|<DOMAIN>|$DOMAIN_ESC|g" \
    -e "s|<DESCRIPTION>|$DESCRIPTION_ESC|g" \
    -e "s|<AUDIENCE>|$AUDIENCE_ESC|g" \
    -e "s|<OWNER>|$OWNER_ESC|g" \
    -e "s|<BOOTSTRAP_DATE>|$DATE_ESC|g"
}

# 1. .gitignore
cp "$TEMPLATES_DIR/.gitignore" "$NEW_REPO/.gitignore"

# 2. SKILL.md
substitute_placeholders < "$TEMPLATES_DIR/SKILL.md.tmpl" > "$NEW_REPO/SKILL.md"

# 3. install.sh
substitute_placeholders < "$TEMPLATES_DIR/install.sh.tmpl" > "$NEW_REPO/install.sh"
chmod +x "$NEW_REPO/install.sh"

# 4. README.md
substitute_placeholders < "$TEMPLATES_DIR/README.md.tmpl" > "$NEW_REPO/README.md"

# 5. brain/brain.md
substitute_placeholders < "$TEMPLATES_DIR/brain/brain.md.tmpl" > "$NEW_REPO/brain/brain.md"

# 6. brain/interview-log.md — header + the user's bootstrap log.
{
  substitute_placeholders < "$TEMPLATES_DIR/brain/interview-log.md.tmpl"
  echo
  cat "$LOG_FILE"
} > "$NEW_REPO/brain/interview-log.md"

# 7. brain/_meta.md — substitute scalar fields + assemble topic table + stub backlog.
TOPIC_TABLE_TMP="$(mktemp)"
STUB_BACKLOG_TMP="$(mktemp)"
# Clean up scaffold's own temp files on exit (does not conflict with the test's trap).
cleanup_scaffold() {
  rm -f "$TOPIC_TABLE_TMP" "$STUB_BACKLOG_TMP"
}
trap cleanup_scaffold EXIT

# Build the topic table: one row per non-empty line in topics file.
n=0
while IFS='|' read -r topic_name topic_summary; do
  [[ -z "${topic_name:-}" ]] && continue
  n=$((n + 1))
  printf '| %d | %s | empty | — | 0 | %s |\n' "$n" "${topic_name}" "${topic_summary:-}" >> "$TOPIC_TABLE_TMP"
done < "$TOPICS_FILE"

# Build the stub backlog: one line per anchor.
while IFS='|' read -r anchor_title anchor_url; do
  [[ -z "${anchor_title:-}" ]] && continue
  slug="$(echo "$anchor_title" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//')"
  printf -- '- references/%s.md — requested by Bootstrap on %s\n' "$slug" "$BOOTSTRAP_DATE" >> "$STUB_BACKLOG_TMP"
done < "$ANCHORS_FILE"

# Render _meta.md by substituting placeholders, then injecting the table and backlog.
substitute_placeholders < "$TEMPLATES_DIR/brain/_meta.md.tmpl" \
  | awk -v table="$TOPIC_TABLE_TMP" -v backlog="$STUB_BACKLOG_TMP" '
      /<!-- TOPIC_TABLE -->/ {
        while ((getline line < table) > 0) print line
        close(table)
        next
      }
      /<!-- REFERENCE_STUB_BACKLOG -->/ {
        n=0
        while ((getline line < backlog) > 0) { print line; n++ }
        close(backlog)
        if (n == 0) print "(empty)"
        next
      }
      { print }
    ' > "$NEW_REPO/brain/_meta.md"

# 8. brain/references/<slug>.md — one stub per anchor.
while IFS='|' read -r anchor_title anchor_url; do
  [[ -z "${anchor_title:-}" ]] && continue
  slug="$(echo "$anchor_title" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//')"
  if [[ -n "${anchor_url:-}" ]]; then
    cat > "$NEW_REPO/brain/references/${slug}.md" <<EOF
# $anchor_title

<!-- status: linked -->
<!-- requested-by-topic: Bootstrap -->
<!-- requested-date: $BOOTSTRAP_DATE -->
<!-- source-url: $anchor_url -->

Stub file. Replace this content with the real reference doc (or a verbatim copy/excerpt) when available. Source URL is recorded above.
EOF
  else
    cat > "$NEW_REPO/brain/references/${slug}.md" <<EOF
# $anchor_title

<!-- status: missing -->
<!-- requested-by-topic: Bootstrap -->
<!-- requested-date: $BOOTSTRAP_DATE -->

Stub file. Replace this content with the real reference doc when available.
EOF
  fi
done < "$ANCHORS_FILE"

# 9. docs/design-spec.md — copy the New-Brain design spec into the new repo.
DESIGN_SPEC="$HOME/Claude/docs/superpowers/specs/2026-05-24-new-brain-meta-skill-design.md"
if [[ -f "$DESIGN_SPEC" ]]; then
  cp "$DESIGN_SPEC" "$NEW_REPO/docs/design-spec.md"
else
  # Fall back to a stub if the spec isn't on disk (e.g., test environment).
  echo "# Design spec not found at install time. See mh-new-brain/docs/design-spec.md." \
    > "$NEW_REPO/docs/design-spec.md"
fi

# 10. git init + initial commit (no remote).
cd "$NEW_REPO"
git init -q
git add .
git -c user.email="bootstrap@local" -c user.name="New-Brain bootstrap" commit -q -m "Initial scaffold via /New-Brain ($DOMAIN, $BOOTSTRAP_DATE)"

echo "Scaffold complete: $NEW_REPO"
