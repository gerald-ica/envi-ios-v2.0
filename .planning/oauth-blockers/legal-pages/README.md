# Legal pages — deploy these to ica-agency/envi-privacy

The current Privacy page at https://ica-agency.github.io/envi-privacy/ is a stale placeholder ("browser-side Instagram analytics demo", dated 2026-02-07). The Chrome survey confirmed it doesn't cover any of ENVI's actual data categories — it would block App Review by itself.

These three drafts replace it with submission-ready content.

## Files

| Source | Deploy to | Final URL |
|---|---|---|
| `index.html` | repo root (replace existing) | https://ica-agency.github.io/envi-privacy/ |
| `terms/index.html` | new dir `terms/` | https://ica-agency.github.io/envi-privacy/terms/ |
| `data-deletion/index.html` | new dir `data-deletion/` | https://ica-agency.github.io/envi-privacy/data-deletion/ |

## Deploy via GitHub web UI (~5 min)

1. Go to https://github.com/ica-agency/envi-privacy
2. Click the existing `index.html` → ✏️ pencil → paste the contents of `legal-pages/index.html`
3. Commit message: `Replace placeholder with full ENVI Privacy Policy`
4. Click **Add file → Create new file** → name it `terms/index.html` → paste contents of `legal-pages/terms/index.html` → commit
5. Same for `data-deletion/index.html`
6. Go to **Settings → Pages** and confirm the source is `main` branch + `/` (root) — should already be set
7. GitHub Pages will rebuild in 30–90s; verify the three URLs return 200 with the new content

## Deploy via clone + push (~10 min)

```bash
gh repo clone ica-agency/envi-privacy ~/envi-privacy
cd ~/envi-privacy
cp /Users/wendyly/Documents/envi-ios-v2/.planning/oauth-blockers/legal-pages/index.html ./
mkdir -p terms data-deletion
cp /Users/wendyly/Documents/envi-ios-v2/.planning/oauth-blockers/legal-pages/terms/index.html ./terms/
cp /Users/wendyly/Documents/envi-ios-v2/.planning/oauth-blockers/legal-pages/data-deletion/index.html ./data-deletion/
git add . && git commit -m "Full ENVI Privacy + Terms + Data Deletion"
git push
```

## After deploy

Once live, the FB dashboard and Apple Service IDs need these URLs entered:

- **FB parent app 1422291482707790 → Settings → Basic**:
  - Privacy Policy URL: `https://ica-agency.github.io/envi-privacy/` (already set — no change needed)
  - Terms of Service URL: `https://ica-agency.github.io/envi-privacy/terms/` ← NEW
  - User Data Deletion: select "Data Deletion Instructions URL" and set to `https://ica-agency.github.io/envi-privacy/data-deletion/` ← NEW

- **Apple Sign In Service ID** (services list at developer.apple.com): same Privacy + Terms URLs

A follow-up Chrome agent can drive the FB-side dashboard updates once the URLs return 200.

## What I drafted vs what needs your eyes

I wrote with reasonable defaults for a Las Vegas-based content-agency SaaS. Things you should sanity-check before publishing:

- **Email addresses**: I used `privacy@weareinformal.com` and `hello@weareinformal.com`. If those aren't set up, either configure them or substitute with `gerald@weareinformal.com` / `wendy@weareinformal.com` (the business contacts on file).
- **Postal address**: I wrote "Las Vegas, Nevada, USA" without a street. Add a real PO box / suite if you want the policy to be more enforceable in CCPA/GDPR contexts.
- **Governing law (Terms)**: Nevada with venue Clark County — change if your entity is registered elsewhere.
- **Subscription tier names** (Aura / Aura Pro / Power) — match the audit + RevenueCat config.
- **The "we don't sell data" claim** is real for the current architecture but binding — confirm it stays true if any future analytics partnerships are added.
- **Data-retention windows** (30d backups, 90d BigQuery raw) match what the audit/observability work documented; if they change, update §5 to match.
