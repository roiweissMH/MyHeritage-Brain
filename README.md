# ⛔ Moved — this repo is deprecated

The MyHeritage Product Brains — the `/New-Brain` framework **and** every domain
brain — now live in ONE consolidated private org repo:

## → https://github.com/myhrtg/Product.myheritage-brains

`roiweissMH/MyHeritage-Brain` is **superseded as of 2026-06-03 (v1.0.0)** and is no
longer updated.

### If you cloned this repo and installed `/New-Brain` from here

Your already-installed skills keep working — only this repo's `update.sh` / `git pull`
are stale. Re-point to the new repo, one time:

```bash
git clone -b main https://github.com/myhrtg/Product.myheritage-brains.git ~/Product.myheritage-brains
cd ~/Product.myheritage-brains
./install.sh                          # reinstall /New-Brain from the new repo
./scripts/install-brain.sh billing    # redeploy Billing (or ./scripts/install-all-brains.sh)
rm -rf ~/mh-new-brain                 # retire this old clone
```

(The `-b main` flag is temporary until the new repo's default branch is switched to
`main`.) Questions: ping Roi.
