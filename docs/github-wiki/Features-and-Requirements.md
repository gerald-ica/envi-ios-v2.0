# Features & requirements

**Last updated:** 2026-04-23 UTC

This page maps **product intent** (README + code) to **implementation status**.

## Template Tab (Camera-Roll-Native Templates)

| Requirement | Status | Notes |
|-------------|--------|--------|
| Camera roll scanning pipeline | **Implemented** | `MediaClassifier` — PHAsset + EXIF/GPS + 9 Vision ML requests per asset |
| On-device classification cache | **Implemented** | SwiftData `ClassifiedAsset` @Model with indexed query fields |
| Aesthetics scoring / utility filter | **Implemented** | `CalculateImageAestheticsScoresRequest` + `isUtility` flag filters screenshots/receipts |
| Native embedding pipeline | **Implemented** | `SimilarityEngine` (Accelerate vDSP), `DimensionReducer` (UMAP), `DensityClusterer` (HDBSCAN) |
| Embedding index with checkpointing | **Implemented** | `EmbeddingIndex` actor with JSON checkpoint + SHA-256 content-hash invalidation |
| Video template models (Codable) | **Implemented** | `VideoTemplate`, `TemplateSlot`, `MediaRequirements` with 15+ filter dimensions |
| Slot-to-asset matching engine | **Implemented** | 6 weighted scoring signals + cluster-cohesion bonus, no-duplicate constraint |
| "For You" template ranking | **Implemented** | `TemplateRanker` — fillRate * 0.5 + score * 0.3 + popularity * 0.2 |
| Lynx-in-WKWebView dynamic catalog | **Implemented** | `TemplateCatalogClient`, SHA-256 bundle verify, `SwiftLynxBridge` with rate limit + Codable validation |
| Feature flag (mock ↔ lynx) | **Implemented** | `FeatureFlags.templateCatalogSource`, Firebase Remote Config ready |
| Template Tab SwiftUI UI | **Implemented** | Header, category chips, For You grid, category rows, slot-fill indicators |
| Template card with thumbnails | **Implemented** | `TemplateCardView` — 2x2 thumb grid, PHImageManager thumbnails, context menu |
| Full-screen preview + player | **Implemented** | `TemplatePreviewView` + `TemplatePlayerView` — AVComposition for video, crossfade for photo |
| Slot swap UX | **Implemented** | Bottom sheet with alternates + PHPicker with classification quality gate |
| Onboarding scan progress | **Implemented** | `TemplateOnboardingProgressView` with progress ring + live 3x3 thumbnail mosaic |
| MainTabBarController integration | **Implemented** | 6th tab at index 2 (Feed/Library/Templates/Chat+Explore/Analytics/Profile) |
| Hybrid scan strategy | **Implemented** | Onboarding 500 + BGProcessingTask full + lazy rescan + PHPhotoLibraryChangeObserver |
| Thermal-aware scheduling | **Implemented** | `ThermalAwareScheduler` — adaptive batch sizes per thermalState + LPM |
| Batched Vision requests | **Implemented** | Single VNImageRequestHandler with shared Metal CIContext (1.5x+ speedup target) |
| Background task checkpointing | **Implemented** | `BackgroundTaskBudget` — UserDefaults resume point, survives iOS task kills |
| iOS 26 Vision exclusives | **Implemented** | `RecognizeDocumentsRequest`, `DetectCameraLensSmudgeRequest` |
| Performance regression tests | **Implemented** | classify(500)<120s, embedRebuild(500)<8s, match(20×500)<1s, RSS<250MB |
| Telemetry (10 events, no PII) | **Implemented** | media_scan_*, template_*, embedding_index_rebuilt via TelemetryManager |


## World Explorer (3D helix)

