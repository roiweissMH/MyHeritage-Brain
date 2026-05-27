# Changelog

All notable changes to `/New-Brain` (the scaffolder + skill engine for MyHeritage domain brains). Newest entries first. Maintained by `scripts/release.sh`.

<!-- release.sh inserts new entries below this line -->

## 0.4.0 — 2026-05-27

- Add Layer 5: Domain Jira board (per-brain, via Atlassian MCP) + topic-level Jira anchors

## 0.3.0 — 2026-05-26

- Bake 'private GitHub repo per brain' into /New-Brain Phase 4 as the new default

## 0.2.0 — 2026-05-26

- Add Layer 4 codebase knowledge source (per-brain GitHub repo) + topic-level code anchors

## 0.1.0 — 2026-05-26

- Initial tagged release.
- `/New-Brain` skill bootstraps a new domain brain via a guided 5-phase interview.
- Templates are synced from canonical `mh-billing-brain` SKILL via `scripts/sync-templates.sh`.
- MyHeritage common-context layer (Welcome / Onboarding, Help Center, Knowledge Base / Education) inherited by every new brain.
- Pre-commit hook (`scripts/hooks/pre-commit`) + CI (`.github/workflows/ci.yml`) prevent template drift from `mh-billing-brain`.
- Release tooling: `scripts/release.sh` cuts versioned releases; `update.sh` lets consumers pull + reinstall in one command.
