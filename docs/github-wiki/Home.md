# ENVI - AI-Native Content Operating System

**Product:** ENVI is a content creation and management platform for iOS. It assembles and edits content pieces from the user's camera roll -- photos, videos, carousels, stories, and reels -- and presents them in an interactive 3D content library. Powered by AI, it provides smart insights, automated editing suggestions, optimal posting times, and engagement analytics across social platforms.

**Main repository:** [gerald-ica/envi-ios-v2.0](https://github.com/gerald-ica/envi-ios-v2.0)

**Document status**

| Field | Value |
|-------|--------|
| **Wiki last updated** | 2026-04-03 UTC |
| **Source of truth** | Main repo `README.md`, `ENVI/` Swift sources, `dataconnect/` |
| **Changelog** | Main repo `docs/WIKI_CHANGELOG.md` |

## Overview

ENVI is an AI-native content operating system for creators, teams, and agencies. It spans 28+ feature domains covering the full content lifecycle: ideation, creation, editing, scheduling, publishing, analytics, and monetization. The iOS client communicates with a Firebase Auth + Data Connect backend through a typed API facade with protocol-backed repositories.

### Key capabilities

- **World Explorer** -- 3D helix timeline rendered in SceneKit with ~1600 content nodes, touch orbit, time scrubbing, and zoom levels
- **AI Engine (ENVI Brain + Oracle)** -- On-device synthesis, caption generation, script editing, hook libraries, visual AI editing, and style transfer
- **Content Editor** -- AVFoundation-based video/photo editing with crop, filter, speed, rotate, color grading, text overlays, and audio mixer
- **Multi-Platform Publishing** -- Scheduling queue, recurring posts, distribution rules, and cross-platform status reconciliation
- **Analytics Suite** -- Performance reports, audience demographics, benchmarks, trend intelligence, A/B experiments, and retention cohorts
- **Monetization** -- RevenueCat-powered Aura subscription, billing, commerce offers, and marketplace UGC

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

- **Stack:** SwiftUI + UIKit hybrid, SceneKit (World Explorer), iOS **17.0+**, Xcode **15+**. SPM dependencies: SDWebImage, Lottie, RevenueCat.
- **Navigation:** `AppCoordinator` -> Splash / Onboarding / Sign-in -> `MainTabBarController` (5 tabs: Feed, Library, Chat/Explore, Analytics, Profile).
- **Data layer:** Protocol-backed repositories with Mock -> API implementations. Firebase Auth for identity. Typed `APIClient` with retry policy and auth token injection.
- **Backend (in repo):** Firebase Data Connect schema + connectors under `dataconnect/`. Deploy via Firebase CLI.
- **Monetization:** RevenueCat with **Aura** entitlement; paywall and Customer Center SwiftUI views.
- **AI:** ENVI Brain on-device synthesis + Oracle API fallback for server-side AI (caption, script, visual editing, ideation).
- **Feature domains:** 28+ domains implemented across auth, content, AI, analytics, publishing, collaboration, teams, commerce, and more.
- **Environments:** `dev` / `staging` / `prod` configuration matrix with runtime config source.

Use the sidebar for navigation. To refresh this wiki from the codebase, follow the instructions in `docs/github-wiki/SYNC-TO-GITHUB-WIKI.md`.
