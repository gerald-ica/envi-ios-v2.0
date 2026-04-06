# ENVI Incident Runbook

## Severity Levels

| Level | Description | Response Time | Examples |
|-------|-------------|---------------|----------|
| **P0** | Complete outage, all users affected | 15 min acknowledge, 1h mitigate | App crash on launch, Firebase Auth down, Data Connect unreachable |
| **P1** | Major feature broken, significant user impact | 30 min acknowledge, 4h mitigate | Publishing fails for all platforms, feed not loading, payment processing broken |
| **P2** | Partial degradation, workaround exists | 2h acknowledge, 24h mitigate | Single social platform publishing fails, analytics delayed, image upload slow |
| **P3** | Minor issue, cosmetic or low impact | 24h acknowledge, 1 week fix | UI glitch, non-critical notification failure, minor layout issue |

## On-Call Expectations

- On-call engineer monitors alerts during assigned rotation
- Acknowledge P0/P1 alerts within SLA window
- If unable to resolve within 30 minutes, escalate per the escalation path below
- Document all actions taken during the incident in the incident channel

## Communication Protocol

1. **P0/P1**: Create a dedicated Slack channel `#incident-YYYY-MM-DD-brief-desc`
2. **Notify**: Engineering lead, product owner, and on-call engineer
3. **Status updates**: Every 30 min for P0, every 2h for P1
4. **External comms**: If user-facing impact exceeds 1h, draft a status update for in-app or social channels
5. **Resolution**: Post summary in the incident channel and tag stakeholders

## Common Incidents

### API / Firebase Outage

**Symptoms**: Network errors across the app, empty feeds, failed requests

