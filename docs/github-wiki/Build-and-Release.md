# Build & release

**Last updated:** 2026-05-08 UTC

## Requirements

- **Xcode:** 26.0+
- **Deployment target:** iOS **26.0+**
- **macOS:** 26.0+ recommended (Tahoe)

## Open & build

```bash
cd /path/to/envi-ios-v2.0
swift package resolve   # SPM
open ENVI.xcodeproj
```

Select the **ENVI** app scheme, choose an iOS simulator or device, then press **⌘R**.

Do not run the package workspace on a physical device. The Swift package is for module/test management; the installable product is the app target in `ENVI.xcodeproj`.

## Signing and bundle ID

- **Apple Developer Team:** Informal Content Agency (`7P76H55MAW`)
- **Bundle ID:** `com.weareinformal.envi`

## Fonts

Bundled TTFs registered via `ENVITypography.registerFonts()`:

- **Space Mono** (Regular, Bold, Italic, Bold Italic)
- **Inter** (multiple weights)

## Dependencies (SPM)

- SDWebImage
- Lottie
- RevenueCat + RevenueCatUI
- Firebase (Auth, Analytics, Crashlytics, Core)

## Info.plist

Photo library usage strings and other privacy keys live in the app target’s **Info.plist** (not duplicated here). Ensure **Photo Library** read/write descriptions match `PhotoLibraryManager` usage.

## Data Connect (backend only)

Deploy via Firebase CLI after adding `firebase.json` and configuring projects. See [Firebase Data Connect](Firebase-Data-Connect).

## CI

Current GitHub Actions checks:

- **Build and test (iOS simulator)** — full simulator build + test on pull requests to `main`
- **xctest** (workflow `USM iOS CI`) — targeted simulator validation used during the USM rollout

Local release-readiness verification passed on 2026-05-08 UTC:

- `swift package resolve`
- `npm --prefix functions run build`
- `npm --prefix functions test -- --runInBand`
- `xcodebuild ... build CODE_SIGNING_ALLOWED=NO`
- `xcodebuild ... test CODE_SIGNING_ALLOWED=NO`
- simulator install/launch for `com.weareinformal.envi`

## USM release note

The merged USM onboarding path is still staging-scaffolded in `OnboardingCoordinator.swift`. It currently uses a hardcoded debug user UUID and local `mintDebugJWT()` signer for the brain staging environment. Keep the USM flags off in release until that exchange is replaced with a real Firebase UID -> backend account/auth flow.

## Release checklist (suggested)

- [ ] App Store Connect version/build  
- [ ] RevenueCat offerings + entitlements match `PurchaseConstants`  
- [ ] No debug `Purchases.logLevel` in production (review `PurchaseManager`)  
- [ ] API keys only in secure config  
- [ ] Privacy nutrition labels match actual data collection  

---

Update when deployment target or signing strategy changes.
