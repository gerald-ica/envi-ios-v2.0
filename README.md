# ENVI iOS v2.0

**AI-native content operating system for iOS.**

ENVI assembles and edits content pieces from the user's camera roll -- photos, videos, carousels, stories, and reels -- and presents them in an interactive 3D content library. Powered by AI, it provides smart insights, automated editing suggestions, optimal posting times, and engagement analytics across social platforms.

**40 feature domains** | **28 feature modules** | **25 API repositories** | **150+ endpoint contracts**

## Features

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

## Chat/Explore Tab

The Chat/Explore tab is a dual-mode view combining:

- **World Explorer** — A 3D helix visualization of the user's content pieces, supporting touch-based camera rotation, content type filtering, time scrubbing, and click-to-zoom detail views
- **AI Chat** — A conversational interface for asking ENVI to analyze, edit, or create content based on the user's library

Toggle between modes or use them together. The tab uses the "sparkles" SF Symbol icon.

## Content Pieces

Content pieces are already-edited short-form media created from the user's camera roll. During onboarding, ENVI connects to the user's Photos app and automatically assembles content pieces — turning raw photos, videos, and other media into polished, ready-to-post formats. These content pieces populate the World Explorer's 3D helix timeline.

## Architecture

ENVI uses a **SwiftUI + UIKit hybrid** architecture targeting **iOS 17.0+**.

- **SwiftUI** — Library, Chat/Explore, Analytics, Profile, Export screens
- **UIKit** — Feed, Editor, custom tab bar, navigation coordinators
- **SceneKit** — 3D World Explorer helix rendering and interaction
- **SPM Dependencies** — SDWebImage, Lottie, RevenueCat, Firebase (Auth, Analytics, Crashlytics)

### Navigation

- **AppCoordinator** — Root coordinator managing auth flow (Splash → Onboarding → Sign In) and main app flow
- **MainTabBarController** — Custom UIKit tab bar controller hosting 5 tabs with a floating pill-shaped tab bar
- **OnboardingCoordinator** — Manages onboarding flow including Photos permission request

### Layer Structure

```
ENVI/
├── App/                    # App delegate, scene delegate, root coordinator
├── Core/
│   ├── Design/             # ENVITheme, ENVITypography, ENVISpacing, ThemeManager
│   ├── Extensions/         # Color+ENVI, Font+ENVI, View+Extensions
│   ├── Networking/         # APIClient, ContentPieceAssembler
│   └── Storage/            # UserDefaultsManager, PhotoLibraryManager
├── Components/             # Reusable design system components
│   ├── ENVIBadge           # Status badges
│   ├── ENVIBottomSheet     # UIKit bottom sheet presentation
│   ├── ENVIButton          # Primary/secondary/ghost button variants
│   ├── ENVICard            # Elevated card container
│   ├── ENVIChip            # Filter/action chips
│   ├── ENVIInput           # Text input with label + validation
│   ├── ENVIProgressRing    # Circular progress indicator
│   ├── ENVITabBar          # Custom floating tab bar (UIKit)
│   └── ENVIToggle          # Custom toggle switch
├── Features/
│   ├── Auth/               # Splash, onboarding, sign in
│   ├── Feed/               # Swipeable card stack, AI insight pills
│   ├── Library/            # Masonry grid, template carousel
│   ├── ChatExplore/        # Dual-mode Chat + World Explorer
│   ├── Analytics/          # KPI cards, engagement charts, content calendar
│   ├── Profile/            # Stats, connected platforms, settings
│   ├── Editor/             # Video editor with timeline + toolbar (UIKit)
│   └── Export/             # Export sheet with AI captions + progress overlay
├── Models/                 # User, ContentItem, ChatMessage, Platform, AnalyticsData
└── Navigation/             # Coordinator protocol, MainTabBarController
```

## Build Instructions

### Requirements

- **Xcode 15.0+**
- **iOS 17.0+** deployment target
- macOS 14.0+ (Sonoma) recommended

### Setup

```bash
# Clone the repository
git clone https://github.com/gerald-ica/envi-ios-v2.0.git
cd envi-ios-v2.0

# Resolve Swift Package Manager dependencies
swift package resolve

# Open in Xcode
open ENVI.xcodeproj
```

### Build & Run

1. Open `ENVI.xcodeproj` in Xcode
2. Select an iOS 17.0+ simulator or device
3. Press `⌘R` to build and run

### Bundle ID

```
com.informal.envi
```

## Fonts

The app uses two custom font families bundled in the app:

- **Space Mono** (Regular, Bold, Italic, Bold Italic) — headings, labels, navigation, buttons
- **Inter** (Regular, Medium, SemiBold, Bold, ExtraBold, Black) — body text, descriptions

Fonts are registered at app launch via `ENVITypography.registerFonts()`.

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
4. Ensure the app builds and tests pass (`swift test`)
5. Submit a pull request with a clear description

See the [Architecture wiki page](https://github.com/gerald-ica/envi-ios-v2.0/wiki/Architecture) for coding patterns and conventions.

## License

Copyright 2026 Informal. All rights reserved.
