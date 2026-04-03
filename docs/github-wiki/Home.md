# ENVI iOS v2.0 — Wiki home

**Product:** ENVI — content creation and management for iOS. Assembles and edits content from the camera roll; 3D content library (World Explorer); AI chat; analytics; editor; social platform hooks.

**Main repository:** [gerald-ica/envi-ios-v2.0](https://github.com/gerald-ica/envi-ios-v2.0)

**Document status**

| Field | Value |
|-------|--------|
| **Wiki page last updated** | 2026-04-03 UTC |
| **Source of truth** | Main repo `README.md`, `ENVI/` Swift sources, `dataconnect/` |
| **Changelog** | Main repo `docs/WIKI_CHANGELOG.md` |

## Quick links

| Topic | Page |
|--------|------|
| How the app is structured | [Architecture](Architecture) |
| End-to-end journeys | [User flows](User-Flows) |
| What each area is supposed to do | [Features & requirements](Features-and-Requirements) |
| Persistence, auth levels, subscription gates | [Business logic & rules](Business-Logic-and-Rules) |
| Swift models vs backend schema | [Models & data](Models-and-Data) |
| REST placeholder + client integration | [APIs & networking](APIs-and-Networking) |
| GraphQL / Postgres (planned backend) | [Firebase Data Connect](Firebase-Data-Connect) |
| On-device AI orchestration | [ENVI Brain (AI)](ENVI-Brain-AI) |
| Aura entitlement & paywall | [Subscriptions (RevenueCat)](Subscriptions-RevenueCat) |
| Tokens & typography | [Design system](Design-System) |
| UI building blocks | [Components](Components) |
| Stubs, mocks, next passes | [Roadmap & coming soon](Roadmap-and-Coming-Soon) |
| Xcode / bundle / fonts | [Build & release](Build-and-Release) |
| SwiftPM & unit tests | [Testing & SPM](Testing-and-SPM) |

## Executive summary

- **Stack:** SwiftUI + UIKit hybrid, SceneKit (World Explorer), iOS **17.0+**, Xcode **15+**. SPM: SDWebImage, Lottie, RevenueCat.
- **Navigation:** `AppCoordinator` → Splash / Onboarding / Sign-in → `MainTabBarController` (5 tabs).
- **Data today:** Mostly **mock/sample** data in ViewModels; `UserDefaults` for onboarding profile; `ApprovedMediaLibraryStore` for items approved from Feed → Library; **no** Firebase SDK in the iOS target yet.
- **Backend (in repo):** Firebase **Data Connect** schema + example connector under `dataconnect/` — **not** wired to the app.
- **Monetization:** RevenueCat with **Aura** entitlement; paywall / customer center SwiftUI views.

Use the sidebar for navigation. To refresh this wiki from the codebase, follow `SYNC-TO-GITHUB-WIKI.md` in this folder (main repo: `docs/github-wiki/SYNC-TO-GITHUB-WIKI.md`).
