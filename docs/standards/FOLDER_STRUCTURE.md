# ENVI Folder Structure Standard

Last updated: 2026-04-03 UTC

## Current accepted top-level structure
- `ENVI/App`
- `ENVI/Core`
- `ENVI/Features`
- `ENVI/Components`
- `ENVI/Models`
- `ENVI/Navigation`
- `ENVI/Resources`

## Boundary rules
- `Features/*` may depend on `Core`, `Components`, `Models`, `Navigation`.
- `Core` must not import feature-specific UI.
- `Models` hold domain/UI model structs only; transport DTOs should move to networking/data layer.

## Recommended incremental structure hardening
- Introduce `ENVI/Data/Repositories` for backend/data providers.
- Introduce `ENVI/Core/Config` for env/feature flags.
- Move external service facades under `ENVI/Core/Networking/Services`.

## File placement rules
- New feature-specific screens go under `ENVI/Features/<FeatureName>/`.
- Shared reusable controls go in `ENVI/Components/`.
- Do not add orphan root-level Swift files (e.g., legacy manager files) without target ownership.

## Repo hygiene
- Add `.cache/`, `.cursor/`, `.vscode/`, and local tooling dirs to `.gitignore` if not intended for source control.
- Keep infra/deploy configs under explicit folders (`infra/`, `deploy/`, or `dataconnect/`) with docs.
