# API Contracts

**Last updated:** 2026-04-03 UTC

All API endpoints are consumed through the typed `APIClient` facade. The base URL pattern is `https://api.envi.app/v1/`. Each repository defines its endpoints as string paths passed to `apiClient.request()` or `apiClient.requestVoid()`.

## Content and Feed

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `feed` | GET | No | `ContentRepository` |
| `library` | GET | No | `ContentRepository` |
| `planning/content-plan` | GET | Yes | `ContentRepository` |
| `planning/content-plan` | POST | Yes | `ContentRepository` |
| `planning/content-plan/{id}` | PUT | Yes | `ContentRepository` |
| `planning/content-plan/{id}` | DELETE | Yes | `ContentRepository` |
| `planning/content-plan/reorder` | POST | Yes | `ContentRepository` |
| `templates/{id}/duplicate` | POST | Yes | `ContentRepository` |
| `templates/{id}` | DELETE | Yes | `ContentRepository` |

## Planning and Calendar

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `planning/calendar?start=&end=` | GET | Yes | `CalendarRepository` |
| `planning/calendar/{id}/reschedule` | POST | Yes | `CalendarRepository` |
| `planning/best-times` | GET | Yes | `CalendarRepository` |
| `planning/gaps?start=&end=` | GET | Yes | `CalendarRepository` |
| `planning/holidays?start=&end=` | GET | Yes | `CalendarRepository` |
| `planning/streak` | GET | Yes | `CalendarRepository` |

## Scheduling and Publishing

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `scheduling/posts?start=&end=` | GET | Yes | `SchedulingRepository` |
| `scheduling/posts` | POST | Yes | `SchedulingRepository` |
| `scheduling/posts/{id}` | PUT | Yes | `SchedulingRepository` |
| `scheduling/posts/{id}/cancel` | POST | Yes | `SchedulingRepository` |
| `scheduling/queue` | GET | Yes | `SchedulingRepository` |
| `scheduling/posts/{id}/results` | GET | Yes | `SchedulingRepository` |
| `scheduling/posts/{id}/retry` | POST | Yes | `SchedulingRepository` |
| `scheduling/recurring` | GET | Yes | `SchedulingRepository` |
| `scheduling/recurring/{id}` | DELETE | Yes | `SchedulingRepository` |
| `scheduling/recurring` | POST | Yes | `SchedulingRepository` |
| `scheduling/distribution` | GET | Yes | `SchedulingRepository` |
| `scheduling/distribution/{id}` | PUT | Yes | `SchedulingRepository` |

## Digital Asset Management (DAM)

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `dam/folders` | GET | Yes | `LibraryDAMRepository` |
| `dam/folders` | POST | Yes | `LibraryDAMRepository` |
| `dam/folders/{id}` | PATCH | Yes | `LibraryDAMRepository` |
| `dam/folders/{id}` | DELETE | Yes | `LibraryDAMRepository` |
| `dam/folders/{id}/pin` | PATCH | Yes | `LibraryDAMRepository` |
| `dam/collections` | GET | Yes | `LibraryDAMRepository` |
| `dam/collections` | POST | Yes | `LibraryDAMRepository` |
| `dam/collections/{id}` | DELETE | Yes | `LibraryDAMRepository` |
| `dam/assets/{id}/versions` | GET | Yes | `LibraryDAMRepository` |
| `dam/assets/{id}/rights` | GET | Yes | `LibraryDAMRepository` |
| `dam/storage/quota` | GET | Yes | `LibraryDAMRepository` |
| `dam/assets/{id}/readiness` | POST | Yes | `LibraryDAMRepository` |
| `dam/assets/archive` | POST | Yes | `LibraryDAMRepository` |
| `dam/assets/restore` | POST | Yes | `LibraryDAMRepository` |
| `dam/assets/bulk` | POST | Yes | `LibraryDAMRepository` |

## Analytics

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `analytics/dashboard` | GET | Yes | `AnalyticsRepository` |
| `analytics/growth` | GET | Yes | `AnalyticsRepository` |
| `analytics/cohorts` | GET | Yes | `AnalyticsRepository` |
| `analytics/attribution` | GET | Yes | `AnalyticsRepository` |
| `analytics/reports` | GET | Yes | `AdvancedAnalyticsRepository` |
| `analytics/audience` | GET | Yes | `AdvancedAnalyticsRepository` |
| `analytics/content-performance` | GET | Yes | `AdvancedAnalyticsRepository` |
| `analytics/post-times` | GET | Yes | `AdvancedAnalyticsRepository` |
| `analytics/funnel` | GET | Yes | `AdvancedAnalyticsRepository` |
| `analytics/compare` | GET | Yes | `AdvancedAnalyticsRepository` |
| `analytics/benchmarks` | GET | Yes | `BenchmarkRepository` |
| `analytics/insights` | GET | Yes | `BenchmarkRepository` |
| `analytics/trends` | GET | Yes | `BenchmarkRepository` |
| `analytics/weekly-digest` | GET | Yes | `BenchmarkRepository` |

