# ENVI GitOps Task Stream

Generated: 2026-04-03 23:46:44Z (UTC)

## Current issues
- Active workflow is a generic GKE template with placeholder values and broken branch trigger (`"main"`).
- No iOS-focused CI policy for PR gatekeeping.
- No explicit IaC/deploy config for backend stack beyond `dataconnect/` + `.firebaserc`.
- Environment secrets/config strategy is undocumented.

## Target GitOps model
1. **Git as source of truth** for app + backend config.
2. **Environment promotion** (`dev -> staging -> prod`) via PRs/tags, not manual drift.
3. **Automated validation gates** (build, tests, lint, policy checks).
4. **Deploy safety** with approvals and rollback strategy.

## Mandatory tasks
- [ ] Create `.github/workflows/ios-ci.yml` (build + test + lint).
- [ ] Disable/remove `.github/workflows/google.yml` or move into `infra/legacy/` with trigger off.
- [ ] Add `firebase.json` and deployment doc for Data Connect.
- [ ] Add environment-specific config files (`.xcconfig` or equivalent) and secret injection strategy.
- [ ] Add branch protections: require status checks + PR review + no force push on main.
- [ ] Add release workflow for TestFlight (`workflow_dispatch` + tagged release path).
- [ ] Add observability bootstrap (Crashlytics/Sentry + release version correlation).
- [ ] Add incident runbook (`docs/ops/INCIDENT_RUNBOOK.md`).
- [ ] Add policy check to block committed secrets.
- [ ] Add deployment checklist for staging/prod cutovers.

## Nice-to-have GitOps tasks
- [ ] Terraform/OpenTofu for backend infra (if not fully managed by Firebase).
- [ ] Drift detection checks for backend config.
- [ ] Automated release notes from PR labels.
