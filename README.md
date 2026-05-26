# MH New-Brain

Claude Code meta-skill that bootstraps a new domain brain (structurally identical to `mh-billing-brain`) in one guided Claude Code session.

This is the bootstrapper for the broader **MH Product Brain** initiative. Use it to start a brain for any MyHeritage Product domain.

## What's in the repo

```
mh-new-brain/
├── README.md                ← this file
├── SKILL.md                 ← /New-Brain skill definition (5-phase guided bootstrap)
├── VERSION                  ← current release version (semver)
├── CHANGELOG.md             ← release history (maintained by scripts/release.sh)
├── install.sh               ← deploys SKILL.md to ~/.claude/skills/New-Brain/
├── update.sh                ← user-facing: git pull + reinstall in one command
├── scripts/
│   ├── sync-templates.sh    ← regenerates templates/ from mh-billing-brain (supports --check)
│   ├── scaffold.sh          ← writes a new mh-<domain>-brain/ repo from templates + PM answers
│   ├── release.sh           ← maintainer-only: sync + test + bump + commit + push
│   ├── install-hooks.sh     ← wires repo-tracked hooks into .git/hooks/
│   ├── propagate.sh         ← updates every deployed <Domain>-Brain skill from the current template
│   └── hooks/
│       └── pre-commit       ← blocks commits when templates/ has drifted
├── templates/               ← canonical files copied into each new brain
│   ├── SKILL.md.tmpl
│   ├── install.sh.tmpl
│   ├── README.md.tmpl
│   ├── .gitignore
│   └── brain/
│       ├── _meta.md.tmpl
│       ├── brain.md.tmpl
│       ├── interview-log.md.tmpl
│       └── references/.gitkeep
├── tests/
│   ├── run-all.sh           ← runs every test-*.sh
│   ├── lib.sh
│   ├── test-sync-templates.sh
│   ├── test-scaffold.sh
│   └── test-install.sh
├── .github/workflows/
│   ├── ci.yml               ← shellcheck + template structure checks (push/PR to main)
│   └── notify-slack.yml     ← posts to #product-brains on release commits (inert until SLACK_WEBHOOK_URL is set)
└── docs/
    └── design-spec.md       ← the New-Brain design spec
```

## What `/New-Brain` does

When invoked in Claude Code, `/New-Brain` runs a 5-phase guided interview that produces a fully working brain:

| Phase | Duration | What happens |
|---|---|---|
| 0 — Pre-flight | silent | Checks for unfinished bootstraps and write permissions. |
| 1 — Identity | ≈2 min | Captures domain name, description, audience, owner. |
| 2 — Stakeholders & anchor docs | ≈2 min | Captures team + key reference docs. |
| 3 — Topic collection | ≈3–10 min | Hybrid: paste a doc OR run conversational probes. PM reviews the draft topic table. |
| 4 — Scaffolding | ≈30 sec | Calls `scaffold.sh`, runs the new brain's `install.sh`, writes completion marker. |
| 5 — First-topic handoff | optional | Hands off to the new `/<Domain>-Brain` skill for the first real topic interview. |

After Phase 4 completes, the PM has:
- A self-contained repo at `~/Claude/mh-<domain>-brain/` (git-initialized, no remote).
- A live `/<Domain>-Brain` Claude Code skill (same six commands as `/Billing-Brain`: query / interview / verify / status / capture / refresh).
- An empty brain seeded with the topic list, anchor doc stubs, and (optionally) a `Band & Team` topic with stakeholder info.

## Install

```bash
git clone https://github.com/roiweissMH/MyHeritage-Brain.git ~/Claude/mh-new-brain
cd ~/Claude/mh-new-brain
./install.sh
```

Then restart Claude Code so it discovers `/New-Brain`. The first time you run it, it'll guide you through Phase 0-5 above.

By default, `install.sh` **copies** files (safe — your clone can move or be deleted without breaking the install). Use `./install.sh --symlink` if you want edits to the deployed file to flow back into your clone.

## Update (for users)

To pull the latest `/New-Brain` and reinstall in one shot:

