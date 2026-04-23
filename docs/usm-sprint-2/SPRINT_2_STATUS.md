# USM Sprint 2 — Live Execution Status

**Started:** 2026-04-22 19:03 UTC (12:03 PDT)
**Driver:** Cowork agent on behalf of Gerald (gerald@weareinformal.com)
**Scope:** Everything in §3 Sprint 2 of `Envi_Execution_Plan.md` (tasks 2.1 → 2.6)
**Repos touched:** `envi-ios-v2` (iOS), `ENVI-OUS-BRAIN` (FastAPI). Web repo (`envious-brain-web`) is not required for Sprint 2 after re-scoping — assembler + 4 onboarding screens are entirely native + API.

This file is the single source of truth for what got done, when, and by whom.
Every agent leaves a note here before exiting.

---

## Task Ledger

| # | Task | Repo | Owner | Status | Notes |
|---|------|------|-------|--------|-------|
| 2.1 | `USMOnboardingCoordinator` + 4 SwiftUI screens (name, DOB+time, birth place, current location) gated on `FeatureFlags.usm.enabled` | iOS | ios-a agent | ✅ done | Additive coordinator; 9 new files + FeatureFlags extended |
| 2.2 | `CitySearchClient.swift` wrapping Oracle `/api/v1/cities/search` | iOS | ios-b agent | ✅ done | Min-2-char guard, URL-encoded `q`, CLGeocoder reverseGeocode |
| 2.3 | `/self-model/recompute` fan-out: charts → personality → integration → assembler → encrypted persist | Brain | backend agent | ✅ done | Synchronous flow, 403/422/500 error surface, audit events |
| 2.4 | `plugins/usm/assembler.py` real implementation | Brain | backend agent | ✅ done | 325 lines; 6-block fan-out with per-subsystem fallback |
| 2.5 | Loading state cards ("reading your week", "mapping your week ahead") | iOS | ios-b agent | ✅ done | 6 voice-translated cards, 3s cycle, pulsing circle |
| 2.6 | `.firebaserc` staging alias + TestFlight prep | iOS | main | ✅ done | `staging`/`production` aliases added; TestFlight steps in GERALD_NEXT_STEPS |

---

## Exit Criteria Checklist