**Diagnosis**:
1. Check [Firebase Status Dashboard](https://status.firebase.google.com/)
2. Check Firebase Console > Project > Usage for quota exhaustion
3. Review Cloud Functions logs in Firebase Console > Functions > Logs
4. Verify Data Connect service status in Firebase Console > Data Connect

**Mitigation**:
- If Firebase-wide outage: nothing to do but wait; confirm fallback/offline caching is working
- If quota exhaustion: increase quotas in Google Cloud Console > IAM & Admin > Quotas
- If function errors: roll back to previous function deployment with `firebase functions:delete <fn> && firebase deploy --only functions`

### Auth Failures

**Symptoms**: Users unable to sign in, token refresh errors, 401 responses

**Diagnosis**:
1. Firebase Console > Authentication > check for disabled providers
2. Check if Apple Sign-In service ID and key are still valid in Apple Developer Console
3. Look for token expiry issues in Crashlytics logs (search for `AuthErrorCode`)
4. Verify Firebase Auth emulator is not accidentally targeted in production build

**Mitigation**:
- Expired Apple Sign-In key: regenerate in Apple Developer Console, update Firebase Auth config
- Provider disabled: re-enable in Firebase Console > Authentication > Sign-in method
- Token issues: users can force-logout and re-authenticate; push a hotfix if the refresh logic is broken

### Publish Failures (Social OAuth)

**Symptoms**: Posts fail to publish to Instagram, TikTok, X, or Threads

**Diagnosis**:
1. Check social platform API status pages
2. Verify OAuth tokens have not expired (token lifetime varies by platform)
3. Review publish error responses in app logs / Crashlytics for specific error codes
4. Check if API scopes changed (platform may revoke scopes without notice)

**Mitigation**:
- Expired tokens: prompt user to re-authenticate the affected social account
- Scope revocation: update OAuth scope requests per `docs/ops/OAUTH_SCOPE_POLICY.md`, redeploy
- Platform outage: queue failed publishes for retry; notify user of delay
- Rate limit hit: implement exponential backoff; surface "try again later" to user

### Crash Spike

**Symptoms**: Crashlytics alerts, App Store reviews mentioning crashes, spike in crash-free user % drop

**Diagnosis**:
1. Firebase Console > Crashlytics > filter by version and timeframe
2. Correlate crash spike with most recent TestFlight or App Store release
3. Identify top crash signature and affected OS versions
4. Check if crash is in ENVI code or a third-party SDK (RevenueCat, Firebase, social SDKs)

**Mitigation**:
- If crash is in new release: halt phased rollout (see Rollback below)
- If crash is in third-party SDK: check for SDK updates, pin previous version in Package.swift
- If crash is device/OS specific: add guard code, push hotfix via TestFlight fast-track

### Data Connect Issues

**Symptoms**: Queries return stale data, mutations fail, schema errors in logs

**Diagnosis**:
1. Firebase Console > Data Connect > check service health
2. Compare deployed schema with local schema files for drift
3. Check Data Connect connector generation logs for type mismatches
4. Verify Cloud SQL instance (underlying Postgres) is healthy in Google Cloud Console

**Mitigation**:
- Schema drift: redeploy schema with `firebase deploy --only dataconnect`
- Cloud SQL down: check Google Cloud Console > SQL > instance status; restart if needed
- Query errors: review generated connector code, regenerate if schema changed

## Rollback Procedures

### iOS App (TestFlight / App Store)

**TestFlight Build Revert**:
1. App Store Connect > TestFlight > select the previous stable build
2. Click "Add to Group" for internal/external testers
3. Remove the broken build from the testing group
4. If external review is needed, submit the previous build for review

**App Store Phased Rollout Pause**:
1. App Store Connect > App Store > the active version
2. Click "Pause Phased Release" to stop rollout to new users
3. If critical: click "Release Update to All Users" on the previous version (requires a new submission with the old build)
4. Prepare a hotfix build and submit via the TestFlight Release workflow

**Note**: App Store rollbacks are slow. Prefer pushing a hotfix forward over reverting.

### Backend (Firebase)

**Cloud Functions Rollback**:
```bash
# List previous function versions
gcloud functions list --project=<project-id>

# Redeploy from a previous commit
git checkout <previous-commit>
firebase deploy --only functions
git checkout main
```

**Data Connect Schema Revert**:
```bash
# Checkout the last known-good schema
git checkout <previous-commit> -- dataconnect/

# Redeploy
firebase deploy --only dataconnect

# Restore working directory
git checkout main -- dataconnect/
```

**Firestore Security Rules Rollback**:
```bash
# Deploy previous rules
git checkout <previous-commit> -- firestore.rules
firebase deploy --only firestore:rules
git checkout main -- firestore.rules
```

## Post-Incident Review Template

Complete within 48 hours of resolution for P0/P1, 1 week for P2.

```markdown
## Post-Incident Review

**Date**: YYYY-MM-DD
**Severity**: P0 / P1 / P2
**Duration**: start time - end time (total minutes)
**Impact**: number of users affected, feature(s) impacted

### Timeline
- HH:MM - Issue detected (how: alert / user report / monitoring)
- HH:MM - Acknowledged by <name>
- HH:MM - Root cause identified
- HH:MM - Mitigation applied
- HH:MM - Fully resolved

### Root Cause
<What actually broke and why>

### What Went Well
- <detection speed, response coordination, etc.>

### What Could Be Improved
- <gaps in monitoring, slow escalation, missing runbook, etc.>

### Action Items
- [ ] <preventive measure> - Owner: <name> - Due: <date>
- [ ] <monitoring improvement> - Owner: <name> - Due: <date>
- [ ] <runbook update> - Owner: <name> - Due: <date>
```

## Escalation Paths

| Step | Who | When |
|------|-----|------|
| 1 | On-call engineer | Immediately on alert |
| 2 | Engineering lead | If not mitigated in 30 min (P0) or 2h (P1) |
| 3 | CTO / Product owner | If user-facing impact exceeds 1h or data loss risk |
| 4 | Third-party support | If root cause is in Firebase, RevenueCat, or social platform API |

### Third-Party Support Contacts
- **Firebase**: [Firebase Support](https://firebase.google.com/support) (requires Google Cloud support plan for P0/P1)
- **RevenueCat**: [RevenueCat Support](https://www.revenuecat.com/support) or dashboard chat
- **Apple (App Store Connect)**: [Apple Developer Contact](https://developer.apple.com/contact/)
