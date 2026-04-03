# How to publish this documentation to GitHub Wiki

GitHub Wikis are a **separate git repository** from the main repo.

**Repository:** `https://github.com/gerald-ica/envi-ios-v2.0`  
**Wiki clone URL:** `https://github.com/gerald-ica/envi-ios-v2.0.wiki.git`

## Steps

1. Enable the wiki for the repo (GitHub → **Settings** → **Features** → **Wikis**).
2. Clone the wiki (empty on first use you may need to create the Home page once in the UI, or push initial commit):

```bash
cd /tmp
git clone https://github.com/gerald-ica/envi-ios-v2.0.wiki.git envi-wiki
cd envi-wiki
```

3. Copy all `*.md` files from this repo’s `docs/github-wiki/` into the wiki clone root (same filenames). Include `_Sidebar.md`.
4. Commit and push:

```bash
git add -A
git commit -m "Sync wiki from envi-ios-v2.0 docs (see main repo docs/WIKI_CHANGELOG.md)"
git push origin master
```

> GitHub may use `master` or `main` as the default branch for wikis; use `git branch -a` after clone.

5. Record the sync in **`docs/WIKI_CHANGELOG.md`** in the main repo with date/time.

## Naming

- `Home.md` becomes the wiki home page.
- Other pages: use the same title as the filename without `.md` in the wiki URL (GitHub normalizes spaces: `User-Flows` → `User-Flows` in URL).

**Last documented sync procedure update:** 2026-04-03 UTC.
