# Architecture

**Last updated:** 2026-04-03 UTC

## System architecture overview

ENVI uses a **Firebase Auth + Data Connect + API Facade** architecture:

```
┌─────────────────────────────────────────────────┐
│                  iOS Client                      │
│  SwiftUI + UIKit hybrid  │  SceneKit (3D)       │
│  iOS 17.0+               │  Xcode 15+           │
├─────────────────────────────────────────────────┤
│              ViewModel Layer                     │
│  Feature ViewModels consume repository protocols │
├─────────────────────────────────────────────────┤
│            Repository Layer                      │
│  Protocol → Mock → API → Provider (factory)      │
│  25 typed repositories, 150+ endpoints           │
├─────────────────────────────────────────────────┤
│              APIClient                           │
│  Typed request pipeline with auth token injection│
│  Retry policy with exponential backoff           │
├──────────────┬──────────────────────────────────┤
│ Firebase Auth│       API Facade                  │
│ (identity)   │  https://api.envi.app/v1/         │
├──────────────┴──────────────────────────────────┤
│         Firebase Data Connect                    │
│  PostgreSQL schema + GraphQL connectors          │
│  (under dataconnect/ — deploy via Firebase CLI)  │
└─────────────────────────────────────────────────┘
```

## App layers

```
ENVI/
├── App/                 # ENVIApp (AppDelegate), SceneDelegate, AppCoordinator
├── Core/
│   ├── AI/              # ENVIBrain + analyzers, prediction, experiments
│   ├── Data/            # Repository protocols and implementations (25 repos)
│   ├── Design/          # ENVITheme, ENVITypography, ENVISpacing, ThemeManager
│   ├── Extensions/
│   ├── Networking/      # APIClient (typed), ContentPieceAssembler
│   ├── Purchases/       # PurchaseManager, PurchaseConstants
│   └── Storage/         # UserDefaultsManager, PhotoLibraryManager,
│                        # ApprovedMediaLibraryStore, LocationPermissionManager
├── Components/          # Design system controls (buttons, cards, tab bar, etc.)
├── Features/            # 28 feature modules (Auth, Feed, Library, AI, ...)
├── Models/              # Domain / UI models
└── Navigation/          # Coordinator protocols, MainTabBarController
```

## Repository pattern

Each data domain follows a four-part pattern:

```
Protocol (e.g., ContentRepositoryProtocol)
    ├── MockContentRepository    — sample/stub data for dev
    ├── APIContentRepository     — typed APIClient calls for staging/prod
    └── ContentProvider          — environment-aware factory
```

**How it works:**
1. Feature ViewModels declare a dependency on the protocol (e.g., `ContentRepositoryProtocol`)
2. The Provider inspects the active environment (`dev` / `staging` / `prod`)
3. In `dev`, it injects the Mock implementation with sample data
4. In `staging` or `prod`, it injects the API implementation that calls real endpoints

This allows the entire app to run without a backend in development mode.

## Feature module structure

Each feature module follows this internal structure:

```
Features/{FeatureName}/
├── Models/          # Domain models specific to this feature
├── Repository/      # Protocol + Mock + API + Provider
├── ViewModels/      # ObservableObject ViewModels
└── Views/           # SwiftUI views (or UIKit view controllers)
```

ViewModels are `@MainActor` `ObservableObject` classes that:
- Own state published to views via `@Published` properties
- Call repository methods for data operations
- Handle loading states, errors, and optimistic UI updates

## App lifecycle

1. **`ENVIApp`** (`@main`): registers fonts via `ENVITypography.registerFonts()`, configures `PurchaseManager` (RevenueCat).
2. **`SceneDelegate`**: creates `UIWindow`, forces dark interface style, instantiates `AppCoordinator`, calls `start()`.
3. **`AppCoordinator`**: root `UINavigationController`; routes **Splash** → onboarding complete? → **MainTabBarController** or **OnboardingCoordinator** stack; sign-out returns to **SignInView**.

## Coordinators

| Type | File | Role |
|------|------|------|
| `Coordinator` / `ParentCoordinator` | `Navigation/NavigationCoordinator.swift` | Protocols only (`start()`, child list). |
| `AppCoordinator` | `App/AppCoordinator.swift` | Root flow, onboarding flag, main tabs, sign-out. |
| `OnboardingCoordinator` | `Features/Auth/OnboardingCoordinator.swift` | Pushes SwiftUI onboarding inside UIKit navigation. |

## Main tabs (`MainTabBarController`)

| Index | Tab | Implementation |
|-------|-----|----------------|
| 0 | Feed | UIKit `FeedViewController` inside `UINavigationController` |
| 1 | Library | SwiftUI `LibraryView` in hosting controller |
| 2 | Chat / Explore | SwiftUI `ChatExploreView` |
| 3 | Analytics | SwiftUI `AnalyticsView` |
| 4 | Profile | SwiftUI `ProfileView` |

Custom **`ENVITabBar`** (pill-shaped) overlays the bottom; scroll views in each tab can hide/show the tab bar via pan gestures.

## Design system

| Token | Purpose | File |
|-------|---------|------|
| `ENVITheme` | Color palette (monochromatic, dark-first) | `Core/Design/ENVITheme.swift` |
| `ENVITypography` | Font registration and text styles | `Core/Design/ENVITypography.swift` |
| `ENVISpacing` | Spacing scale (4pt grid) | `Core/Design/ENVISpacing.swift` |
| `ThemeManager` | Runtime theme switching | `Core/Design/ThemeManager.swift` |

**Fonts:**
- **Space Mono** — headings, labels, navigation, buttons (UPPERCASE style)
- **Inter** — body text, descriptions

## Environment model

| Environment | Config source | Data layer |
|-------------|--------------|------------|
| `dev` | Bundled defaults | Mock repositories (sample data) |
| `staging` | Staging config | API repositories against staging backend |
| `prod` | Production config | API repositories against production backend |

Environment is determined at launch by `EnvironmentModel` and propagated to all Provider factories.

## World Explorer (SceneKit)

- **`HelixSceneController`**: builds scene (starfield, helix spine, ~1600 content planes, timeline, link lines); animates stream vs spiral modes; hit-testing for selection.
- **`HelixSceneRepresentable`**: bridges `SCNView` to SwiftUI; syncs filters, theme, scrub, zoom, view mode.
- **`WorldExplorerView`**: HUD, filters, time scrubber, zoom levels (Y/M/W/D), sheets (library settings, editor).
- **`ContentLibrary`**: maps `FeedViewModel.imageNames` + `ContentPiece.sampleLibrary` into helix metadata.

See [Features & Requirements](Features-and-Requirements) and [Roadmap](Roadmap-and-Coming-Soon) for production vs placeholder behavior.

## Dependencies (SPM)

| Package | Purpose |
|---------|---------|
| **SDWebImage** | Async image loading and caching |
| **Lottie** | Animation playback |
| **RevenueCat** | Subscription management |
| **RevenueCatUI** | Paywall and Customer Center views |

Firebase SDK is used for Auth but not yet declared in `Package.swift` for Data Connect. See [Firebase Data Connect](Firebase-Data-Connect).

## Bundle identifier

`com.informal.envi`

## Further reading

- [Feature Domains](Feature-Domains) — full domain inventory (40 domains)
- [API Contracts](API-Contracts) — all 150+ endpoint specifications
- [Getting Started](Getting-Started) — development environment setup
