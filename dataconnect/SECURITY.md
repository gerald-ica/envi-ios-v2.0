# Data Connect Security Policy

Last updated: 2026-04-04 UTC

## Production policy

- Do not expose Data Connect operations with `@auth(level: PUBLIC)` in production paths.
- Default all operations to `@auth(level: USER)` unless a documented exception is approved.
- Any exception requires:
  - a written risk justification,
  - rate-limit strategy,
  - abuse-monitoring plan.

## Current connector posture

- `dataconnect/example/queries.gql` now enforces `@auth(level: USER)` for all operations.
- Removed insecure annotations that previously justified broad exposure.

## Review checklist for new operations

1. Verify auth level is `USER` (or stricter).
2. Ensure operation only returns tenant-scoped data.
3. Confirm mutation paths cannot write cross-user records.
4. Add security review note in PR description.
