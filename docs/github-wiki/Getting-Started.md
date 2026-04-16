# Getting Started

**Last updated:** 2026-04-03 UTC

This guide walks through setting up the ENVI iOS development environment from scratch.

## Prerequisites

- **Xcode 15.0+** (download from the Mac App Store or [developer.apple.com](https://developer.apple.com/xcode/))
- **macOS 14.0+** (Sonoma) recommended
- **iOS 17.0+** simulator or physical device
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
- **Firebase** (Auth, Analytics, Crashlytics, Core) -- identity, telemetry, and crash reporting

## 3. Firebase setup

The app uses Firebase Auth for identity. To run against a Firebase project:

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add an iOS app with bundle ID `com.informal.envi`
3. Download the generated `GoogleService-Info.plist`
4. Place it in the `ENVI/` directory (this file is gitignored)

For local development without Firebase, the app falls back to mock authentication flows.

## 4. Environment configuration

ENVI supports three environments configured via runtime config:

| Environment | Purpose | Data source |
|-------------|---------|-------------|
| `dev` | Local development | Mock repositories with sample data |
| `staging` | Integration testing | API repositories against staging backend |
| `prod` | Production | API repositories against production backend |

The environment is determined by the `EnvironmentModel` configuration source. In `dev` mode, all repositories return mock/sample data without requiring a running backend.

## 5. Open in Xcode

```bash
open .swiftpm/xcode/package.xcworkspace
```

Or open `Package.swift` in Xcode if you want Xcode to regenerate the SwiftPM workspace.

## 6. Build and run

1. Select an **iOS 17.0+** simulator or connected device
2. Press **Cmd+R** to build and run
3. The app launches into the Splash screen, then routes to Onboarding (first run) or the main tab bar

## Project structure

```
envi-ios-v2.0/
├── ENVI/                    # Main app target
│   ├── App/                 # AppDelegate, SceneDelegate, AppCoordinator
│   ├── Core/
│   │   ├── AI/              # ENVI Brain + analyzers
│   │   ├── Data/            # Repository protocols and implementations
│   │   ├── Design/          # ENVITheme, ENVITypography, ENVISpacing
│   │   ├── Extensions/      # Swift extensions
│   │   ├── Networking/      # APIClient, ContentPieceAssembler
│   │   ├── Purchases/       # PurchaseManager (RevenueCat)
│   │   └── Storage/         # UserDefaults, PhotoLibrary, Location
│   ├── Components/          # Reusable design system UI components
│   ├── Features/            # Feature modules (28 domains)
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
swift test
# or in Xcode: Cmd+U
```

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
| Fonts not rendering | Ensure `ENVITypography.registerFonts()` is called in the app delegate |
| Firebase auth errors | Verify `GoogleService-Info.plist` is present and matches your Firebase project |
| Photos permission denied | Reset simulator via Device > Erase All Content and Settings |

## Next steps

- Read the [Architecture](Architecture) page to understand the app structure
- Review [Feature Domains](Feature-Domains) for the full domain inventory
- Check [API Contracts](API-Contracts) for backend endpoint specifications
- See [Build & Release](Build-and-Release) for release checklists
