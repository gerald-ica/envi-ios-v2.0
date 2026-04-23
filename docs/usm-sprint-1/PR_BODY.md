# USM Sprint 1 — User Self-Model v1 (iOS)

iOS half of the User Self-Model foundation. Mirrors the Pydantic v2 schema in `ENVI-OUS-BRAIN` so a JSON payload round-trips byte-for-byte between the two clients.

## What this PR adds

**`ENVI/Core/USM/UserSelfModel.swift`**
- `UserSelfModel` + `Identity` + six block structs (`USMAstroBlock`, `USMPsychBlock`, `USMDynamicBlock`, `USMVisualBlock`, `USMPredictBlock`, `USMNeuroBlock`).
- All structs are `Codable`, `Sendable`, `Equatable` with explicit `CodingKeys` mapping camelCase ↔ snake_case.
- `JSONValue` Codable enum for arbitrary JSON fields (`planetary_positions`, `design_metadata`, `key_periods`) so the server can ship open-schema data without breaking iOS decode.
- `UserSelfModel.upgrade(from:fromVersion:toVersion:)` shim matching `schema.py::upgrade()` semantics.
- `USMError` with `upgradeFailed`, `cacheMissing`, `syncFailed`, `conflictResolutionFailed` cases.

**`ENVI/Core/USM/USMCache.swift`**
- `USMCacheRecord` — SwiftData `@Model` keyed on `userId + schemaVersion`, storing the encoded payload, `blockVersions` dict, SHA-256 of the payload, and `recomputedAt`.
- `USMCache` actor — serializes reads/writes against a dedicated `ModelContainer` rooted at `Application Support/USMCache.sqlite`. Ships with an `inMemory:` initializer for tests. Saves are no-ops when the payload hash matches existing record.

**`ENVI/Core/USM/USMSyncActor.swift`**
- `USMSyncActor` — serial actor with `pull` / `pushBlock` / `requestRecompute` / `currentModel` APIs. Cache-first reads kick off a background refresh; forced pulls de-dupe concurrent callers.
- Retry loop: 3 attempts, base delay 0.5s, cap 8s, ±20% jitter. Retries only on 5xx and transport errors — 4xx fails fast.
- `UserSelfModelWire` decodes the `UserSelfModelResponse` shape straight from the FastAPI route and projects it into `UserSelfModel`.
- Pluggable `USMSyncTransport` + `USMAuthTokenProvider` protocols so tests never hit the network or Firebase.

**`ENVITests/Core/USM/UserSelfModelTests.swift`**
- Schema round-trip (JSON keys are snake_case).
- Decodes the exact server payload shape, including `block_versions`.
- Same-version upgrade is a no-op; mismatched versions throw.
- Cache save/load/clear round-trip + no-op write on matching hash.
- Sync actor retries on 503 → 503 → 200 and returns the model.
- Sync actor fails fast on 401 (no retries burned).
- Sync actor exhausts after `maxAttempts` on repeated 500s.

**`.github/workflows/usm-ios-ci.yml`**
- `macos-14` + Xcode 16.0, runs `xcodebuild test -only-testing:ENVITests/UserSelfModelTests` on `feature/usm-**` pushes and USM-scoped PRs. Caches DerivedData keyed on `project.pbxproj` hash.

## How it slots into the existing app

Nothing reads from `USMCache` or `USMSyncActor` yet — Sprint 2 wires the assembler + profile screens. This PR is purely additive and does not touch any existing file outside `ENVI/Core/USM/`, `ENVITests/Core/USM/`, and `.github/workflows/`.

## Feature flag

Sprint 2 will gate on `FeatureFlags.usm.enabled`. Adding the flag is out of scope for this PR.

## Gerald's side

See `docs/usm-sprint-1/GERALD_NEXT_STEPS.md`. Short version:

1. Open `ENVI.xcodeproj`, add the three new Swift files + the XCTest file to the `ENVI` and `ENVITests` targets.
2. Run `xcodebuild test -scheme ENVI -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' -only-testing:ENVITests/UserSelfModelTests` locally and confirm green.
3. Push `feature/usm-1-schema` to trigger `usm-ios-ci.yml`.

## Sprint 1 task coverage

Closes tasks 1.5, 1.6, 1.7, and the iOS half of 1.8 from `Envi_Execution_Plan.md §3`.
