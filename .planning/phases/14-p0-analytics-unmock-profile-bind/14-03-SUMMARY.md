# Phase 14 Plan 03: Profile User Bind Summary

**ProfileViewModel now hydrates from the real Firebase Auth user; User.mock is confined to Preview/Debug paths; loading + error states visible in ProfileView.**

## Accomplishments
- Removed `User.mock` from `ProfileViewModel`'s production-reachable default. Changed `var user = User.mock` → `var user: User?` (optional, nil-init).
- Added `@MainActor func loadProfile() async` that pulls the current user from `AuthManager.shared.currentUser()`, assigns it, then runs `loadConnections()`.
- Added `isLoadingProfile: Bool` and `profileLoadError: String?` observable state.
- Wired `ProfileView` with a `.task { await viewModel.loadProfile() }` plus three rendering states: (a) profile UI when `user != nil`, (b) `ProgressView` + "Loading profile…" when loading, (c) error banner with Retry button when `profileLoadError != nil`. Never falls back to `User.mock` silently (audit rule).
- Added `ENVI/Core/Auth/AuthManager+CurrentUser.swift` — thin bridge mapping FirebaseAuth.User → domain `User` (Task 1 option (c), see Decisions).
- Retained `User.mock` via `#if DEBUG` `ProfileViewModel.preview()` helper for SwiftUI previews only.
- Added `ENVITests/ProfileViewModelTests.swift` with 2 tests (both passing):
  - `testDefaultStateIsEmpty`
  - `testPreviewHelperInjectsMock`
- Verified full Debug build succeeds on iPhone 17 Pro.
- Verified all 9 pinned XCTests pass (7 from 14-02 + 2 from 14-03).

## Files Created/Modified
- `ENVI/Features/Profile/ProfileViewModel.swift` — removed mock default, added load/error state and preview helper
- `ENVI/Features/Profile/ProfileView.swift` — `.task` hydration + loading/error UI; `profileHeader` / `statsSection` now take `User` as a parameter
- `ENVI/Core/Auth/AuthManager+CurrentUser.swift` — **new** bridge extension (`currentUser() -> User?`)
- `ENVITests/ProfileViewModelTests.swift` — **new** 2-test suite
- `project.yml` — added `ProfileViewModelTests.swift` to the `ENVITests` bundle sources
- `ENVI.xcodeproj/project.pbxproj` — regenerated via xcodegen

## Decisions Made
- **Task 1 Branch (c) — added a bridge extension.** Surveyed `AuthManager.swift`: no `currentUser: User?` property, no `getCurrentUser() async throws -> User` method. Only raw `FirebaseAuth.User` via `Auth.auth().currentUser`. Created `AuthManager+CurrentUser.swift` (extension, not mutation) exposing `currentUser() -> User?`. Deliberately partial mapping: uid/displayName/email/photoURL → domain fields; no Firestore round-trip here; connectedPlatforms / stats remain the responsibility of other services.
- **Optional `User?` rather than fallback mock.** Per the v1.2 audit rule: silent mock fallback is the root-cause misleading behavior. On error or signed-out state, view shows a proper empty/error state with Retry.
- **`handle` derivation**: `"@" + email.prefix(before: "@")` when email is present; otherwise `@user`. Firebase Auth doesn't carry a username, and Firestore profile lookup is out of 14-03 scope. Handle will be upgraded in a later phase once profile-fetch repo lands.
- **Preview helper**: annotated `@MainActor` because `loadConnections()` is `@MainActor`. Keeps call sites typed correctly.
- **Did NOT refactor `AccountRepository`** into a user-fetch repo. The plan was explicit about not creating a new UserRepository. Bridge extension was the minimal path.

## Issues Encountered
- First build attempt failed because `preview()` was not `@MainActor`-annotated and called `loadConnections()`. Fixed by adding `@MainActor` to the helper.
- First build attempt also failed transiently because the new `AuthManager+CurrentUser.swift` wasn't yet in the pbxproj; `xcodegen generate` picked it up on the next pass.

## Next Step
Phase 14 complete. Roll-up `.planning/phases/14-p0-analytics-unmock-profile-bind/SUMMARY.md` will summarize all three plans, mark v1.1 STATE blocker #7 as RESOLVED (2026-04-17), and tick the plan checkboxes in ROADMAP + STATE.
