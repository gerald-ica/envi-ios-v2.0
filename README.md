# ENVI

**Personalized AI Content Editor.**

Your next post is already filmed. ENVI is a personalized AI content editor for iOS that scans your camera roll, turns forgotten footage into polished, ready-to-post content, and helps you manage your social media presence across platforms. Powered by AI, it provides smart insights, automated captions, optimal posting times, and engagement analytics — all in a monochromatic, editorial design language.

## Screenshots

<!-- TODO: Add screenshots before launch -->
_Coming soon — app launches March 30th._

## Architecture

ENVI uses a **MVVM + Coordinator** pattern with a **UIKit + SwiftUI hybrid** architecture targeting **iOS 17.0+**.

### Navigation

- **AppCoordinator** — Root coordinator managing auth flow (Splash → Onboarding → Sign In) and main app flow
- **MainTabBarController** — Custom UIKit tab bar controller hosting 5 tabs with a floating pill-shaped tab bar
- **OnboardingCoordinator** — Manages the 5-step onboarding flow (Name → DOB → Location → Birthplace → Socials)

### Layer Structure

```
ENVI/
├── App/                    # App delegate, scene delegate, root coordinator
├── Core/
│   ├── Design/             # ENVITheme, ENVITypography, ENVISpacing, ThemeManager
│   ├── Extensions/         # Color+ENVI, Font+ENVI, View+Extensions
│   ├── Networking/         # APIClient
│   └── Storage/            # UserDefaultsManager
├── Components/             # Reusable design system components
│   ├── ENVIBadge           # Monochromatic status badges
│   ├── ENVIBottomSheet     # UIKit bottom sheet presentation
│   ├── ENVIButton          # Primary/secondary/ghost button variants
│   ├── ENVICard            # Elevated card container
│   ├── ENVIChip            # Filter/action chips
│   ├── ENVIInput           # Text input with label + validation
│   ├── ENVIProgressRing    # Circular progress indicator
│   ├── ENVITabBar          # Custom floating tab bar (UIKit)
│   └── ENVIToggle          # Custom toggle switch
├── Features/
│   ├── Auth/               # Splash, onboarding (5 steps), sign in
│   ├── Feed/               # Swipeable card stack, AI insight pills
│   ├── Library/            # Masonry grid, template carousel
│   ├── Chat/               # AI chat with data cards, related questions
│   ├── Analytics/          # KPI cards, engagement charts, content calendar
│   ├── Profile/            # Stats, connected platforms, settings, appearance
│   ├── Editor/             # Video editor with timeline + toolbar (UIKit)
│   └── Export/             # Export sheet with AI captions + progress overlay
├── Models/                 # User, ContentItem, ChatMessage, Platform, AnalyticsData
└── Navigation/             # Coordinator protocol, MainTabBarController
```

### Key Patterns

- **UIKit screens** (Feed, Editor) use UIKit view controllers with SwiftUI hosted views where appropriate
- **SwiftUI screens** (Library, Chat, Analytics, Profile, Export) use `@StateObject` ViewModels
- **Design tokens** are centralized in `ENVITheme`, `ENVITypography`, and `ENVISpacing`
- **ThemeManager** is a singleton `ObservableObject` managing light/dark/system appearance

## Design System

ENVI follows a **monochromatic** visual language — black, white, and neutral grays only.

### Color Palette

| Token | Dark Mode | Light Mode |
|-------|-----------|------------|
| Background | `#000000` (pure black) | `#FFFFFF` (pure white) |
| Surface Low | `#1A1A1A` | `#F4F4F4` |
| Surface High | `#2A2A2A` | `#E8E8E8` |
| Primary | `#FFFFFF` (white) | `#000000` (black) |
| Text | `#FFFFFF` | `#000000` |
| Text Secondary | `rgba(255,255,255,0.7)` | `rgba(0,0,0,0.7)` |
| Border | `rgba(255,255,255,0.12)` | `rgba(0,0,0,0.12)` |
| Accent | `#30217C` (subtle gradients only, max 20%) | `#30217C` |

### Typography

| Style | Font | Size | Case | Tracking |
|-------|------|------|------|----------|
| Display Large | Space Mono Bold | 32 | UPPERCASE | -2px |
| Display Medium | Space Mono Bold | 28 | UPPERCASE | -1.5px |
| Heading | Space Mono Bold | 22 | UPPERCASE | -1px |
| Subheading | Space Mono Regular | 17 | UPPERCASE | +0.5px |
| Body | Inter Regular | 15 | Sentence | +0.3px |
| Caption | Inter Medium | 13 | Sentence | +0.5px |
| Label | Space Mono Bold | 11 | UPPERCASE | +2.5px |
| Badge | Space Mono Bold | 10 | UPPERCASE | +2px |

### Rules

- **Headings, buttons, labels, chips, badges, navigation:** Space Mono, UPPERCASE
- **Body text, descriptions, placeholders:** Inter, sentence case
- **Icons:** SF Symbols outline variants only (no `.fill` suffixes)
- **Border radius:** 8–14px rounded rectangles (no capsule shapes)
- **No bold in body text** (Inter Regular or Medium only)
- **No italic anywhere**

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

- **Space Mono** (Regular, Bold) — headings, labels, navigation, buttons
- **Inter** (Regular, Medium, SemiBold, Bold, ExtraBold, Black) — body text, descriptions

Fonts are registered at app launch via `ENVITypography.registerFonts()`.

## License

Copyright © 2026 Informal. All rights reserved.
