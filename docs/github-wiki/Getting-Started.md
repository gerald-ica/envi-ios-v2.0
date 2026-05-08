# Getting Started

**Last updated:** 2026-05-08 UTC

This guide walks through setting up the ENVI iOS development environment from scratch.

## Prerequisites

- **Xcode 26.0+** (download from the Mac App Store or [developer.apple.com](https://developer.apple.com/xcode/))
- **macOS 26.0+** (Tahoe) recommended
- **iOS 26.0+** simulator or physical device
- **Git** (included with Xcode Command Line Tools)

## 1. Clone the repository

```bash
git clone https://github.com/gerald-ica/envi-ios-v2.0.git
cd envi-ios-v2.0
```

## 2. Resolve Swift Package Manager dependencies

```bash
swift package resolve
```

This fetches the following SPM dependencies:
- **SDWebImage** -- async image loading and caching
- **Lottie** -- animation playback
- **RevenueCat** + **RevenueCatUI** -- subscription management, paywalls, and Customer Center
- **Firebase** (Auth, Analytics, Crashlytics, App Check, Firestore, Remote Config, Core) -- identity, telemetry, live insights, feature flags, and crash reporting
- **GoogleSignIn** -- Google identity provider

## 3. Firebase setup

The checked-in app target is currently wired for Informal Content Agency:

- **Apple Developer Team:** `7P76H55MAW`
- **Bundle ID:** `com.weareinformal.envi`
- **Checked-in plist path:** `ENVI/Resources/GoogleService-Info.plist`

If you want to point the app at a different Firebase project:

1. Add the matching iOS app in Firebase for your intended bundle ID.
2. Replace `ENVI/Resources/GoogleService-Info.plist` with the matching plist.
3. Update `project.yml` bundle identifier and signing team if you are changing away from the current Informal Content Agency configuration.
4. Regenerate the project if needed (`xcodegen generate`).

Auth uses Firebase directly, and DEBUG builds install the App Check debug provider before `FirebaseApp.configure()`. Release builds use DeviceCheck-backed App Check.

## 4. Environment configuration

ENVI supports three environments configured via runtime config:

| Environment | Purpose | Data source |
|-------------|---------|-------------|
| `dev` | Local development | Mock repositories with sample data |
| `staging` | Integration testing | API repositories against staging backend |
| `prod` | Production | API repositories against production backend |

The environment is determined by `AppConfig` / `FeatureFlags`. In addition to backend host selection, Firebase Remote Config can override runtime flags such as `usmEnabled`, `usmOnboardingEnabled`, and connector gates.

## 5. Open in Xcode

```bash
open ENVI.xcodeproj
```

Use `Package.swift` for dependency and test management only. For simulator or device runs, use the `ENVI` application scheme from `ENVI.xcodeproj` so Xcode builds a signed `.app` bundle.

## 6. Build and run

1. Select the **ENVI** app scheme and an **iOS 26.0+** simulator or connected device
2. Press **Cmd+R** to build and run
3. The app launches into the Splash screen, then routes to Onboarding (first run) or the main tab bar

## Project structure

```
envi-ios-v2.0/
├── ENVI/                    # Main app target
│   ├── App/                 # AppDelegate, SceneDelegate, AppCoordinator
│   ├── Core/
│   │   ├── AI/              # ENVI Brain + analyzers
│   │   ├── Auth/            # Firebase auth, App Check, social OAuth broker
│   │   ├── Design/          # ENVITheme, ENVITypography, ENVISpacing
│   │   ├── Embedding/       # SimilarityEngine, UMAP, HDBSCAN, EmbeddingIndex
│   │   ├── Extensions/      # Swift extensions
│   │   ├── Media/           # Classification cache, classifier, scan coordinator
│   │   ├── Networking/      # APIClient, ContentPieceAssembler
│   │   ├── Storage/         # UserDefaults, PhotoLibrary, Location
│   │   ├── Telemetry/       # Analytics / event tracking
│   │   └── USM/             # User Self-Model schema, cache, sync
│   ├── Components/          # Reusable design system UI components
│   ├── Features/            # Auth, HomeFeed, ChatExplore, Profile, Publishing, USM
│   ├── Models/              # Domain and UI models
│   ├── Navigation/          # Coordinator protocols, MainTabBarController
│   └── Resources/           # Assets, fonts, plists
├── ENVITests/               # Unit tests
├── dataconnect/             # Firebase Data Connect schema + connectors
├── docs/                    # Documentation and wiki source
├── scripts/                 # Build and CI scripts
└── Package.swift            # SPM manifest
```

## Fonts

The app bundles two custom font families:

- **Space Mono** (Regular, Bold, Italic, Bold Italic) -- headings, labels, navigation, buttons
- **Inter** (Regular, Medium, SemiBold, Bold, ExtraBold, Black) -- body text, descriptions

Fonts are registered automatically at app launch via `ENVITypography.registerFonts()`.

## Common tasks

### Running tests

```bash
xcodebuild test \
  -scheme ENVI \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
# or in Xcode: Cmd+U
```

`swift test` is still useful for quick package validation, but the app's CI and the authoritative local verification path both run through `xcodebuild test` against the `ENVI.xcodeproj` app scheme.

### Checking for secrets in code

```bash
./scripts/check-secrets.sh
```

### Deploying Data Connect (backend)

```bash
cd dataconnect
firebase deploy --only dataconnect
```

See [Firebase Data Connect](Firebase-Data-Connect) for full backend setup.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| SPM resolution fails | Delete `.build/` and `Package.resolved`, then run `swift package resolve` again |
| "Attempted to install `ENVI` which is not a .app bundle" | Open `ENVI.xcodeproj` and run the app scheme instead of the Swift package workspace |
| Fonts not rendering | Ensure `ENVITypography.registerFonts()` is called in the app delegate |
| Firebase auth errors | Verify `GoogleService-Info.plist` is present and matches your Firebase project |
| USM onboarding appears but fails immediately | The merged USM path is still staging-scaffolded; verify `usmEnabled` / `usmOnboardingEnabled` and do not expect release-ready auth exchange yet |
| Photos permission denied | Reset simulator via Device > Erase All Content and Settings |

## Next steps

- Read the [Architecture](Architecture) page to understand the app structure
- Review [Feature Domains](Feature-Domains) for the full domain inventory
- Check [API Contracts](API-Contracts) for backend endpoint specifications
- See [Build & Release](Build-and-Release) for release checklists