| Requirement | Status | Notes |
|-------------|--------|--------|
| 3D helix / stream of content pieces | **Implemented** | SceneKit; stream + spiral modes; ~1600 nodes |
| Touch camera / orbit | **Implemented** | `allowsCameraControl` + custom camera targets |
| Filter by content type | **Implemented** | Dims non-matching types |
| Time scrub + zoom (Y/M/W/D) | **Implemented** | `ExplorerZoomLevel` |
| Tap → detail | **Implemented** | `ContentNodeView` |
| Data from user’s real library | **Partial** | Uses shared image pool + `ContentPiece.sampleLibrary`; counts are placeholders |

## ENVI AI Chat

| Requirement | Status | Notes |
|-------------|--------|--------|
| Conversational UI | **Implemented** | `ChatExploreView` + `EnhancedChatViewModel` |
| Thread / typing simulation | **Implemented** | Enhanced chat path active; legacy chat files are no longer the primary UI |
| Real LLM backend | **Not implemented** | Mock threads + optional `ENVIBrain` local synthesis path |
| Voice UI | **Shell** | Timer / UI present; verify capture pipeline |

## Content analytics

| Requirement | Status | Notes |
|-------------|--------|--------|
| KPI / charts / calendar UI | **Implemented** | SwiftUI components |
| Live platform data | **Partial** | Firestore-backed connector insights exist behind feature flags / connected-account prerequisites; fallback/mock paths still exist |

## Content editor

| Requirement | Status | Notes |
|-------------|--------|--------|
| Timeline + toolbar shell | **Implemented** | UIKit |
| Real editing tools | **Placeholder** | Alerts in `EditorViewController` |

## Social platform integration

| Requirement | Status | Notes |
|-------------|--------|--------|
| Model types (`Platform`, connections) | **Implemented** | Mock user in Profile |
| OAuth broker flow | **Implemented** | `SocialOAuthManager` + broker-routed provider flows with Firebase auth |
| Provider-specific publish / account routes | **Partial** | X, TikTok sandbox, LinkedIn, and Meta-family scaffolding exist; rollout depends on backend secrets, app review, and per-provider readiness |

## Feed

| Requirement | Status | Notes |
|-------------|--------|--------|
| Card stack / insights UI | **Implemented** | Mock `ContentItem` |
| Explore feed | **Placeholder** | Copy only |
| Search / notifications | **Placeholder** | Alerts |

## Library

| Requirement | Status | Notes |
|-------------|--------|--------|
| Grid + templates | **Implemented** | Mock + approved items |
| Import / create | **Not wired** | FAB alert |

## Export

| Requirement | Status | Notes |
|-------------|--------|--------|
| Export sheet + progress UI | **Implemented** | Review `ExportComposer` for backend |

## Onboarding & auth

| Requirement | Status | Notes |
|-------------|--------|--------|
| Multi-step onboarding | **Implemented** | Persists to UserDefaults |
| Photos permission | **Implemented** | `PhotoLibraryManager` |
| Real authentication | **Implemented** | Firebase email / Apple / Google + anonymous bootstrap for pre-auth connector flows |
| USM schema/cache/sync layer | **Implemented** | `UserSelfModel`, `USMCache`, `USMSyncActor` merged in PR #36 |
| USM onboarding flow | **Implemented behind flags** | PR #37 merged; still staging-scaffolded and not release-ready because onboarding auth exchange is hardcoded in `OnboardingCoordinator.swift` |

## Subscriptions

| Requirement | Status | Notes |
|-------------|--------|--------|
| RevenueCat configure | **Implemented** | App launch |
| Aura entitlement | **Implemented** | `PurchaseManager.isAuraActive` |
| Paywall / customer center | **Implemented** | SwiftUI views |

## Firebase Data Connect (backend)

| Requirement | Status | Notes |
|-------------|--------|--------|
| Schema + example connector | **In repo** | `dataconnect/` |
| iOS client | **Not integrated** | No Firebase SDK in app |

---

For gaps and planned work, see [Roadmap & coming soon](Roadmap-and-Coming-Soon).
