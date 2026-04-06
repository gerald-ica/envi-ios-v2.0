# OAuth Scope and Token Policy

Last updated: 2026-04-03 UTC

## Purpose

Define minimum OAuth scope, token handling, and rotation requirements for social publishing integrations.

## Scope Baseline

- Only request scopes required for current product capabilities.
- Stage rollouts by feature flag and expand scopes only when a reviewed feature requires it.
- Keep provider scope mappings in backend configuration, not in client code.

## Current ENVI Integration Targets

- Instagram:
  - `instagram_business_basic`
  - `instagram_business_content_publish`
  - `pages_show_list` (only if required by provider bridge)
- TikTok, YouTube, X, Threads, LinkedIn:
  - Start with publish and profile-read only.
  - Defer analytics-management scopes until analytics ingestion is fully enabled.

## Token Handling Rules

- Access and refresh tokens are stored server-side only.
- iOS receives connection metadata (account handle, status, timestamps) and never raw provider tokens.
- Encrypt tokens at rest and rotate encryption keys by environment on a fixed cadence.
- Revoke provider sessions on explicit disconnect and on account deletion.

## Operational Checklist

For any new scope request:

1. Create PR with:
   - user-facing feature justification,
   - exact provider scopes being added,
   - rollback plan.
2. Security review approval required before merge.
3. Update integration tests for connect, refresh, publish, revoke.
4. Update release notes and customer-facing permissions disclosure.

## Audit Cadence

- Monthly scope audit across all enabled providers.
- Remove unused scopes within one release cycle.
- Track scope usage metrics and failed permission prompts in telemetry.
