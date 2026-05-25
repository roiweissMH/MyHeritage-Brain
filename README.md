# MH New-Brain

Claude Code meta-skill that bootstraps a new domain brain (structurally identical to `mh-billing-brain`) in one guided Claude Code session.

This is the bootstrapper for the broader **MH Product Brain** initiative. Use it to start a brain for any MyHeritage Product domain.

## What's in the repo

```
mh-new-brain/
├── README.md                ← this file
├── SKILL.md                 ← /New-Brain skill definition (5-phase guided bootstrap)
├── install.sh               ← deploys SKILL.md to ~/.claude/skills/New-Brain/
├── scripts/
│   ├── sync-templates.sh    ← regenerates templates/ from mh-billing-brain (maintainer-run)
│   └── scaffold.sh          ← writes a new mh-<domain>-brain/ repo from templates + PM answers
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
git clone <mh-new-brain-repo-url> mh-new-brain
cd mh-new-brain
./install.sh
```

Then restart Claude Code so it discovers `/New-Brain`. The first time you run it, it'll guide you through Phase 0-5 above.

By default, `install.sh` **copies** files (safe — your clone can move or be deleted without breaking the install). Use `./install.sh --symlink` if you want edits to the deployed file to flow back into your clone.

## Update

```bash
cd mh-new-brain
git pull
./install.sh
```

## Running the tests

```bash
bash tests/run-all.sh
```

Every test file lives in `tests/`. Shell-based, no external framework. They exercise `sync-templates.sh`, `scaffold.sh`, and `install.sh` against temporary workspaces.

## Updating templates after a Billing-Brain change

`/New-Brain` produces brains in the same shape as the canonical `mh-billing-brain` repo. If `mh-billing-brain/SKILL.md` (or any other reference file) changes, regenerate the templates:

```bash
bash scripts/sync-templates.sh
git diff templates/
# Review the diff; if it's correct, commit it.
git add templates/ && git commit -m "Sync templates with mh-billing-brain"
```

`sync-templates.sh` reads from `$BILLING_DIR` (default: `~/Claude/mh-billing-brain`). Override with the env var if the canonical repo lives elsewhere.

## Design

See `docs/design-spec.md` for the full design — architecture, phase flow, file contents, error handling, v1/v2 split, success criteria.

## Compatibility with existing Billing brain

`/New-Brain` does not modify `mh-billing-brain/`, `~/Claude/brains/billing/`, or `~/.claude/skills/Billing-Brain/`. It produces new brains in the same shape so the Billing brain remains the reference example.
