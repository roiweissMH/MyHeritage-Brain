# ⛔ Moved — this repo is deprecated

The MyHeritage Product Brains — the `/New-Brain` framework **and** every domain
brain — now live in ONE consolidated private org repo:

## → https://github.com/myhrtg/Product.myheritage-brains

`roiweissMH/MyHeritage-Brain` is **superseded as of 2026-06-03 (v1.0.0)** and is no
longer updated (archived read-only).

### If you cloned this repo and installed `/New-Brain` from here

Your already-installed skills keep working — only this repo's `update.sh` / `git pull`
are stale. Re-point to the new repo:

**Step 1 — install from the new repo.** Paste all three lines together (they run top
to bottom):

```bash
git clone -b main https://github.com/myhrtg/Product.myheritage-brains.git ~/Product.myheritage-brains
cd ~/Product.myheritage-brains
./install.sh && ./scripts/install-brain.sh billing
```

Then **restart Claude Code** and confirm `/New-Brain` and `/Billing-Brain` work.

**Step 2 — optional cleanup.** The old clone is harmless to keep — nothing depends on
it once Step 1 is done. If you'd rather remove it, first make sure it holds no
un-pushed work (the old model kept brains as local folders under `brains/`), then
delete it:

```bash
cd ~/mh-new-brain && git status     # confirm nothing un-committed / un-pushed
rm -rf ~/mh-new-brain
```

(The `-b main` flag is temporary until the new repo's default branch is switched to
`main`.) Questions: ping Roi.
