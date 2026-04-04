# Environment Config Matrix

Last updated: 2026-04-04 UTC

## Single source of truth

- Runtime environment comes from `ENVI/Core/Config/AppEnvironment.swift`.
- Primary key: `ENVI_APP_ENV` with values: `dev`, `staging`, `prod`.
- Optional API override: `ENVI_API_BASE_URL`.
- `APIClient` now resolves `baseURL` from `AppConfig.apiBaseURL`.

## Environment mapping

| Environment | `ENVI_APP_ENV` | Default API base URL | Owner | Notes |
|---|---|---|---|---|
| Development | `dev` | `https://api-dev.envi.app/v1` | iOS + Backend | Local feature work, non-production data |
| Staging | `staging` | `https://api-staging.envi.app/v1` | Backend | Pre-release validation, QA/UAT |
| Production | `prod` | `https://api.envi.app/v1` | Backend + Release owner | Live user traffic |

## Recommended CI and local setup

- CI PR validation should run with `ENVI_APP_ENV=staging`.
- Local development defaults to `dev` in DEBUG builds.
- Non-DEBUG builds default to `prod` unless explicitly overridden.

## Required secrets/config by environment

| Key | dev | staging | prod |
|---|---|---|---|
| `ENVI_APP_ENV` | `dev` | `staging` | `prod` |
| `ENVI_API_BASE_URL` (optional) | optional | optional | optional |
| RevenueCat API key | sandbox key | staging key | production key |
| Firebase project | dev project | staging project | production project |

## Promotion rules

1. `dev -> staging`: merge to `main` with passing CI.
2. `staging -> prod`: tagged release + explicit approval.
3. Config changes require PR review from iOS + backend owners.