## AI - Ideation

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `ai/ideation/generate` | POST | Yes | `IdeationRepository` |
| `ai/trends` | GET | Yes | `IdeationRepository` |
| `ai/competitors?handle=` | GET | Yes | `IdeationRepository` |
| `ai/keywords?niche=` | GET | Yes | `IdeationRepository` |
| `ai/boards` | GET | Yes | `IdeationRepository` |
| `ai/boards/{boardID}/ideas/{ideaID}` | PUT | Yes | `IdeationRepository` |
| `ai/boards/{boardID}/ideas/{ideaID}/column` | PATCH | Yes | `IdeationRepository` |

## AI - Writing

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `ai/writing/caption` | POST | Yes | `AIWritingRepository` |
| `ai/writing/script` | POST | Yes | `AIWritingRepository` |
| `ai/writing/hooks` | POST | Yes | `AIWritingRepository` |
| `ai/writing/rephrase` | POST | Yes | `AIWritingRepository` |
| `ai/writing/thread` | POST | Yes | `AIWritingRepository` |
| `ai/writing/hashtags` | POST | Yes | `AIWritingRepository` |

## AI - Visual

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `ai/visual/edit` | POST | Yes | `AIVisualRepository` |
| `ai/visual/history` | GET | Yes | `AIVisualRepository` |
| `ai/visual/styles` | GET | Yes | `AIVisualRepository` |
| `ai/visual/generate` | POST | Yes | `AIVisualRepository` |

## Brand Kits and Templates

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `brand-kits` | GET | Yes | `BrandKitRepository` |
| `brand-kits` | POST | Yes | `BrandKitRepository` |
| `brand-kits/{id}` | PUT | Yes | `BrandKitRepository` |
| `brand-kits/{id}` | DELETE | Yes | `BrandKitRepository` |
| `brand-kits/{id}/caption-style-guide` | GET | Yes | `BrandKitRepository` |
| `content-templates` | GET | Yes | `BrandKitRepository` |
| `content-templates/{id}/duplicate` | POST | Yes | `BrandKitRepository` |
| `content-templates/{id}` | DELETE | Yes | `BrandKitRepository` |

## Metadata and Tags

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `metadata/tags` | GET | Yes | `MetadataRepository` |
| `metadata/tags` | POST | Yes | `MetadataRepository` |
| `metadata/tags/{id}` | PUT | Yes | `MetadataRepository` |
| `metadata/tags/{id}` | DELETE | Yes | `MetadataRepository` |
| `metadata/auto-generate` | POST | Yes | `MetadataRepository` |
| `metadata/suggestions?q=` | GET | Yes | `MetadataRepository` |
| `metadata/completeness/{assetID}` | GET | Yes | `MetadataRepository` |
| `metadata/clusters` | GET | Yes | `MetadataRepository` |
| `metadata/tags/batch` | POST | Yes | `MetadataRepository` |

## Notifications and Automation

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `notifications/` | GET | Yes | `NotificationRepository` |
| `notifications/read` | POST | Yes | `NotificationRepository` |
| `automations/rules` | GET | Yes | `NotificationRepository` |
| `automations/rules` | POST | Yes | `NotificationRepository` |
| `automations/rules/{id}` | PUT | Yes | `NotificationRepository` |
| `automations/reminders` | GET | Yes | `NotificationRepository` |
| `automations/reminders` | POST | Yes | `NotificationRepository` |

## Search

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `search/query` | POST | Yes | `SearchRepository` |
| `search/semantic` | POST | Yes | `SearchRepository` |
| `search/visual` | POST | Yes | `SearchRepository` |
| `search/saved` | GET | Yes | `SearchRepository` |
| `search/saved` | POST | Yes | `SearchRepository` |
| `search/saved/{id}` | DELETE | Yes | `SearchRepository` |
| `search/saved/{id}/alert` | PATCH | Yes | `SearchRepository` |
| `search/facets` | POST | Yes | `SearchRepository` |
| `search/gems` | GET | Yes | `SearchRepository` |
| `search/seasonal` | GET | Yes | `SearchRepository` |

## Campaigns

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `campaigns` | GET | Yes | `CampaignRepository` |
| `campaigns` | POST | Yes | `CampaignRepository` |
| `campaigns/{id}` | PUT | Yes | `CampaignRepository` |
| `campaigns/briefs` | GET | Yes | `CampaignRepository` |
| `campaigns/requests` | GET | Yes | `CampaignRepository` |
| `campaigns/requests/{id}` | PUT | Yes | `CampaignRepository` |
| `campaigns/sprint` | GET | Yes | `CampaignRepository` |
| `campaigns/sprint/{id}` | PUT | Yes | `CampaignRepository` |

