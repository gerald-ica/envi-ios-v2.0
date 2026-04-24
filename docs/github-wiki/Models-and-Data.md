# Models & data

**Last updated:** 2026-04-23 UTC

## Swift models (`ENVI/Models/`)

| File | Primary types | Role |
|------|---------------|------|
| `User.swift` | `User` | Profile; `mock` sample |
| `Platform.swift` | `SocialPlatform`, `PlatformConnection` | Connected social accounts |
| `ContentPiece.swift` | `ContentType`, `ContentPlatform`, `ContentSource`, `ContentMetrics`, `ContentPiece` | Library / World Explorer piece; `sampleLibrary`, `futurePieces`, `pastPieces` |
| `ContentItem.swift` | `ContentItem`, nested `ContentType` | **Feed** cards (`photo`, `video`, `carousel`, `textPost`) — distinct from `ContentPiece.ContentType` |
| `ContentLink.swift` | `ContentLink` | Graph edges; `sampleLinks` |
| `ContentInsight.swift` | `ContentInsight`, `InsightCategory`, `InsightDataPoint` | AI insight cards |
| `ContentPrediction.swift` | `ContentPrediction`, categories, `PredictedEngagement` | Predictions for timeline |
| `WaterfallSuggestion.swift` | `WaterfallSuggestion` | Format/platform suggestions from a `ContentPiece` |
| `ChatThread.swift` | `ChatThread`, `ThreadMetric`, `MetricTrend` | Structured thread content |
| `ChatMessage.swift` | `ChatMessage`, `DataCard` | Chat bubbles; `mockThread` |
| `AnalyticsData.swift` | `AnalyticsData`, `KPI`, `DailyMetric`, `CalendarDay` | Dashboard; `mock` |
| `LibraryItem.swift` | `LibraryItem` | Unified library / gallery item model used by HomeFeed and profile-adjacent surfaces |
| `VideoTemplateModels.swift` | `VideoTemplate`, `TemplateSlot`, `MediaRequirements`, `PopulatedTemplate` | Template definitions with 15+ filter dimensions for slot matching |

## User Self-Model layer (`ENVI/Core/USM/`)

| File | Primary types | Role |
|------|---------------|------|
| `UserSelfModel.swift` | `UserSelfModel`, `Identity`, `USMAstroBlock`, `USMPsychBlock`, `USMDynamicBlock`, `USMVisualBlock`, `USMPredictBlock`, `USMNeuroBlock`, `JSONValue` | Codable/Sendable mirror of the backend self-model schema |
| `USMCache.swift` | `USMCache`, `USMCacheRecord` | SwiftData-backed cache keyed by user + schema version |
| `USMSyncActor.swift` | `USMSyncActor`, `USMSyncError`, transport/auth protocols | Pull/push/recompute client with retry + cache-first reads |

## Backend schema (Data Connect) — different domain

Postgres-backed GraphQL tables in `dataconnect/schema/schema.gql`:

- **User** — `displayName`, `createdAt`, optional `email`, `photoUrl`, `subscriptionType`
- **Project** — belongs to User; `name`, timestamps, `description`, `lastExportedAt`
- **MediaAsset** — user-owned file metadata + URL
- **ProjectClip** — timeline clip on a project (optional `mediaAsset`)
- **Effect** — on a clip (`effectType`, `parameters` JSON string)
- **Template** — user-owned template, optional `isPublic`

**Important:** These tables model **projects / editing / assets**, not the same structs as `ContentPiece` / `ContentItem` in Swift. Integration would require mapping layers and sync strategy.

## SwiftData Models

| Model | File | Role |
|-------|------|------|
| `ClassifiedAsset` | `Core/Media/Models/ClassifiedAsset.swift` | Cached classification results -- scene labels, aesthetics score, face count, GPS, feature print hash. Indexed query fields for fast lookup. |
| `USMCacheRecord` | `Core/USM/USMCache.swift` | Cached JSON payload, block versions, payload hash, and recompute timestamp for the User Self-Model |

---

Update when adding models or migrating to shared backend DTOs.
