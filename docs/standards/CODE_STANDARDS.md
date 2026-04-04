# ENVI Code Standards

Last updated: 2026-04-03 UTC

## Swift architecture standards
- Use **Coordinator pattern** for navigation ownership.
- Keep feature logic in ViewModels; avoid direct networking in Views.
- New data dependencies must go through repository protocols.
- Keep singletons limited to composition roots and globally shared subsystems.

## Quality standards
- Every non-trivial feature change requires:
  1. Unit tests for ViewModel/data mapping logic.
  2. At least one integration test for primary path when feasible.
  3. Error-state and empty-state behavior, not just happy path.
- Remove mock data from critical user paths before marking feature as complete.

## Security standards
- No hardcoded secrets in source.
- Use environment-specific configuration and injected secrets in CI.
- Personal data usage must be documented and consented.

## Git standards
- PR required for `main`.
- Conventional commit style recommended (`feat:`, `fix:`, `docs:` etc.).
- CI checks must pass before merge.

## Documentation standards
- Update `docs/WIKI_CHANGELOG.md` for meaningful doc or architectural changes.
- Keep `.planning/` roadmap and execution backlog current as phases move.
