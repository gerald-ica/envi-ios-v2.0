# Legal pages — superseded by getenvi.ai/legal/*

Status as of 2026-05-12: the live, canonical legal pages are hosted at **getenvi.ai/legal/\***, not the GitHub Pages plan this README originally described. The HTML drafts in this folder are kept as the audit-time reference; they are NOT the source of the live site.

## Canonical live URLs

| Page | URL |
|---|---|
| Legal hub / index | https://getenvi.ai/legal |
| Privacy Policy | https://getenvi.ai/legal/privacypolicy |
| Terms of Service | https://getenvi.ai/legal/terms |
| Data Deletion | https://getenvi.ai/legal/data-deletion |

**Use these URLs everywhere a privacy / terms / data-deletion URL is required** — Google OAuth consent screen, App Store Connect App Privacy section, Facebook for Developers app dashboard, Apple Sign In Service ID configuration, in-app Settings → Legal links.

Notes on drift from the original audit drafts in this folder:
- Privacy moved from `/legal` to `/legal/privacypolicy` so `/legal` could become a hub page.
- All three live pages now use `gerald@weareinformal.com` as the contact email. The local drafts still reference `privacy@weareinformal.com` and `hello@weareinformal.com`; treat the live pages as source of truth.

## Audit-era drafts in this folder

| File | What it was for |
|---|---|
| `index.html` | First-pass Privacy Policy draft (May 11 audit). Now superseded by getenvi.ai/legal/privacypolicy. |
| `terms/index.html` | First-pass Terms draft. Now superseded by getenvi.ai/legal/terms. |
| `data-deletion/index.html` | First-pass Data Deletion draft. Now superseded by getenvi.ai/legal/data-deletion. |

These remain in the repo as the audit-time historical reference. If you ever need to re-publish or self-host, they're a starting point.

## Legacy: ica-agency.github.io/envi-privacy

The original audit plan was to deploy to `ica-agency/envi-privacy` on GitHub Pages. That repo still exists with the Feb 2026 placeholder ("browser-side Instagram analytics demo"). Since getenvi.ai supersedes it, no one should be linking to `ica-agency.github.io/envi-privacy` anywhere. Optional cleanup: redirect or unpublish the GH Pages site so search engines stop indexing the stale content.

## What this folder is NOT

- NOT the deploy source for the live site
- NOT a place to edit copy if you want to change the live pages
- NOT a fallback / mirror — out of sync with live

To change actual legal copy, edit wherever getenvi.ai is hosted (the user's Next.js site / Vercel / whatever serves getenvi.ai), not these files.
