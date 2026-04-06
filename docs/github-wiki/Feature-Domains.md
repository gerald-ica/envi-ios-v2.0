# Feature Domains

**Last updated:** 2026-04-03 UTC

ENVI organizes its product surface into feature domains. Each domain maps to a Feature module, a Repository, and a set of API endpoint contracts. Below is the full domain inventory with implementation status based on committed code.

## Domain inventory

| Domain | Name | Feature Module | Repository | Status |
|--------|------|---------------|------------|--------|
| D01 | Auth and Identity | `Auth` | -- (Firebase Auth) | Implemented |
| D02 | Identity Expansion (Google, MFA, Devices) | `Auth` | `AccountRepository` | Implemented |
| D03 | Feed and For You | `Feed` | `ContentRepository` | Implemented |
| D04 | Library and Content Grid | `Library` | `ContentRepository` | Implemented |
| D05 | Chat and AI Conversation | `Chat`, `ChatExplore` | -- | Implemented |
| D06 | World Explorer (3D Helix) | `ChatExplore` | -- | Implemented |
| D07 | Analytics Dashboard | `Analytics` | `AnalyticsRepository` | Implemented |
| D08 | Content Editor (Video/Photo) | `Editor` | -- | Implemented |
| D09 | Export and Composer | `Export` | -- | Implemented |
| D10 | Profile and Settings | `Profile`, `Settings` | -- | Implemented |
| D11 | Content Planning and Calendar | `Planning` | `CalendarRepository`, `ContentRepository` | Implemented |
| D12 | Digital Asset Management (DAM) | `Library` | `LibraryDAMRepository` | Implemented |
| D13 | Brand Kits and Templates | `BrandKit` | `BrandKitRepository` | Implemented |
| D14 | AI Ideation (Trends, Competitors) | `AI` | `IdeationRepository` | Implemented |
| D15 | AI Writing (Captions, Scripts, Hooks) | `AI` | `AIWritingRepository` | Implemented |
| D16 | Scheduling and Publishing Queue | `Publishing` | `SchedulingRepository` | Implemented |
| D17 | Billing and Subscription | `Billing`, `Subscription` | `BillingRepository` | Implemented |
| D18 | Advanced Analytics (Reports, Audience) | `Analytics` | `AdvancedAnalyticsRepository` | Implemented |
| D19 | Metadata and Tag Management | `Metadata` | `MetadataRepository` | Implemented |
| D20 | Notifications and Automation | `Notifications` | `NotificationRepository` | Implemented |
| D21 | Benchmarks and Trend Intelligence | `Analytics` | `BenchmarkRepository` | Implemented |
| D22 | A/B Testing and Experiments | `Experiments` | `ExperimentRepository` | Implemented |
| D23 | Content Repurposing | `Repurposing` | `RepurposingRepository` | Implemented |
| D24 | Teams, Roles, and Workspaces | `Teams` | `TeamRepository` | Implemented |
| D25 | Collaboration and Review Workflows | `Collaboration` | `CollaborationRepository` | Implemented |
| D26 | Community Inbox | `Community` | `CommunityRepository` | Implemented |
| D27 | Audience CRM | `Community` | `CommunityRepository` | Implemented |
| D28 | Monetization and Commerce | `Commerce` | `CommerceRepository` | Implemented |
| D29 | Marketplace and UGC | `Commerce` | `CommerceRepository` | Implemented |
| D30 | Search and Discovery | `Search` | `SearchRepository` | Implemented |
| D31 | Campaigns and Sprint Board | `Campaigns` | `CampaignRepository` | Implemented |
| D32 | AI Visual Editing and Style Transfer | `AI` | `AIVisualRepository` | Implemented |
| D33 | Agency and Multi-Client Management | `Agency` | `AgencyRepository` | Implemented |
| D34 | Education and Tutorials | `Education` | `EducationRepository` | Implemented |

### Domains without dedicated repositories (handled by core modules)

| Domain | Name | Notes |
|--------|------|-------|
| D35 | Onboarding Flow | Handled by `Auth` feature module with `OnboardingCoordinator` |
| D36 | Social OAuth and Platform Connections | Implemented in Auth/OAuth layer across 6 platforms |
| D37 | Telemetry and Observability | 40+ events via telemetry baseline, no dedicated repository |
| D38 | RevenueCat and Aura Entitlements | `PurchaseManager` in Core/Purchases |
| D39 | World Explorer 3D Rendering | SceneKit `HelixSceneController` in ChatExplore |
| D40 | Design System and Components | `ENVITheme`, `ENVITypography`, `ENVISpacing` in Core/Design |

## Summary

- **Total domains:** 40
- **Implemented (committed):** 40
- **With API repositories:** 25
- **Feature modules in codebase:** 28

All 40 domains have code committed to the main branch. The 25 repository-backed domains define typed API endpoint contracts through the `APIClient` facade. The remaining domains are handled by core infrastructure modules (auth, telemetry, design system, SceneKit rendering).

## Architecture per domain

Each repository-backed domain follows this pattern:

```
Protocol (e.g., ContentRepositoryProtocol)
    -> MockContentRepository (sample data for dev)
    -> APIContentRepository (typed APIClient calls)
    -> ContentProvider (environment-aware factory)
```

ViewModels consume repository protocols and are injected with the appropriate implementation based on the active environment (`dev` = mock, `staging`/`prod` = API).
