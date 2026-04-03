# Testing & Swift Package

**Last updated:** 2026-04-03 UTC

## Swift Package (`Package.swift`)

- **Name:** `ENVI`
- **Platform:** iOS **17**
- **Product:** executable **`ENVI`** (path: `ENVI/`)
- **Resources:** `Resources/Fonts`, `Resources/Images` (processed)
- **Dependencies:**
  - SDWebImage (from 5.19.0)
  - Lottie (airbnb/lottie-spm, from 4.4.0)
  - RevenueCat + **RevenueCatUI** (purchases-ios-spm, from 5.0.0)

**Note:** Xcode project `ENVI.xcodeproj` may duplicate or reference this layout — maintain parity when bumping versions.

## Test target (`ENVITests`)

Path: `ENVITests/ENVITests.swift`

Current tests (sample):

- `Color` hex init
- `User.mock` fields / initials
- `ContentItem.mockFeed` non-empty
- `OnboardingViewModel` name validation / `canContinue`
- `AnalyticsData.mock` daily engagement count
- `ThemeManager.shared.mode` non-nil

**Coverage:** Smoke-level only; no UI tests or integration tests documented in-repo.

## Running tests

Prefer **Xcode** test action (**⌘U**) against the **`ENVI.xcodeproj`** scheme — that resolves iOS simulator destinations correctly.

`swift test` from the command line may fail on a Mac host if the package graph resolves the `ENVI` executable for macOS and hits dependency minimum-OS mismatches (Lottie / RevenueCat require newer macOS than the default executable baseline). If you need CLI tests, use `xcodebuild test` with an iOS Simulator destination, or adjust `Package.swift` platform constraints in a dedicated change.

---

Expand this page when adding CI commands or UI test targets.
