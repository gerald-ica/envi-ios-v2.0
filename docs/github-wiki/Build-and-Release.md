# Build & release

**Last updated:** 2026-04-03 UTC

## Requirements

- **Xcode:** 15.0+
- **Deployment target:** iOS **17.0+**
- **macOS:** 14.0+ recommended (Sonoma)

## Open & build

```bash
cd /path/to/envi-ios-v2.0
swift package resolve   # SPM
open .swiftpm/xcode/package.xcworkspace
```

Select an iOS 17+ simulator or device, **⌘R** to run.

## Bundle ID

`com.informal.envi`

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

## Release checklist (suggested)

- [ ] App Store Connect version/build  
- [ ] RevenueCat offerings + entitlements match `PurchaseConstants`  
- [ ] No debug `Purchases.logLevel` in production (review `PurchaseManager`)  
- [ ] API keys only in secure config  
- [ ] Privacy nutrition labels match actual data collection  

---

Update when deployment target or signing strategy changes.