## Repurposing

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `repurposing/jobs` | GET | Yes | `RepurposingRepository` |
| `repurposing/jobs` | POST | Yes | `RepurposingRepository` |
| `repurposing/suggestions` | GET | Yes | `RepurposingRepository` |
| `repurposing/cross-post` | POST | Yes | `RepurposingRepository` |

## Experiments

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `experiments` | GET | Yes | `ExperimentRepository` |
| `experiments` | POST | Yes | `ExperimentRepository` |
| `experiments/start` | POST | Yes | `ExperimentRepository` |
| `experiments/stop` | POST | Yes | `ExperimentRepository` |
| `experiments/results` | GET | Yes | `ExperimentRepository` |

## Teams and Workspaces

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `teams/workspaces` | GET | Yes | `TeamRepository` |
| `teams/workspaces` | POST | Yes | `TeamRepository` |
| `teams/workspaces/{id}/members` | GET | Yes | `TeamRepository` |
| `teams/invites` | POST | Yes | `TeamRepository` |
| `teams/members/{id}/role` | PATCH | Yes | `TeamRepository` |
| `teams/members/{id}` | DELETE | Yes | `TeamRepository` |
| `teams/activity/{workspaceID}` | GET | Yes | `TeamRepository` |

## Collaboration

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `collaboration/reviews` | GET | Yes | `CollaborationRepository` |
| `collaboration/reviews` | POST | Yes | `CollaborationRepository` |
| `collaboration/reviews/{id}/comments` | POST | Yes | `CollaborationRepository` |
| `collaboration/comments/{id}/resolve` | POST | Yes | `CollaborationRepository` |
| `collaboration/reviews/{id}/status` | PATCH | Yes | `CollaborationRepository` |
| `collaboration/approvals` | GET | Yes | `CollaborationRepository` |
| `collaboration/share-links` | POST | Yes | `CollaborationRepository` |

## Community and CRM

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `community/inbox?filter=` | GET | Yes | `CommunityRepository` |
| `community/inbox/{id}/read` | POST | Yes | `CommunityRepository` |
| `community/inbox/{id}/flag` | POST | Yes | `CommunityRepository` |
| `community/inbox/{id}/reply` | POST | Yes | `CommunityRepository` |
| `community/contacts` | GET | Yes | `CommunityRepository` |
| `community/contacts/{id}` | GET | Yes | `CommunityRepository` |
| `community/segments` | GET | Yes | `CommunityRepository` |
| `community/segments` | POST | Yes | `CommunityRepository` |
| `community/segments/{id}` | DELETE | Yes | `CommunityRepository` |

## Commerce and Marketplace

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `commerce/offers` | GET | Yes | `CommerceRepository` |
| `commerce/offers` | POST | Yes | `CommerceRepository` |
| `commerce/link-in-bio` | GET | Yes | `CommerceRepository` |
| `commerce/link-in-bio` | PUT | Yes | `CommerceRepository` |
| `commerce/deals` | GET | Yes | `CommerceRepository` |
| `marketplace/ugc` | GET | Yes | `CommerceRepository` |

## Billing

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `billing/plans` | GET | Yes | `BillingRepository` |
| `billing/subscription` | GET | Yes | `BillingRepository` |
| `billing/usage` | GET | Yes | `BillingRepository` |
| `billing/history` | GET | Yes | `BillingRepository` |
| `billing/upgrade-prompts?feature=` | GET | Yes | `BillingRepository` |
| `billing/seats` | GET | Yes | `BillingRepository` |

## Account

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `account/sessions` | GET | Yes | `AccountRepository` |
| `account/sessions/{id}` | DELETE | Yes | `AccountRepository` |
| `account/login-history` | GET | Yes | `AccountRepository` |
| `account/data-export` | POST | Yes | `AccountRepository` |
| `account/consents` | GET | Yes | `AccountRepository` |
| `account/creator-profile` | GET | Yes | `AccountRepository` |

## Agency

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `agency/clients` | GET | Yes | `AgencyRepository` |
| `agency/clients` | POST | Yes | `AgencyRepository` |
| `agency/portals/{clientID}` | GET | Yes | `AgencyRepository` |
| `agency/portals/{id}` | PUT | Yes | `AgencyRepository` |
| `agency/reports` | POST | Yes | `AgencyRepository` |
| `agency/dashboard` | GET | Yes | `AgencyRepository` |

## Education

| Endpoint | Method | Auth | Repository |
|----------|--------|------|------------|
| `education/tutorials` | GET | Yes | `EducationRepository` |
| `education/achievements` | GET | Yes | `EducationRepository` |
| `education/learning-paths` | GET | Yes | `EducationRepository` |

## Summary

- **Total unique endpoints:** 150+
- **Repositories with API contracts:** 25
- **All endpoints require authentication** except `feed` and `library` (read-only)
- **Base URL:** `https://api.envi.app/v1/` (configured per environment)