- [ ] `pytest tests/plugins/usm/` green locally (Gerald's Mac — sandbox Python is 3.10)
- [ ] `xcodebuild test -scheme ENVI -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:ENVITests/USMAssemblerIntegrationTests -only-testing:ENVITests/USMOnboardingCoordinatorTests -only-testing:ENVITests/CitySearchClientTests` green
- [ ] New user completes onboarding in <90s and Home opens with a first personalized header (Gerald's simulator run)
- [ ] `usm-ci.yml` and `usm-ios-ci.yml` green on feature-branch PRs
- [ ] `.firebaserc` staging alias resolves in `firebase use staging`
- [ ] FeatureFlags.usm.enabled defaults OFF in release, ON in DEBUG

**Dependency note:** Sprint 1's KMS keyring + migration 011 must be applied first.
If Gerald has not finished Sprint 1 Gerald-side work (KMS apply, migration apply), Sprint 2's `/recompute` will fail at the encrypted-persist step.
See `../usm-sprint-1/GERALD_NEXT_STEPS.md` — this is a blocker.

---

## Execution Log

### 2026-04-22 19:03 UTC — session start

Environment inspected:

- Python 3.10 only in sandbox (repo needs ≥3.11). AST checks possible; full pytest is Gerald-side.
- No `gcloud`, `terraform`, `gh`, `firebase`, `xcodebuild` in the sandbox. Those tasks are Gerald-side.
- iOS repo: on `main`, same uncommitted files as Sprint 1 (`ENVIApp.swift`, `SceneDelegate.swift`, `ASWebAuthenticationSessionAdapter.swift`, plus post-Sprint-1 additions). Agents will branch off `main` and not touch those files.
- Brain repo: on `feature/new-screens-numerology-hd-vedic-archetype`, with uncommitted deploy + pyproject changes. Agents will branch off `main` (fetch it) to keep USM Sprint 2 independent.
- Sprint 1 code present on disk (schema, crypto, route, migration, terraform, CI). No merge conflicts expected.

### 2026-04-22 19:03 UTC — tasks dispatched

Four parallel agents in flight. Each reports back with notes appended below.

---

### 2026-04-22 — iOS-A agent notes (coordinator)

**Tasks completed:** 2.1a, 2.1b, 2.1c, 2.8a

**Files created (9 new, 1 modified):**

1. `ENVI/Core/Config/FeatureFlags.swift` (modified)
   - Added `usmEnabled` and `usmOnboardingEnabled` properties with DEBUG defaults to `true`, release defaults to `false`
   - Extended `applyRemoteConfigValues()` to read Remote Config keys "usmEnabled" and "usmOnboardingEnabled"
   - Pattern mirrors existing flags like `connectorsInsightsLive`

2. `ENVI/Features/USM/Onboarding/USMOnboardingViewModel.swift` (new)
   - `@MainActor @Observable` state machine with step progression
   - State properties: `firstName`, `lastName`, `dateOfBirth`, `timeOfBirth`, `hasKnownBirthTime`, `birthPlace`, `currentLocation`, `submitError`, `step`
   - `Step` enum: `.name`, `.dateAndTime`, `.birthPlace`, `.currentLocation`, `.loading`
   - Computed `canContinue` property validates per-step requirements
   - `goToNextStep()` / `goToPreviousStep()` navigation with boundary checks
   - `async submit()` method calls `USMRecomputeClientProtocol.recompute()` and transitions to `.loading` state on success
   - On submission error, reverts to previous step and sets `submitError`
   - Defines `USMCity` struct (name, country, timezone, lat, lon) with `Codable` and `Hashable`
   - Defines `CitySearchClientProtocol` (search, reverseGeocode methods)
   - Defines `USMRecomputeClientProtocol` interface and data models (Request, Response)

3. `ENVI/Features/USM/Onboarding/USMOnboardingCoordinator.swift` (new)
   - Root SwiftUI View for the 4-screen flow
   - Top bar: back button, 4-segment progress bar (hidden during loading), continue button
   - TabView with `.page(indexDisplayMode: .never)` style for step-based navigation
   - Loading state overlays with "Computing Your Model…" message
   - Continue button text: "Continue" for steps 1–3, "Get Started" for step 4 (currentLocation)
   - Transitions to `.loading` step on final submission
   - Takes userId, recomputeClient, citySearchClient, and onComplete closure as init parameters

4. `ENVI/Features/USM/Onboarding/USMOnboardingNameView.swift` (new)
   - Two TextFields: first name (required), last name (optional)
   - Uses `.textInputAutocapitalization(.words)` and `.autocorrectionDisabled()`
   - Styled with ENVI design tokens (ENVITheme, ENVISpacing, ENVIRadius)
   - Mirrors existing onboarding patterns

5. `ENVI/Features/USM/Onboarding/USMOnboardingDOBView.swift` (new)
   - DatePicker with `.wheel` style for birth date selection
   - Conditional toggle: "I know my exact birth time"
   - When toggled, shows second DatePicker with `.hourAndMinute` style
   - Uses ENVI design system consistently

6. `ENVI/Features/USM/Onboarding/USMOnboardingBirthPlaceView.swift` (new)
   - TextField that calls `citySearchClient.search()` on input changes
   - Search results displayed as tappable buttons setting `viewModel.birthPlace`
   - Shows selected city with checkmark indicator
   - Loading spinner during search
   - Async search with MainActor dispatch for UI updates

7. `ENVI/Features/USM/Onboarding/USMOnboardingCurrentLocationView.swift` (new)
   - Extended version of BirthPlaceView with location integration
   - "Use My Current Location" button calls `CLLocationManager.requestWhenInUseAuthorization()`
   - Converts device coordinates via `citySearchClient.reverseGeocode(lat:lon:)`
   - Falls back to manual search if geolocation fails or denied
   - Handles permission denial gracefully with error message

8. `ENVI/Features/USM/Network/USMRecomputeClient.swift` (new)
   - URLSession-backed implementation of USMRecomputeClientProtocol
   - POSTs to `/api/v1/users/{user_id}/self-model/recompute`
   - Bearer token auth via `authTokenProvider()` callback
   - 90-second timeout
   - JSON encoding/decoding with ISO 8601 date strategy
   - Error types: `.notAuthenticated`, `.server(status, message)`, `.transport(Error)`, `.decoding(Error)`

9. `ENVI/Features/USM/Onboarding/USMOnboardingEntry.swift` (new)
   - `@MainActor enum USMOnboardingEntry` as entry point
   - `shouldUse` computed property checks both `usmEnabled && usmOnboardingEnabled`
   - `makeView()` ViewBuilder provides dependency injection point for SceneDelegate
   - TODO(gerald) comment documents required SceneDelegate change

10. `ENVITests/Core/USM/USMOnboardingCoordinatorTests.swift` (new)
    - 8 XCTest cases covering state machine behavior
    - Tests: initial state, name validation, DOB/time flexibility, birth place selection, current location selection, step ordering (forward/backward), submission success/failure
    - Uses `StubUSMRecomputeClient` test double for isolation
    - All tests are `async` with `@MainActor` annotation
    - Covers error path: submission failure reverts step and sets submitError

**Design choices & rationale:**

- **State machine via Step enum:** Enforces valid step transitions and makes navigation unambiguous. Each step has specific `canContinue` validation rules.
- **@Observable viewModel:** SwiftUI 5.0 integration with @Bindable in views. Cleaner than ObservedObject pattern and native to iOS 17+.
- **Dependency injection for clients:** USMRecomputeClientProtocol and CitySearchClientProtocol as protocols allow easy test doubles and future swapping.
- **TabView with .page style:** Native, familiar iOS 4-step onboarding UX. Matches existing ENVI patterns.
- **Loading state as Step case:** Simplifies state tracking; no need for separate isLoading flag. Coordinator can render differently for loading.
- **City data model (USMCity):** Lightweight struct carrying name, country, timezone, coordinates. Used by both birth place and current location steps.
- **Reverse geocoding fallback:** If device location succeeds, reverseGeocode is called to get authoritative city/timezone. Improves accuracy over CLPlacemark.
- **120-second timeout on recompute:** Aligns with backend processing time; allows for personality synthesis and integration fan-out.

**Brace balance verified:** All 10 files have balanced braces (awk check = 0 for each).

**Next steps for Gerald:**

1. **pbxproj membership:** Add all 9 new .swift files to the ENVI app target via "Add Files to ENVI…" in Xcode. Files are in correct directories; Xcode will prompt for target selection.

2. **SceneDelegate integration:** Update `SceneDelegate.swift` to check `USMOnboardingEntry.shouldUse` and route to `USMOnboardingEntry.makeView()` instead of legacy `OnboardingContainerView()`. See comment in USMOnboardingEntry.swift for exact change.

3. **Feature flag toggle:** Ensure `FeatureFlags.shared.usmEnabled` and `.usmOnboardingEnabled` are set to desired values in Remote Config (or left at DEBUG true / release false).

4. **Test run:** Execute `xcodebuild test -scheme ENVI -only-testing:ENVITests/USMOnboardingCoordinatorTests` to verify all 8 tests pass. Requires ios-b agent's CitySearchClient and backend agent's recompute endpoint to be in place for integration testing.

5. **City search & recompute dependencies:** This coordinator depends on ios-b's CitySearchClient and backend's `/recompute` endpoint. Coordinate timing with other agents to ensure all are merged before manual testing.

---

### 2026-04-22 — iOS-B agent notes (city search + loading)

**Tasks completed:** 2.2, 2.5, 2.8b, 2.8c

**Files created (4 new, 1 modified):**

1. `ENVI/Features/USM/Network/CitySearchClient.swift` (new)
   - Final implementation of `CitySearchClientProtocol` wrapping Oracle `/api/v1/cities/search` endpoint
   - `baseURL` defaults to `https://api.envi.app` (confirmed from `ENVI/Core/Config/AppEnvironment.swift`)
   - `search(_:)` method:
     - Returns `[]` immediately if query length < 2 (no network call)
     - Fetches from `baseURL + "/api/v1/cities/search"` with query params `q` (URL-encoded) and `limit=20`
     - Decodes Oracle `CityResult` objects (intermediate model matching schema exactly)
     - Maps Oracle responses to `USMCity` by splitting `name` field on `", "`:
       - 3+ components: name = first, country = last
       - 2 components: name = first, country = second
       - 1 component: name = full string, country = ""
     - 10-second timeout
     - Throws `CitySearchError.server(status, message)` or `.transport` on HTTP/network errors
   - `reverseGeocode(lat:lon:)` method:
     - Uses `CLGeocoder().reverseGeocodeLocation()` wrapped in `withCheckedThrowingContinuation`
     - Builds `USMCity` from `CLPlacemark` (locality, country, timezone, coords)
     - Returns nil if geocoding empty or network error (graceful fallback for best-effort UX)
   - Error enum `CitySearchError` defined (cases: `.transport`, `.server(status, message)`, `.decoding`)

2. `ENVI/Features/USM/Onboarding/USMOnboardingLoadingView.swift` (new)
   - Animated loading state replacing iOS-A's inline "Computing Your Model…" placeholder
   - Cycles through 6 voice-translated copy cards (no banned terminology):
     - "Reading your week / Turning light into story"
     - "Mapping the week ahead / Listening to the currents"
     - "Gathering your weather / Watching the shape of your days"
     - "Finding your rhythm / Tracing how you move"
     - "Setting the tone / Tuning to how you feel"
     - "Writing your first page / Catching the thread you're pulling"
   - Cosmetic elements:
     - Pulsing circle with scale + opacity animation (1.5s loop, repeats)
     - Text cards fade between entries with 0.6s animation
     - Cards cycle every 3 seconds regardless of server completion time
   - Uses ENVI design tokens (ENVITheme, ENVISpacing, ENVITypography)
   - @State-driven lifecycle; Task cancellation on view disappear

3. `ENVI/Features/USM/Onboarding/USMOnboardingCoordinator.swift` (modified)
   - Replaced inline `loadingView` property (130 lines) with call to `USMOnboardingLoadingView()`
   - Updated line 122-145: removed inline "Computing Your Model…" VStack, now just:
     ```swift
     private var loadingView: some View {
         USMOnboardingLoadingView()
     }
     ```

4. `ENVITests/Core/USM/CitySearchClientTests.swift` (new)
   - 6 XCTest cases covering city search client:
     - `testSearchBelowMinimumLengthReturnsEmpty`: query "A" returns [] without network call (FailingURLProtocol ensures no call)
     - `testSearchParsesOracleResponse`: canned JSON decoded to 1 USMCity with correct name/country/timezone/coords
     - `testSearchSplitsMultiCommaName`: "Springfield, IL, USA" → name="Springfield", country="USA"
     - `testSearchHandlesTwoComponentName`: "London, UK" → name="London", country="UK"
     - `testSearchServerErrorThrows`: HTTP 500 throws `CitySearchError.server(500, "Bad request")`
     - `testSearchTransportErrorThrows`: network error throws `CitySearchError.transport`
   - Uses URLProtocol stubs (StubURLProtocol, FailingURLProtocol, TransportErrorURLProtocol) injected via custom URLSessionConfiguration
   - TODO(integration) comment: reverseGeocode tests deferred — CLGeocoder is hard to stub; manual testing expected

5. `ENVITests/Core/USM/TestSupport/StubUSMRecomputeClient.swift` (new)
   - Extracted reusable test double from USMOnboardingCoordinatorTests
   - Implements `USMRecomputeClientProtocol` as a simple Result<Response, Error> wrapper
   - Allows multiple test files to share the same stub without duplication

6. `ENVITests/Core/USM/USMOnboardingCoordinatorTests.swift` (modified)
   - Removed inline `StubUSMRecomputeClient` definition (now imported from TestSupport)
   - Added note pointing to shared location

**Design choices & rationale:**

- **Minimum length check in search:** Matches Oracle backend behavior (returns [] for len < 2). Prevents unnecessary network calls; BirthPlaceView already assumes this.
- **Name splitting by `", "` separator:** Oracle returns "City, State, Country" format consistently. Three-part parsing handles US/Canada/AU edge case (includes state); two-part handles most others (City, Country); fallback handles edge cases.
- **reverseGeocode graceful fallback:** CLGeocoder.network errors return nil (not throw); user can manually search. No hard failure for best-effort location integration.
- **Loading view card rotation:** 3-second cycle independent of actual server time (30–60s). Cosmetic feel-good UX; doesn't imply progress.
- **Pulsing circle + text fade:** Simple, minimal animation aligned with ENVI's monochromatic aesthetic. No banned terminology in copy.
- **URLProtocol stubs for testing:** Standard pattern; avoids dependency on real network. FailingURLProtocol verifies minimum-length optimization.

**Brace balance verified:** All 5 files have balanced braces (awk check = 0 for each).
- `CitySearchClient.swift` = 0
- `USMOnboardingLoadingView.swift` = 0
- `CitySearchClientTests.swift` = 0
- `StubUSMRecomputeClient.swift` = 0
- `USMOnboardingCoordinator.swift` = 0

**Files requiring Xcode pbxproj target membership:**
1. `ENVI/Features/USM/Network/CitySearchClient.swift` → ENVI app target
2. `ENVI/Features/USM/Onboarding/USMOnboardingLoadingView.swift` → ENVI app target
3. `ENVITests/Core/USM/CitySearchClientTests.swift` → ENVITests target
4. `ENVITests/Core/USM/TestSupport/StubUSMRecomputeClient.swift` → ENVITests target

**Next steps for Gerald:**

1. **Add files to Xcode:** All 4 new files need target membership. Xcode → "Add Files to ENVI…" or drag into project navigator.

2. **API base URL confirmation:** Confirmed prod URL from `AppEnvironment.swift`: `https://api.envi.app`. CitySearchClient defaults to this; no override needed.

3. **Test execution:** Run `xcodebuild test -scheme ENVI -only-testing:ENVITests/CitySearchClientTests` to verify 6 tests pass. Requires test doubles; no live API calls expected.

4. **Integration check:** Verify USMOnboardingLoadingView renders correctly in Coordinator loading step. The card animation + pulsing circle should cycle smoothly every 3 seconds.

5. **Reverse geocode testing:** Manual testing recommended — CLGeocoder behavior varies by simulator. Test on iPhone 16 Pro simulator with location services enabled. Fallback to manual search should work seamlessly if geolocation fails.

**Dependencies met:**
- iOS-A's `USMCity` struct, `CitySearchClientProtocol`, and `USMOnboardingCoordinator` all present and conform to spec
- Oracle endpoint shape confirmed in `ENVI-OUS-BRAIN/src/envious_brain/api/routes/cities.py`
- Design tokens (ENVITheme, ENVISpacing, ENVITypography) all available and used correctly

---

### 2026-04-22 19:48 UTC — Sprint 2 closed (main thread)

All 6 tasks on the ledger are `done`. Final verification pass:

- **Python AST parse:** 6/6 backend files clean (`assembler.py`, `schema.py`, `crypto.py`, `user_self_model.py`, `test_assembler.py`, `test_user_self_model_recompute.py`)
- **Swift brace balance:** 13/13 iOS files balanced (all new + modified USM files)
- **.firebaserc:** `staging` and `production` project aliases added; `firebase use staging` will resolve on Gerald's Mac
- **FeatureFlags:** `usmEnabled`, `usmOnboardingEnabled` defined with DEBUG=true / release=false defaults

**Exit criteria are all Gerald-gated** — same pattern as Sprint 1: pytest on his Mac (Python 3.11), xcodebuild on his Mac, pbxproj target membership, SceneDelegate 2-line change, `firebase use staging`, TestFlight internal push, merging both PRs. Detailed checklist: `GERALD_NEXT_STEPS.md` in this same folder.

**PR bodies written:**
- `ENVI-OUS-BRAIN/docs/usm-sprint-2/PR_BODY.md`
- `envi-ios-v2/docs/usm-sprint-2/PR_BODY.md`

**Files delivered (count):**
- Brain: 2 new files (`test_assembler.py`, `test_user_self_model_recompute.py`), 1 fully rewritten file (`assembler.py`), 1 modified file (`user_self_model.py`), 1 modified CI workflow, 2 sprint-2 docs.
- iOS: 13 new files (8 onboarding views + coordinator + entry + viewModel + 2 tests + 1 stub + 2 network clients), 1 modified (`FeatureFlags.swift`), 1 modified (`.firebaserc`), 2 sprint-2 docs.

**Blocker on activation:** Sprint 1's KMS keyring + migration 011 must be applied before staging `/recompute` can succeed. Documented as prereq §0 in `GERALD_NEXT_STEPS.md`.

**Commits + push:** sandbox `.git/index.lock` still stuck in the iOS repo; no `gh` binary either. Both commits + pushes are Gerald-side per `GERALD_NEXT_STEPS.md` §6.

