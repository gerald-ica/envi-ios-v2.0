# ENVI iOS v2.0

**Content creation and management platform for iOS.**

ENVI assembles and edits content pieces from the user's camera roll — photos, videos, carousels, stories, and reels — and presents them in an interactive 3D content library. Powered by AI, it provides smart insights, automated editing suggestions, optimal posting times, and engagement analytics across social platforms.

## Features

- **World Explorer** — 3D content library rendered as a helix timeline using SceneKit, displaying the user's content pieces in an immersive, navigable space
- **ENVI AI Chat** — Conversational AI for content insights, editing suggestions, and creative direction
- **Content Analytics** — KPI cards, engagement charts, content calendar, and performance tracking
- **Content Editor** — Video and photo editor with timeline, toolbar, and AI-assisted editing
- **Social Platform Integration** — Connect and manage multiple social media platforms from one place

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
- **SPM Dependencies** — SDWebImage for image loading, Lottie for animations

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
git clone https://github.com/gerald-ica/envi-ios.git
cd envi-ios

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

Full engineering documentation (architecture, flows, APIs, Data Connect, AI, subscriptions, roadmap) lives in **`docs/github-wiki/`** as Markdown you can sync to the repo’s [GitHub Wiki](https://github.com/gerald-ica/envi-ios-v2.0/wiki). See **`docs/github-wiki/SYNC-TO-GITHUB-WIKI.md`** for publish steps and **`docs/WIKI_CHANGELOG.md`** for dated updates.

## License

Copyright © 2026 Informal. All rights reserved.
