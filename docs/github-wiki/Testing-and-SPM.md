# Testing & Swift Package

**Last updated:** 2026-04-23 UTC

## Swift Package (`Package.swift`)

- **Name:** `ENVI`
- **Platform:** iOS **26**
- **Product:** library **`ENVI`** (path: `ENVI/`)
- **Resources:** `Resources/Fonts`, `Resources/Images` (processed)
- **Dependencies:**
  - SDWebImage (from 5.19.0)
  - Lottie (airbnb/lottie-spm, from 4.4.0)
  - RevenueCat + **RevenueCatUI** (purchases-ios-spm, from 5.0.0)
  - FirebaseAuth / Analytics / Crashlytics / AppCheck / Firestore / RemoteConfig / Core
  - GoogleSignIn

**Note:** The installable iOS app lives in `ENVI.xcodeproj`. `Package.swift` is intentionally non-runnable and exists for code organization, dependency resolution, and tests.

## Test target (`ENVITests`)

Path: `ENVITests/`

Current coverage includes:

- Auth and OAuth broker flows
- Template ranking, matching, and catalog actions
- For You / Gallery behavior
- Analytics / profile / publishing view models
- Connector adapters (TikTok, X, LinkedIn)
- USM schema, cache, sync, onboarding coordinator, and city search
- Performance smoke tests around the template pipeline

## Running tests

Prefer **Xcode** test action (**⌘U**) against the **`ENVI`** app scheme from `ENVI.xcodeproj`.

For CLI parity with GitHub Actions, use:

```bash
xcodebuild test \
  -scheme ENVI \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO
```

`swift test` from the command line may fail on a Mac host if the package graph resolves the `ENVI` library in a way that doesn't match the installable app target's runtime assumptions. Use it as a lightweight package check, not as a substitute for simulator CI.

## CI workflows

- **`iOS CI`** — full simulator build + test for pull requests to `main`
- **`USM iOS CI`** — feature-branch simulator validation used during the USM rollout

---

Expand this page when adding CI commands or UI test targets.
