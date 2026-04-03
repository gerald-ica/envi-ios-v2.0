# Features & requirements

**Last updated:** 2026-04-03 UTC

This page maps **product intent** (README + code) to **implementation status**.

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
| Conversational UI | **Implemented** | Enhanced chat + legacy chat files |
| Thread / typing simulation | **Implemented** | `EnhancedChatViewModel` |
| Real LLM backend | **Not implemented** | Mock threads + optional `ENVIBrain` local synthesis path |
| Voice UI | **Shell** | Timer / UI present; verify capture pipeline |

## Content analytics

| Requirement | Status | Notes |
|-------------|--------|--------|
| KPI / charts / calendar UI | **Implemented** | SwiftUI components |
| Live platform data | **Not implemented** | `AnalyticsData.mock` |

## Content editor

| Requirement | Status | Notes |
|-------------|--------|--------|
| Timeline + toolbar shell | **Implemented** | UIKit |
| Real editing tools | **Placeholder** | Alerts in `EditorViewController` |

## Social platform integration

| Requirement | Status | Notes |
|-------------|--------|--------|
| Model types (`Platform`, connections) | **Implemented** | Mock user in Profile |
| OAuth / API posting | **Not implemented** | No network layer |

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
| Real authentication | **Verify** | Sign-in UI present; token/session storage TBD |

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
