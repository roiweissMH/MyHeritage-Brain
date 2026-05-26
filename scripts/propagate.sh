#!/usr/bin/env bash
# propagate.sh — push the current engine to every deployed <Domain>-Brain skill.
#
# Each deployed brain skill at ~/.claude/skills/<Domain>-Brain/SKILL.md is
# regenerated from templates/SKILL.md.tmpl, substituting the brain's own
# domain name. The previous version is backed up. The brain's content
# (interviews, references in ~/Claude/brains/...) is NOT touched.
#
# Usage:
#   ./scripts/propagate.sh             # update all installed brain skills
#   ./scripts/propagate.sh --dry-run   # preview what would change; write nothing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="${MH_BRAIN_SKILLS_DIR:-$HOME/.claude/skills}"
TEMPLATE="$REPO_DIR/templates/SKILL.md.tmpl"

DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift;;
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

if [[ ! -f "$TEMPLATE" ]]; then
  echo "✗ propagate.sh: template not found at $TEMPLATE" >&2
  exit 1
fi

if [[ ! -d "$SKILLS_DIR" ]]; then
  echo "No skills directory at $SKILLS_DIR — nothing to propagate."
  exit 0
fi

# Find every <Domain>-Brain/ directory, excluding the scaffolder (New-Brain).
shopt -s nullglob
found=()
for skill_dir in "$SKILLS_DIR"/*-Brain; do
  [[ -d "$skill_dir" ]] || continue
  name="$(basename "$skill_dir")"
  [[ "$name" == "New-Brain" ]] && continue
  found+=("$skill_dir")
done

if [[ ${#found[@]} -eq 0 ]]; then
  echo "No domain brain skills installed yet (other than /New-Brain). Nothing to propagate."
  exit 0
fi

if [[ $DRY_RUN -eq 1 ]]; then
  echo "→ Propagate (dry-run) — engine template: $TEMPLATE"
else
  echo "→ Propagating engine to ${#found[@]} installed brain(s) from: $TEMPLATE"
fi

ts="$(date +%Y%m%d-%H%M%S)"
updated=0
unchanged=0
errors=0

for skill_dir in "${found[@]}"; do
  skill_name="$(basename "$skill_dir")"             # e.g., Billing-Brain
  domain="${skill_name%-Brain}"                     # e.g., Billing
  slug="$(echo "$domain" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -c 'a-z0-9\n' '-' \
    | sed -e 's/--*/-/g' -e 's/^-//' -e 's/-$//')"
  skill_md="$skill_dir/SKILL.md"

  new_content="$(sed \
    -e "s|<DOMAIN>|$domain|g" \
    -e "s|<domain-slug>|$slug|g" \
    -e "s|<Skill-Name>|$skill_name|g" \
    -e "s|<skill-cmd>|/$skill_name|g" \
    "$TEMPLATE")"

  if [[ -f "$skill_md" ]]; then
    current_content="$(cat "$skill_md")"
    if [[ "$current_content" == "$new_content" ]]; then
      echo "  ·  $skill_name — already current"
      unchanged=$((unchanged + 1))
      continue
    fi
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  ✎ $skill_name — would be updated (domain: $domain, slug: $slug)"
    updated=$((updated + 1))
    continue
  fi

  # Backup + write.
  if [[ -f "$skill_md" ]]; then
    cp "$skill_md" "$skill_md.bak.$ts" || { echo "  ✗ $skill_name — backup failed" >&2; errors=$((errors+1)); continue; }
  fi
  if ! printf '%s\n' "$new_content" > "$skill_md"; then
    echo "  ✗ $skill_name — write failed" >&2
    errors=$((errors + 1))
    continue
  fi
  echo "  ✓ $skill_name — updated (backup: SKILL.md.bak.$ts)"
  updated=$((updated + 1))
done

echo ""
if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry-run summary: $updated would change, $unchanged unchanged, $errors error(s)."
else
  echo "Propagation summary: $updated updated, $unchanged unchanged, $errors error(s)."
  if [[ $updated -gt 0 ]]; then
    echo ""
    echo "Restart Claude Code so it picks up the SKILL.md changes."
  fi
fi

if [[ $errors -gt 0 ]]; then
  exit 1
fi
exit 0
