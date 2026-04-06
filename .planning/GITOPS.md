# ENVI GitOps Task Stream

Generated: 2026-04-03 23:46:44Z (UTC)

## Resolved issues (as of roadmap completion)
- ~~Active workflow is a generic GKE template with placeholder values and broken branch trigger.~~ Replaced with `ios-ci.yml`.
- ~~No iOS-focused CI policy for PR gatekeeping.~~ iOS CI workflow gates PRs on build + test.
- ~~No explicit IaC/deploy config for backend stack.~~ `firebase.json` + Data Connect deploy runbook added.
- ~~Environment secrets/config strategy is undocumented.~~ Documented in `docs/ops/ENV_CONFIG_MATRIX.md`.

## Target GitOps model
1. **Git as source of truth** for app + backend config.
2. **Environment promotion** (`dev -> staging -> prod`) via PRs/tags, not manual drift.
3. **Automated validation gates** (build, tests, lint, policy checks).
4. **Deploy safety** with approvals and rollback strategy.

## Mandatory tasks
- [x] Create `.github/workflows/ios-ci.yml` (build + test + lint).
- [x] Disable/remove `.github/workflows/google.yml` or move into `infra/legacy/` with trigger off.
- [x] Add `firebase.json` and deployment doc for Data Connect.
- [x] Add environment-specific config files and secret injection strategy.
- [ ] Add branch protections: require status checks + PR review + no force push on main.
- [x] Add release workflow for TestFlight (`workflow_dispatch` + tagged release path).
- [x] Add observability bootstrap (Crashlytics via Firebase SDK + release version correlation).
- [x] Add incident runbook (`docs/ops/INCIDENT_RUNBOOK.md`).
- [x] Add policy check to block committed secrets (`scripts/check-secrets.sh` + CI integration).
- [x] Add deployment checklist for staging/prod cutovers (`docs/ops/DEPLOYMENT_CUTOVER_CHECKLIST.md`).

## Nice-to-have GitOps tasks
- [ ] Terraform/OpenTofu for backend infra (if not fully managed by Firebase).
- [ ] Drift detection checks for backend config.
- [ ] Automated release notes from PR labels.
