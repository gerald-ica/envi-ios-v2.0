# ENVI Deployment Cutover Checklist

Use this checklist for every release to TestFlight and the App Store.

## Pre-Release Validation

- [ ] All CI checks pass on `main` (iOS CI workflow green)
- [ ] Staging / development build smoke tested on a physical device
- [ ] RevenueCat offerings in dashboard match `PurchaseConstants` identifiers in code
- [ ] RevenueCat entitlement ID (`aura`) verified in dashboard and `EntitlementConstants`
- [ ] No `print()`, `debugPrint()`, or `#if DEBUG`-only logging leaking into Release scheme
- [ ] `Info.plist` `CFBundleShortVersionString` and `CFBundleVersion` updated (or workflow will set them)
- [ ] Privacy nutrition labels in App Store Connect match current data usage (especially after adding new SDKs)
- [ ] No API keys, tokens, or secrets hardcoded in source (run `scripts/check-secrets.sh` locally)
- [ ] Firebase `GoogleService-Info.plist` points to production project (not dev/staging)
- [ ] Data Connect schema deployed to production matches what the app expects
- [ ] Social OAuth redirect URIs and scopes match production configuration

## Deployment Steps

- [ ] Merge final PR to `main`
- [ ] Tag the release commit: `git tag v{version} && git push origin v{version}`
- [ ] Verify TestFlight Release workflow triggered (Actions tab)
- [ ] Confirm build uploaded to App Store Connect (check processing status)
- [ ] Add build to internal testing group in TestFlight
- [ ] Internal team completes smoke test on TestFlight build:
  - [ ] App launches without crash
  - [ ] Sign in / sign out works
  - [ ] Feed loads content
  - [ ] Publish flow completes to at least one social platform
  - [ ] Paywall displays and purchase flow initiates
- [ ] Submit build to external TestFlight group for beta review (if applicable)
- [ ] Once approved, submit for App Store review (or start phased rollout)

## Post-Deployment Monitoring

### 1-Hour Checkpoint
- [ ] Crashlytics: no new crash clusters above 0.1% crash-free threshold
- [ ] Firebase Data Connect: queries returning expected data
- [ ] RevenueCat: purchases processing (check RevenueCat dashboard > Activity)

### 24-Hour Checkpoint
- [ ] Crash-free users rate >= 99.5%
- [ ] No spike in user-reported issues
- [ ] Publishing success rate stable across social platforms
- [ ] App Store rating not trending downward
- [ ] KPI dashboards baseline recorded for this version

### 72-Hour Checkpoint (App Store releases)
- [ ] Phased rollout progressing (if enabled)
- [ ] No App Store review rejections for updates
- [ ] Release notes published on relevant channels

## Rollback Criteria

Initiate rollback if any of the following occur within 24 hours of release:

- Crash-free users drops below 98%
- Authentication flow broken for any sign-in provider
- Publishing fails for 2+ social platforms simultaneously
- Payment/subscription flow broken (RevenueCat errors)
- Data Connect returns errors for core queries (feed, profile)

## Rollback Steps

1. **Pause phased rollout** in App Store Connect (if App Store release)
2. **Remove broken build** from TestFlight testing groups
3. **Re-add previous stable build** to TestFlight groups
4. **If App Store**: submit previous build as a new version (expedited review)
5. **If backend change caused it**: revert Firebase deployment per `docs/ops/INCIDENT_RUNBOOK.md`
6. **Notify team** in Slack with incident details
7. **Create post-incident review** within 48 hours

## Required Secrets (GitHub Actions)

Verify these secrets are configured in the repository before first release:

| Secret | Purpose |
|--------|---------|
| `P12_CERTIFICATE_BASE64` | Distribution certificate |
| `P12_PASSWORD` | Certificate password |
| `PROVISIONING_PROFILE_BASE64` | App Store provisioning profile |
| `KEYCHAIN_PASSWORD` | Temporary keychain password |
| `ASC_KEY_ID` | App Store Connect API key ID |
| `ASC_ISSUER_ID` | App Store Connect API issuer ID |
| `ASC_PRIVATE_KEY` | App Store Connect API private key (`.p8` contents) |