```bash
cd ~/Claude/mh-new-brain
./update.sh
```

`update.sh` does three things in order:

1. **Pulls** the latest from `origin/main`.
2. **Reinstalls** `/New-Brain` into `~/.claude/skills/New-Brain/`.
3. **Propagates** the engine to every domain brain you already have installed — `~/.claude/skills/<Domain>-Brain/SKILL.md` is regenerated from the current template (with your domain spliced in). The previous version is preserved as `SKILL.md.bak.YYYYMMDD-HHMMSS`. Brain content (interviews, references) lives elsewhere and is never touched.

It then prints the new version + recent CHANGELOG entries. Restart Claude Code afterwards so it picks up SKILL changes.

## Running the tests

```bash
bash tests/run-all.sh
```

Every test file lives in `tests/`. Shell-based, no external framework. They exercise `sync-templates.sh`, `scaffold.sh`, and `install.sh` against temporary workspaces.

## Maintainer workflow

### One-time setup after cloning

```bash
./scripts/install-hooks.sh
```

This symlinks `scripts/hooks/pre-commit` into `.git/hooks/`. From then on, every commit runs `sync-templates.sh --check` to make sure `templates/` is consistent with the canonical Billing-Brain SKILL. The hook is a no-op on machines that don't have `~/Claude/mh-billing-brain/`.

### Cutting a release

```bash
./scripts/release.sh "Short description of the change"
```

This one command does the full release flow:

1. Runs `sync-templates.sh` to regenerate `templates/` from `~/Claude/mh-billing-brain/`.
2. Runs the test suite. Aborts (and reverts) if anything fails.
3. Bumps the patch version in `VERSION`. Use `--minor` or `--major` to bump differently.
4. Prepends a dated entry to `CHANGELOG.md`.
5. Commits `templates/`, `VERSION`, and `CHANGELOG.md` in a single commit.
6. Pushes to `origin/main`.

Add `--dry-run` to do everything **except** the push (commit lands locally; you decide whether to push).

Consumers pick up the change with `./update.sh`.

### Slack notifications

`.github/workflows/notify-slack.yml` watches pushes to `main` and posts to **#product-brains** when the head commit looks like a release (message starts with `Release `). It's inert until the `SLACK_WEBHOOK_URL` repository secret is configured — until then it logs a notice in the Action run and exits cleanly. To set it up: create an Incoming Webhook for #product-brains in Slack, then add the URL as a secret named `SLACK_WEBHOOK_URL` under the repo's **Settings → Secrets and variables → Actions**.

### Just resyncing templates (no release)

If you only want to regenerate the templates without cutting a release:

```bash
./scripts/sync-templates.sh
git diff templates/
```

`sync-templates.sh` reads from `$BILLING_DIR` (default: `~/Claude/mh-billing-brain`). The pre-commit hook will refuse a commit if `templates/` drifts from that source.

### Propagating engine changes to existing brains (manually)

`update.sh` propagates automatically. If you want to run propagation by itself (e.g., on the maintainer's machine after a sync without a full release):

```bash
./scripts/propagate.sh             # update every installed <Domain>-Brain
./scripts/propagate.sh --dry-run   # preview only; write nothing
```

The script walks `~/.claude/skills/*-Brain/` (skipping `New-Brain`), regenerates each skill's `SKILL.md` from `templates/SKILL.md.tmpl` with the brain's domain spliced in, and backs up the previous version as `SKILL.md.bak.YYYYMMDD-HHMMSS`. It does **not** touch brain content (interviews, references) under `~/Claude/brains/<domain>/`.

If a PM has hand-edited their deployed `SKILL.md`, propagation will overwrite it — the backup is the only recovery path. (We may add an opt-out marker convention in a later version.)

## Design

See `docs/design-spec.md` for the full design — architecture, phase flow, file contents, error handling, v1/v2 split, success criteria.

## Compatibility with existing Billing brain

`/New-Brain` does not modify `mh-billing-brain/`, `~/Claude/brains/billing/`, or `~/.claude/skills/Billing-Brain/`. It produces new brains in the same shape so the Billing brain remains the reference example.
