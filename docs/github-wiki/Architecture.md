# Architecture

**Last updated:** 2026-04-03 UTC

## Layers

```
ENVI/
├── App/                 # ENVIApp (AppDelegate), SceneDelegate, AppCoordinator
├── Core/
│   ├── AI/              # ENVIBrain + analyzers, prediction, experiments
│   ├── Design/          # ENVITheme, ENVITypography, ENVISpacing, ThemeManager
│   ├── Extensions/
│   ├── Networking/      # APIClient (stub), ContentPieceAssembler (stub)
│   ├── Purchases/       # PurchaseManager, PurchaseConstants
│   └── Storage/         # UserDefaultsManager, PhotoLibraryManager, ApprovedMediaLibraryStore, LocationPermissionManager
├── Components/          # Design system controls (buttons, cards, tab bar, etc.)
├── Features/            # Feature modules (Auth, Feed, Library, …)
├── Models/              # Domain / UI models
└── Navigation/          # Coordinator protocols, MainTabBarController
```

## App lifecycle

1. **`ENVIApp`** (`@main`): registers fonts, configures `PurchaseManager`.
2. **`SceneDelegate`**: creates `UIWindow`, forces dark interface style at window level, instantiates `AppCoordinator`, calls `start()`.
3. **`AppCoordinator`**: root `UINavigationController`; **Splash** → if onboarding complete → **MainTabBarController**, else **OnboardingCoordinator** stack; sign-out returns to **SignInView**.

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

## World Explorer (SceneKit)

- **`HelixSceneController`**: builds scene (starfield, helix spine, ~1600 content planes, timeline, link lines); animates stream vs spiral modes; hit-testing for selection.
- **`HelixSceneRepresentable`**: bridges `SCNView` to SwiftUI; syncs filters, theme, scrub, zoom, view mode.
- **`WorldExplorerView`**: HUD, filters, time scrubber, zoom levels (Y/M/W/D), sheets (library settings, editor).
- **`ContentLibrary`**: maps `FeedViewModel.imageNames` + `ContentPiece.sampleLibrary` into helix metadata.

See [Features & requirements](Features-and-Requirements) and [Roadmap](Roadmap-and-Coming-Soon) for production vs placeholder behavior.

## Dependencies (SPM)

- **SDWebImage** — image loading
- **Lottie** — animations
- **RevenueCat** + **RevenueCatUI** — subscriptions, paywalls, Customer Center (`Package.swift`)

**Not** in Package.swift: Firebase, Data Connect — see [Firebase Data Connect](Firebase-Data-Connect).

## Bundle identifier

`com.informal.envi` (per README).
