# ENVI - AI-Native Content Operating System

**Product:** ENVI is a content creation and management platform for iOS. It assembles and edits content pieces from the user's camera roll -- photos, videos, carousels, stories, and reels -- and presents them in an interactive 3D content library. Powered by AI, it provides smart insights, automated editing suggestions, optimal posting times, and engagement analytics across social platforms.

**Main repository:** [gerald-ica/envi-ios-v2.0](https://github.com/gerald-ica/envi-ios-v2.0)

**Document status**

| Field | Value |
|-------|--------|
| **Wiki last updated** | 2026-05-08 UTC |
| **Source of truth** | Main repo `README.md`, `ENVI/` Swift sources, `dataconnect/` |
| **Changelog** | Main repo `docs/WIKI_CHANGELOG.md` |

## Overview

ENVI is an AI-native content operating system for creators, teams, and agencies. It spans 28+ feature domains covering the full content lifecycle: ideation, creation, editing, scheduling, publishing, analytics, and monetization. The iOS client uses Firebase Auth, a typed API client, connector broker routes, and feature-flagged USM plumbing; Firebase Data Connect artifacts remain in-repo for backend work.

### Key capabilities

- **World Explorer** -- 3D helix timeline rendered in SceneKit with ~1600 content nodes, touch orbit, time scrubbing, and zoom levels
- **Template Tab** -- Camera-roll-native templates that scan the user's Photos library with Apple Vision, classify every asset, and show templates pre-populated with the user's own content. Dynamic catalog via Lynx-in-WKWebView.
- **AI Engine (ENVI Brain + Oracle)** -- On-device synthesis, caption generation, script editing, hook libraries, visual AI editing, and style transfer
- **Content Editor** -- AVFoundation-based video/photo editing with crop, filter, speed, rotate, color grading, text overlays, and audio mixer
- **Multi-Platform Publishing** -- Scheduling queue, recurring posts, distribution rules, and cross-platform status reconciliation
- **Analytics Suite** -- Performance reports, audience demographics, benchmarks, trend intelligence, A/B experiments, and retention cohorts
- **Monetization** -- RevenueCat-powered Aura subscription, billing, commerce offers, and marketplace UGC

## Current repo state

- **Signing aligned:** `main` is configured for Informal Content Agency, Apple Developer Team `7P76H55MAW`, with bundle identifier `com.weareinformal.envi`.
- **USM merged:** PRs `#36` and `#37` are merged into `main`, bringing `UserSelfModel`, `USMCache`, `USMSyncActor`, and the 4-step USM onboarding flow into the app.
- **Local verification current:** on 2026-05-08, Swift package resolve, Functions build/tests, Xcode Debug build, Xcode simulator tests, and simulator install/launch all passed for `com.weareinformal.envi`.
- **Not production-ready yet:** the USM onboarding route is still staging-only because `OnboardingCoordinator.swift` uses a hardcoded debug user and local `mintDebugJWT()` signer.

## Quick links

| Topic | Page |
|--------|------|
| How the app is structured | [Architecture](Architecture) |
| All 28+ feature domains | [Feature Domains](Feature-Domains) |
| API endpoint contracts | [API Contracts](API-Contracts) |
| End-to-end journeys | [User Flows](User-Flows) |
| Features and implementation status | [Features & Requirements](Features-and-Requirements) |
| Business logic and rules | [Business Logic & Rules](Business-Logic-and-Rules) |
| Swift models vs backend schema | [Models & Data](Models-and-Data) |
| REST client integration | [APIs & Networking](APIs-and-Networking) |
| GraphQL / Postgres backend | [Firebase Data Connect](Firebase-Data-Connect) |
| On-device AI orchestration | [ENVI Brain (AI)](ENVI-Brain-AI) |
| Aura entitlement and paywall | [Subscriptions (RevenueCat)](Subscriptions-RevenueCat) |
| Tokens and typography | [Design System](Design-System) |
| UI building blocks | [Components](Components) |
| Roadmap and planned work | [Roadmap & Coming Soon](Roadmap-and-Coming-Soon) |
| Build setup and release | [Build & Release](Build-and-Release) |
| Development environment setup | [Getting Started](Getting-Started) |
| SwiftPM and unit tests | [Testing & SPM](Testing-and-SPM) |

## Executive summary

- **Stack:** SwiftUI + UIKit hybrid, SceneKit (World Explorer), iOS **26.0+**, Xcode **26.0+**. SPM dependencies: SDWebImage, Lottie, RevenueCat, Firebase (Auth, Analytics, Crashlytics), GoogleSignIn.
- **Navigation:** `AppCoordinator` -> Splash / Onboarding / Sign-in -> `MainTabBarController` (3 tabs: For You/Gallery, World Explorer, Profile).
- **Data layer:** Protocol-backed repositories with Mock -> API implementations. Firebase Auth for identity. Typed `APIClient` with retry policy, Firebase ID-token auth, and broker-specific clients for connector traffic.
- **Backend (in repo):** REST contracts and Firebase/Data Connect artifacts both exist. Current iOS runtime paths lean on `APIClient`, Cloud Functions broker routes, and Oracle/brain endpoints rather than a direct Data Connect client.
- **Monetization:** RevenueCat with **Aura** entitlement; paywall and Customer Center SwiftUI views.
- **AI:** ENVI Brain on-device synthesis + Oracle API fallback for server-side AI (caption, script, visual editing, ideation).
- **Feature domains:** 28+ domains implemented across auth, content, AI, analytics, publishing, collaboration, teams, commerce, and more.
- **Environments:** `dev` / `staging` / `prod` configuration matrix with runtime config source.

Use the sidebar for navigation. To refresh this wiki from the codebase, follow the instructions in `docs/github-wiki/SYNC-TO-GITHUB-WIKI.md`.
