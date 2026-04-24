# ENVI iOS v2.0

**AI-native content operating system for iOS.**

ENVI is a personalized ai content editor on iOS 26+ app that assembles and edits content pieces from the user's camera roll -- photos, videos, carousels, stories, and reels -- and presents them the final product that they then can swipe to approve or deny to then have it auto scheduled to post. Theres also a new interactive 3D content helix library that presents them a new way of looking at their camera roll and posted content. Powered by AI, the app studies the user to provide personalized smart insights, automated editing, suggestions, optimal posting times, and engagement analytics all based on their users data and social platforms.

**40 feature domains** | **28 feature modules** | **25 API repositories** | **150+ endpoint contracts**

## Repo Status

- `main` includes the merged USM foundation and onboarding work from PRs [#36](https://github.com/gerald-ica/envi-ios-v2.0/pull/36) and [#37](https://github.com/gerald-ica/envi-ios-v2.0/pull/37).
- The new User Self-Model path is gated by `FeatureFlags.shared.usmEnabled` and `FeatureFlags.shared.usmOnboardingEnabled`, with DEBUG defaults on and release defaults off.
- The USM onboarding flow is still staging-scaffolded: [`OnboardingCoordinator.swift`](ENVI/Features/Auth/OnboardingCoordinator.swift) currently hardcodes a debug user UUID and local `mintDebugJWT()` helper. Do not treat that path as production-ready until the Firebase UID -> backend account exchange is wired.

## Features

- **Template Tab** -- Camera-roll-native video/photo templates. ENVI scans the user's Photos library with Apple's Vision framework (9 ML requests per asset), classifies every photo and video, and shows templates pre-populated with the user's own content. Templates rank by how well the user's media matches each slot -- "4/4 slots filled" means ready to export in one tap. Dynamic catalog delivery via Lynx-in-WKWebView lets new templates ship without App Store updates.
- **World Explorer** -- 3D content library rendered as a helix timeline using SceneKit, displaying the user's content pieces in an immersive, navigable space
- **ENVI AI Engine** -- Caption generation, script editing, hook libraries, visual AI editing, style transfer, ideation dashboard with trends and competitor analysis
- **Content Editor** -- AVFoundation-based video and photo editor with crop, filter, speed, rotate, color grading, text overlays, and audio mixer
- **Content Analytics** -- KPI cards, engagement charts, benchmarks, trend intelligence, A/B experiments, retention cohorts, and source attribution
- **Multi-Platform Publishing** -- Scheduling queue, recurring posts, distribution rules, and cross-platform status reconciliation across 6 social platforms
- **Digital Asset Management** -- Folders, smart collections, version tracking, rights management, and storage quota
- **Brand Kits and Templates** -- Brand identity management, template gallery, and creative systems
- **Teams and Collaboration** -- Workspaces, role management, review workflows, approval steps, and share links
- **Campaigns** -- Campaign management with briefs, content requests, and sprint boards
- **Monetization** -- RevenueCat-powered Aura subscription, billing, commerce offers, and marketplace UGC

## Template Tab (New)

The Template Tab is ENVI's differentiator vs CapCut. Instead of showing a remote catalog of templates with generic placeholders, ENVI:

1. **Scans the camera roll** during onboarding (last 500 assets with progress UI, full library continues in background)
2. **Classifies every asset** with Apple Vision (scene labels, aesthetics score, face/person count, saliency, feature prints) + EXIF/GPS/TIFF metadata
3. **Clusters visually similar content** via native Swift ports of UMAP + HDBSCAN (from Apple's embedding-atlas algorithms)
4. **Matches assets to template slots** using 6 weighted scoring signals + cluster-cohesion bonus
5. **Renders templates with the user's own content** -- thumbnails are real camera roll photos, not stock
6. **Full-screen preview** with AVPlayer-backed video playback, slot swapping (tap to swap with alternates or pick from library), and one-tap export
7. **Dynamic catalog** via Lynx-in-WKWebView with SHA-256 bundle integrity verification and feature-flag rollback

### Template Tab Architecture

```
Camera Roll → PhotoLibraryManager → MediaClassifier Pipeline
                                        ├── MediaMetadataExtractor (EXIF/GPS/TIFF/MakerApple)
                                        ├── VisionAnalysisEngine (9 ML requests batched)
                                        ├── ReverseGeocodeCache (CLGeocoder + LRU)
                                        └── ClassificationCache (SwiftData @Model)
                                                    ↓
                                        EmbeddingIndex (SimilarityEngine + UMAP + HDBSCAN)
                                                    ↓
                                        TemplateMatchEngine + TemplateRanker
                                                    ↓
                                        TemplateTabViewModel (@Observable)
                                                    ↓
                                        TemplateTabView → TemplatePreviewView → Export
```

### Scan Strategy

- **Onboarding**: `scanOnboardingBatch()` — last 500 PHAssets with progress ring UI
- **Background**: `BGProcessingTaskRequest` — full library in 100-asset chunks, resumable via UserDefaults checkpoint
- **Lazy**: Template tab rescan on open — classifies delta since last scan
- **Incremental**: `PHPhotoLibraryChangeObserver` — classifies new/updated assets in real-time
- **Thermal-aware**: `ThermalAwareScheduler` throttles/pauses work based on `ProcessInfo.thermalState` + Low Power Mode

## Chat/Explore Tab

The Chat/Explore tab is a dual-mode view combining:

- **World Explorer** — A 3D helix visualization of the user's content pieces, supporting touch-based camera rotation, content type filtering, time scrubbing, and click-to-zoom detail views
- **AI Chat** — A conversational interface for asking ENVI to analyze, edit, or create content based on the user's library

Toggle between modes or use them together. The tab uses the "sparkles" SF Symbol icon.

## Content Pieces

Content pieces are already-edited short-form media created from the user's camera roll. During onboarding, ENVI connects to the user's Photos app and automatically assembles content pieces — turning raw photos, videos, and other media into polished, ready-to-post formats. These content pieces populate the World Explorer's 3D helix timeline.

## Architecture

ENVI uses a **SwiftUI + UIKit hybrid** architecture targeting **iOS 26.0+**.

- **SwiftUI** — Library, Chat/Explore, Analytics, Profile, Templates, Export screens
- **UIKit** — Feed, Editor, custom tab bar, navigation coordinators
- **SceneKit** — 3D World Explorer helix rendering and interaction
- **Vision** — On-device ML (classify, aesthetics, face, saliency, feature prints, document detect, lens smudge)
- **Accelerate** — BLAS/LAPACK for native UMAP + HDBSCAN embedding pipeline
- **SwiftData** — Classification cache with indexed query fields
- **WebKit** — Lynx-in-WKWebView for dynamic template catalog delivery
- **BackgroundTasks** — Resumable camera roll scanning with thermal awareness
- **SPM Dependencies** — SDWebImage, Lottie, RevenueCat, Firebase (Auth, Analytics, Crashlytics)

### Navigation

- **AppCoordinator** — Root coordinator managing auth flow (Splash → Onboarding → Sign In) and main app flow
- **MainTabBarController** — Custom UIKit tab bar controller hosting 3 tabs with a floating pill-shaped tab bar (For You/Gallery, Chat/Explore, Profile)
- **OnboardingCoordinator** — Manages onboarding flow including Photos permission request and template scan progress

### Layer Structure

```
ENVI/
├── App/                    # App delegate, scene delegate, root coordinator
├── Components/             # Reusable design system components
├── Core/
│   ├── AI/                 # ENVI Brain, ContentAnalyzer, PredictionEngine
│   ├── Auth/               # Firebase auth, App Check, social OAuth broker
│   ├── Config/             # AppEnvironment, FeatureFlags
│   ├── Design/             # ENVITheme, ENVITypography, ENVISpacing, ThemeManager
│   ├── Embedding/          # SimilarityEngine, DimensionReducer (UMAP), DensityClusterer (HDBSCAN), EmbeddingIndex
│   ├── Extensions/         # Color+ENVI, Font+ENVI, View+Extensions
│   ├── Media/              # MediaClassifier, VisionAnalysisEngine, ClassificationCache, MediaScanCoordinator, ThermalAwareScheduler
│   ├── Networking/         # APIClient, ContentPieceAssembler
│   ├── Storage/            # UserDefaultsManager, PhotoLibraryManager
│   ├── Templates/          # TemplateMatchEngine, TemplateRanker, TemplateCatalogClient, TemplateManifest
│   ├── Telemetry/          # TelemetryManager (Firebase Analytics)
│   └── USM/                # User Self-Model schema, cache, sync
├── Features/
│   ├── Auth/               # Splash, legacy onboarding, sign in
│   ├── ChatExplore/        # Dual-mode Chat + World Explorer
│   ├── Connectors/         # Meta-family connector UI
│   ├── HomeFeed/           # For You/Gallery, templates, feed, library
│   ├── Modals/             # Shared modal surfaces
│   ├── Profile/            # Stats, connected platforms, settings
│   ├── Publishing/         # Publishing queue and related UI
│   └── USM/                # Feature-flagged USM onboarding flow
├── Models/                 # User, ContentItem, ContentPiece, LibraryItem, analytics, templates
└── Navigation/             # Coordinator protocol, MainTabBarController
```

## Build Instructions

### Requirements

- **Xcode 26.0+**
- **iOS 26.0+** deployment target
- macOS 26.0+ (Tahoe) recommended

### Setup

```bash
# Clone the repository
git clone https://github.com/gerald-ica/envi-ios-v2.0.git
cd envi-ios-v2.0

# Resolve Swift Package Manager dependencies
swift package resolve

# Open the installable iOS app project
open ENVI.xcodeproj
```

### Build & Run

1. Open `ENVI.xcodeproj` in Xcode
2. Select an iOS 26.0+ simulator or device
3. Press `⌘R` to build and run

`Package.swift` is kept for dependency resolution and tests. The physical-device build must use the app target from `ENVI.xcodeproj`, because a Swift package executable isn't an installable `.app` bundle.

### Background task identifiers

`ENVI/Resources/Info.plist` registers the background task identifiers the app is allowed to schedule. As of Sprint 03 it lists:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.weareinformal.envi.staging.usm-recompute</string>
</array>
```

Add additional identifiers (e.g. for the media-classifier full-scan task) here before registering them with `BGTaskScheduler`, otherwise iOS will silently refuse to run the task.

### Bundle ID

```
com.weareinformal.envi.staging
```

## Fonts

The app uses two custom font families bundled in `ENVI/Resources/Fonts/`:

- **Space Mono** (Regular, Bold, Italic, Bold Italic) — headings, labels, navigation, buttons
- **Inter** (Regular, Medium, SemiBold, Bold, ExtraBold, Black) — body text, descriptions

Registration happens two ways and both must stay in sync with the `.ttf` files on disk:

1. **Declarative** — `UIAppFonts` in `ENVI/Resources/Info.plist` lists all 10 font filenames, so iOS registers them during process bootstrap before any UI renders.
2. **Programmatic** — `ENVITypography.registerFonts()` calls `CTFontManagerRegisterFontsForURL` at scene-delegate launch as a belt-and-suspenders fallback.

## Documentation (GitHub Wiki)

Full engineering documentation lives in the [GitHub Wiki](https://github.com/gerald-ica/envi-ios-v2.0/wiki):

- [Architecture](https://github.com/gerald-ica/envi-ios-v2.0/wiki/Architecture) -- system design, repository pattern, environment model
- [Feature Domains](https://github.com/gerald-ica/envi-ios-v2.0/wiki/Feature-Domains) -- all 40 domains with implementation status
- [API Contracts](https://github.com/gerald-ica/envi-ios-v2.0/wiki/API-Contracts) -- 150+ endpoint specifications organized by domain
- [Getting Started](https://github.com/gerald-ica/envi-ios-v2.0/wiki/Getting-Started) -- development environment setup

Wiki source files are in `docs/github-wiki/`. See `docs/github-wiki/SYNC-TO-GITHUB-WIKI.md` for publish steps.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Follow the repository pattern: Protocol -> Mock -> API -> Provider
4. Ensure the app builds and simulator tests pass (`xcodebuild test -scheme ENVI -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO`)
5. Submit a pull request with a clear description

See the [Architecture wiki page](https://github.com/gerald-ica/envi-ios-v2.0/wiki/Architecture) for coding patterns and conventions.

## License

Copyright 2026 Informal. All rights reserved.
