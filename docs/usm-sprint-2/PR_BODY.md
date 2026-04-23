# USM Sprint 2 (iOS) — 4-screen onboarding + city search + loading + feature flags

## What's in this PR

Native iOS side of Sprint 2. Four-screen USM onboarding flow, Oracle city search, voice-translated loading state, and feature-flag gating. Entirely additive — no changes to the legacy onboarding code path.

### New code (13 files)

**`ENVI/Features/USM/Onboarding/`** — 7 files
- `USMOnboardingViewModel.swift` — `@MainActor @Observable` state machine. Step enum (`.name`, `.dateAndTime`, `.birthPlace`, `.currentLocation`, `.loading`), per-step `canContinue` validation, async `submit()` that calls `USMRecomputeClientProtocol.recompute()` and reverts to the prior step on failure. Also the authoritative home for `USMCity`, `CitySearchClientProtocol`, `USMRecomputeClientProtocol` and their request/response/error types so all USM code depends on one source of truth.
- `USMOnboardingCoordinator.swift` — root `View`; TabView with `.page(indexDisplayMode: .never)`, 4-segment progress bar, back button, and a continue button that flips to "Get Started" on the last step. Renders `USMOnboardingLoadingView()` during the async recompute.
- `USMOnboardingNameView.swift` — first/last name with `.textInputAutocapitalization(.words)`. Last name optional.
- `USMOnboardingDOBView.swift` — wheel DatePicker for birth date, toggleable hour+minute DatePicker when "I know my exact birth time" is on.
- `USMOnboardingBirthPlaceView.swift` — debounced text search against `CitySearchClientProtocol`, tappable result rows.
- `USMOnboardingCurrentLocationView.swift` — same shape as birth place plus a "Use My Current Location" path (`CLLocationManager.requestWhenInUseAuthorization()` → `reverseGeocode(lat:lon:)` → pre-fills the selected city). Falls back to manual search on denial or failure.
- `USMOnboardingLoadingView.swift` — pulsing circle + voice-translated card carousel cycling every 3 seconds across six approved strings. No banned terms (no "chart", "zodiac", "MBTI", "dasha").
- `USMOnboardingEntry.swift` — `@MainActor enum` entry point. `shouldUse` checks `FeatureFlags.shared.usmEnabled && .usmOnboardingEnabled`. `makeView(onComplete:)` ViewBuilder provides the DI point for SceneDelegate.

**`ENVI/Features/USM/Network/`** — 2 files
- `USMRecomputeClient.swift` — URLSession-backed `USMRecomputeClientProtocol`. POSTs to `/api/v1/users/{user_id}/self-model/recompute` with Bearer token, 90s timeout.
- `CitySearchClient.swift` — hits `/api/v1/cities/search?q=&limit=20`, decodes Oracle `CityResult`, maps to `USMCity` (splits combined `name` on `", "`). 10s timeout. `reverseGeocode(lat:lon:)` wraps `CLGeocoder().reverseGeocodeLocation()` with graceful nil-on-error fallback.

**`ENVITests/Core/USM/`** — 3 files
- `USMOnboardingCoordinatorTests.swift` — 8 `async` `@MainActor` tests: initial state, per-step validation, step ordering, forward/backward navigation, submit success, submit error revert.
- `CitySearchClientTests.swift` — 6 URLProtocol-stubbed tests: min-length guard (no network call), response parsing, 3-part / 2-part / 1-part name splitting, HTTP 500, transport error. `reverseGeocode` tests deferred (CLGeocoder not easily stubbable; manual sim test).
- `TestSupport/StubUSMRecomputeClient.swift` — shared `Result<Response, Error>`-wrapped test double for both coordinator tests and future USM test files.

### Modified (2 files)

- `ENVI/Core/Config/FeatureFlags.swift` — added `usmEnabled` and `usmOnboardingEnabled`. DEBUG default `true`, release default `false`. `applyRemoteConfigValues()` extended to read the matching Remote Config keys.
- `.firebaserc` — added `staging` and `production` aliases. `firebase use staging` now resolves.

## How the flow works at runtime

`USMOnboardingEntry.shouldUse` → `true` (flags on) → SceneDelegate calls `USMOnboardingEntry.makeView(onComplete:)` instead of the legacy onboarding container → user goes through name → DOB+time → birth place → current location → taps "Get Started" → view model transitions to `.loading` step → coordinator renders `USMOnboardingLoadingView()` while `USMRecomputeClient.recompute(...)` runs against Oracle → on success fires `onComplete()` (SceneDelegate hides the flow); on failure reverts to step 4 and surfaces `submitError`.

## CI

`.github/workflows/usm-ios-ci.yml` already covers `ENVI/Core/USM/**` and `ENVITests/Core/USM/**` — the new USM files sit under `Features/USM/**`, so the workflow filter needs updating when Gerald pushes (noted in `GERALD_NEXT_STEPS.md`).

## Dependencies

- Backend PR `USM Sprint 2: assembler + /recompute fan-out` must ship for this flow to actually produce a model. Without it, the recompute call returns 501 / placeholder.
- Sprint 1 Gerald-side work (KMS keyring + migration 011 apply) is still required — the backend's recompute encrypts with KMS, so if Sprint 1 isn't applied, recompute fails at the persist step.

## Review notes for Gerald

All 13 new files need pbxproj target membership — listed file by file in `GERALD_NEXT_STEPS.md` §4. SceneDelegate integration is a 2-line change — exact diff in §5. Everything else (Firebase staging alias, TestFlight internal push, merge order) is in the same doc.

No files outside `ENVI/Features/USM/**`, `ENVITests/Core/USM/**`, `docs/usm-sprint-2/**`, `FeatureFlags.swift`, and `.firebaserc` should be in the diff of this PR. If any other file appears, it's accidental — check before merging.

## Voice & tone guardrails

All user-visible strings in Loading + coordinator were drafted to match ENVI voice guidelines: no "chart", "zodiac", "MBTI", "dasha", "houses", "aspects", "rulers", "dignities". Instead: "reading", "mapping", "gathering", "finding your rhythm", "setting the tone", "writing your first page". These are approved copy from the Envi Voice Translator spec.
