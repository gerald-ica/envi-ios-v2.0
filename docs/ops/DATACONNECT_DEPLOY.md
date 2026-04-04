# Data Connect Deploy Runbook

Last updated: 2026-04-04 UTC

## Scope

This runbook defines the deploy path for the Data Connect configuration in this repo:

- `firebase.json`
- `dataconnect/dataconnect.yaml`
- `dataconnect/schema/schema.gql`
- `dataconnect/example/connector.yaml`
- `dataconnect/seed_data.gql`

## Prerequisites

1. Firebase CLI installed and authenticated.
2. `.firebaserc` points to the expected project (`envi-by-informal-staging` for staging).
3. Required Google APIs enabled for Firebase Data Connect in the target project.

## Staging deploy flow

```bash
# from repository root
firebase use envi-by-informal-staging
firebase deploy --only dataconnect
```

## Verification

```bash
# verify CLI can read deployed Data Connect resources
firebase dataconnect:services:list
```

Then verify from iOS app (staging environment):

1. Launch with `ENVI_APP_ENV=staging`.
2. Exercise at least one query path expected to use Data Connect.
3. Confirm no fallback-to-mock path is used in logs for that feature.

## Production promotion checklist

1. Open PR with schema/connector changes.
2. Confirm staging deploy + smoke verification passed.
3. Tag release candidate commit.
4. Switch project and deploy:

```bash
firebase use <prod-project-id>
firebase deploy --only dataconnect
```

5. Record deploy timestamp and operator in release notes.
