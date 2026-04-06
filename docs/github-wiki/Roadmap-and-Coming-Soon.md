# Roadmap & coming soon

**Last updated:** 2026-04-03 UTC

This page lists **known gaps** and **intended next passes** inferred from code comments and placeholder UX. Treat as engineering backlog, not a committed product roadmap.

## Completed areas (previously placeholder/stub)

| Area | Previous state | Current state |
|------|----------------|---------------|
| **REST API** | `APIClient.mockRequest` threw `notImplemented` | Typed `APIClient` with auth token injection and retry policy |
| **Content assembly** | Queue without upload | PHAsset-backed assembler with real resolution |
| **Feed search** | Alert placeholder | Search implemented |
| **Feed notifications** | Alert placeholder | Notifications center implemented |
| **Feed Explore** | Placeholder label | Explore grid implemented |
| **Library FAB** | Alert placeholder | PHPicker integration for media import |
| **Editor tools** | Alert placeholder | Crop, filter, speed, rotate with AVFoundation |
| **Photo library** | Basic fetch stub | PhotoLibraryManager change observer + approved media persistence |
| **Analytics** | `AnalyticsData.mock` | Retention cohorts, source attribution, creator growth analytics |
| **AI subsystems** | Mock engagement / trends | Oracle API fallback path + production annotations |
| **Social OAuth** | Not started | All 6 platforms with token lifecycle |

## Remaining placeholder areas

| Area | Current state | Intended direction |
|------|---------------|-------------------|
| **Chat** | Mock threads + partial Brain | LLM backend, durable threads |
| **World Explorer count** | ~1600 / 2000 placeholder nodes | Match real library size |
| **Helix textures** | Placeholder image generation | User / server-provided thumbnails |

## Backend / infra

| Item | Status |
|------|--------|
| **`firebase.json`** | Added with Data Connect deploy runbook |
| **iOS ↔ Firebase** | Firebase Auth, Analytics, Crashlytics, Core declared in `Package.swift` |
| **`GetTemplateDetails` / `CreateDemoData` PUBLIC** | Security review before production |

## How this page stays current

1. Grep the codebase for: `placeholder`, `stub`, `not wired`, `mock`, `not implemented`, `next pass`.
2. Update this table and **`docs/WIKI_CHANGELOG.md`** with **UTC date/time**.

**Last grep-based audit:** 2026-04-03 UTC.
