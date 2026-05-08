# Architecture

**Last updated:** 2026-05-08 UTC

## System architecture overview

ENVI uses a **Firebase Auth + Data Connect + API Facade** architecture:

```
┌───────────────────────────────────────────────────────────┐
│                       iOS Client                          │
│  SwiftUI + UIKit hybrid  │  SceneKit (3D)  │  WebKit      │
│  Vision  │  Accelerate  │  SwiftData                      │
│  iOS 26.0+               │  Xcode 26+                     │
├───────────────────────────────────────────────────────────┤
│                    ViewModel Layer                         │
│  Feature ViewModels consume repository protocols           │
├───────────────────────────────────────────────────────────┤
│                  Repository Layer                          │
│  Protocol → Mock → API → Provider (factory)                │
│  25 typed repositories, 150+ endpoints                     │
├───────────────────────────────────────────────────────────┤
│                    APIClient                               │
│  Typed request pipeline with auth token injection          │
│  Retry policy with exponential backoff                     │
├────────────────┬──────────────────────────────────────────┤
│ Firebase Auth  │          API Facade                       │
│ (identity)     │  https://api.envi.app/v1/                 │
├────────────────┴──────────────────────────────────────────┤
│              Firebase Data Connect                         │
│  PostgreSQL schema + GraphQL connectors                    │
│  (under dataconnect/ — deploy via Firebase CLI)            │
└───────────────────────────────────────────────────────────┘
```

## App layers

```
ENVI/
├── App/                 # ENVIApp (AppDelegate), SceneDelegate, AppCoordinator
├── Core/
│   ├── AI/              # ENVIBrain + analyzers, prediction, experiments
│   ├── Auth/            # AuthManager, SocialOAuthManager, AppleSignInButton, GoogleSignInButton
│   ├── Config/          # AppEnvironment, FeatureFlags
│   ├── Data/            # Repository protocols and implementations (25 repos)
│   ├── Design/          # ENVITheme, ENVITypography, ENVISpacing, ThemeManager
│   ├── Editing/         # VideoEditService (AVFoundation)
│   ├── Embedding/       # SimilarityEngine, DimensionReducer (UMAP),
│   │                    # DensityClusterer (HDBSCAN), EmbeddingIndex
│   ├── Extensions/
│   ├── Media/           # MediaClassifier, VisionAnalysisEngine, MediaMetadataExtractor,
│   │                    # ClassificationCache, ReverseGeocodeCache, MediaScanCoordinator,
│   │                    # ThermalAwareScheduler, BatchedVisionRequests
│   ├── Networking/      # APIClient (typed), ContentPieceAssembler
│   ├── Purchases/       # PurchaseManager, PurchaseConstants
│   ├── Storage/         # UserDefaultsManager, PhotoLibraryManager,
│   │                    # ApprovedMediaLibraryStore, LocationPermissionManager
│   ├── Telemetry/       # TelemetryManager
│   └── Templates/       # TemplateMatchEngine, TemplateRanker, TemplateCatalogClient,
│                        # TemplateManifest
├── Components/          # Design system controls (buttons, cards, tab bar, etc.)
├── Features/            # 28+ feature modules (Auth, Feed, Library, AI, ...)
│   ├── Templates/       # TemplateTabView, TemplateCardView, TemplatePreviewView,
│   │                    # TemplatePlayerView, LynxWebView, SwiftLynxBridge
│   ├── ForYouGallery/   # ForYouGalleryContainerView, ForYouSwipeView,
│   │                    # GalleryGridView, FeedDetailView
│   └── ...              # (other feature modules)
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
| 0 | For You / Gallery | SwiftUI `ForYouGalleryContainerView` in `UIHostingController` |
| 1 | World Explorer / AI Chat | SwiftUI `ChatExploreView` (center ENVI logo) |
| 2 | Profile + Settings | SwiftUI `ProfileView` |

Custom **`ENVITabBar`**: Condensed 3-tab pill bar (164x64pt, `#4A60B2` fill with glass blur, white 45x45 active circle behind selected icon). Supports optional title labels and icon-only tabs. Scroll views in each tab can hide/show the tab bar via pan gestures.

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

## Template Tab architecture

The Template Tab surfaces editable video/photo templates matched to the user's camera roll content via on-device Vision ML analysis and embedding similarity.

### Pipeline

```
Camera Roll
    │
    ▼
PhotoLibraryManager
    │
    ▼
MediaClassifier Pipeline
  ├── ClassifyImage
  ├── CalculateImageAestheticsScores
  ├── DetectFaceRectangles
  ├── GenerateImageSaliency
  ├── GenerateFeaturePrint
  ├── RecognizeAnimals
  ├── DetectHorizon
  ├── RecognizeDocuments
  └── DetectCameraLensSmudge
    │
    ▼
EmbeddingIndex
    │
    ▼
TemplateMatchEngine
    │
    ▼
TemplateTabView
```

### Vision ML requests

The `MediaClassifier` dispatches the following `VNRequest` types per asset:

| Request | Purpose |
|---------|---------|
| `ClassifyImage` | Scene/object taxonomy (e.g., "beach", "food", "portrait") |
| `CalculateImageAestheticsScores` | Quality/aesthetics score for ranking |
| `DetectFaceRectangles` | Face count and bounding boxes |
| `GenerateImageSaliency` | Attention heat-map for crop guidance |
| `GenerateFeaturePrint` | 2048-dim embedding vector for similarity |
| `RecognizeAnimals` | Pet/animal detection |
| `DetectHorizon` | Horizon angle for landscape correction |
| `RecognizeDocuments` | Filter out receipts, screenshots, documents |
| `DetectCameraLensSmudge` | Flag low-quality captures |

### Scan strategy

| Strategy | Trigger | Scope |
|----------|---------|-------|
| **Onboarding** | First launch, after photo-library permission grant | Up to 500 most-recent assets |
| **Background** | `BGProcessingTask` | Remaining unscanned assets |
| **Lazy** | User opens Template tab | Delta scan (new assets since last scan) |
| **Incremental** | `PHPhotoLibraryChangeObserver` fires | Newly added/modified assets only |

### Thermal awareness

`ThermalAwareScheduler` adapts batch sizes based on `ProcessInfo.thermalState`:

| Thermal state | Batch size | Behavior |
|---------------|------------|----------|
| `.nominal` | Full (configurable) | Normal processing speed |
| `.fair` | 75% | Slight throttle |
| `.serious` | 50% | Reduced throughput |
| `.critical` | Pause | Scanning suspended until cool-down |

### Lynx bridge

`SwiftLynxBridge` connects the native Swift layer with Lynx-rendered template previews inside `LynxWebView`:

- **Codable validation**: All bridge messages conform to `Codable` protocols with strict type checking
- **Token-bucket rate limit**: Prevents excessive bridge calls from overwhelming the native layer
- **Payload caps**: Maximum message size enforced to prevent memory spikes

## Authentication architecture

ENVI uses **Firebase Auth** as the identity provider with multiple sign-in methods:

### Sign-in methods

| Method | Implementation |
|--------|----------------|
| **Email / Password** | Standard Firebase Auth `createUser` / `signIn` |
| **Google Sign-In** | `GIDSignIn` SDK → Firebase `OAuthProvider` credential |
| **Apple Sign-In** | `ASAuthorizationController` → Firebase `OAuthProvider` credential |

### Core components

- **`AuthManager`** — Singleton that owns the Firebase `Auth.auth()` instance. Registers a state-change listener (`addStateDidChangeListener`) to publish the current `User?` to the rest of the app. All sign-in/sign-out flows route through `AuthManager`.
- **`SocialOAuthManager`** — Coordinates third-party OAuth flows (Google, Apple). Supports a **mock mode** for development builds so the full OAuth flow can be bypassed with stub credentials.
- **`AppleSignInButton`** / **`GoogleSignInButton`** — SwiftUI button components that trigger the respective OAuth flows via `SocialOAuthManager`.

### Auth flow

```
SignInView
    │
    ├── Email/Password → FirebaseAuth.signIn(email:password:)
    ├── Google → GIDSignIn.sharedInstance.signIn() → OAuthProvider credential → FirebaseAuth
    └── Apple → ASAuthorizationController → OAuthProvider credential → FirebaseAuth
    │
    ▼
AuthManager.stateDidChangeListener
    │
    ▼
AppCoordinator routes to MainTabBarController
```

## Dependencies (SPM)

| Package | Purpose |
|---------|---------|
| **SDWebImage** | Async image loading and caching |
| **Lottie** | Animation playback |
| **RevenueCat** | Subscription management |
| **RevenueCatUI** | Paywall and Customer Center views |
| **FirebaseAuth** | Authentication (email + Apple Sign-In + Google Sign-In) |
| **FirebaseAnalytics** | Product analytics and event tracking |
| **FirebaseCrashlytics** | Crash reporting and diagnostics |
| **FirebaseCore** | Firebase SDK foundation |
| **GoogleSignIn** | Google OAuth sign-in SDK (GIDSignIn) |

All dependencies are declared in `Package.swift`. See [Firebase Data Connect](Firebase-Data-Connect) for the backend data layer.

## Bundle identifier

`com.weareinformal.envi`

Signing is configured for Informal Content Agency, Apple Developer Team `7P76H55MAW`.

## Further reading

- [Feature Domains](Feature-Domains) — full domain inventory (40 domains)
- [API Contracts](API-Contracts) — all 150+ endpoint specifications
- [Getting Started](Getting-Started) — development environment setup
