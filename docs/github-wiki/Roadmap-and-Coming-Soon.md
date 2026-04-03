# Roadmap & coming soon

**Last updated:** 2026-04-03 UTC

This page lists **known gaps** and **intended next passes** inferred from code comments and placeholder UX. Treat as engineering backlog, not a committed product roadmap.

## Confirmed placeholder / stub areas

| Area | What users see today | Intended direction (from code / README) |
|------|----------------------|----------------------------------------|
| **REST API** | `APIClient.mockRequest` throws `notImplemented` | Real `https://api.envi.app/v1` clients |
| **Content assembly** | `ContentPieceAssembler` queue without upload | Upload PHAsset IDs → backend AI → `ContentPiece` |
| **Feed search** | Alert: “Global search is the next feed flow” | Global search |
| **Feed notifications** | Alert: not wired | Notifications center |
| **Feed Explore** | Placeholder label | Real explore feed |
| **Library FAB** | Alert: import/create not wired | Real add/import sheet |
| **Editor tools** | Alert: placeholder UI | Wire tools into real editor stack |
| **Photo library** | Basic fetch; comment: stub | Observers, background refresh |
| **Analytics** | `AnalyticsData.mock` | Live KPIs from platforms / backend |
| **AI subsystems** | Mock engagement / trends | APIs + real user history |
| **Chat** | Mock threads + partial Brain | LLM backend, durable threads |
| **World Explorer count** | ~1600 / 2000 placeholder nodes | Match real library size |
| **Helix textures** | Placeholder image generation | User / server-provided thumbnails |

## Backend / infra

| Item | Status |
|------|--------|
| **`firebase.json`** | Missing — add for Data Connect deploy workflow |
| **iOS ↔ Data Connect** | Not started — no Firebase in app target |
| **`GetTemplateDetails` / `CreateDemoData` PUBLIC** | Security review before production |

## README vs code

- README says **iOS 17+** and hybrid architecture — wiki aligned.
- README clone URL shows `envi-ios` vs repo name `envi-ios-v2.0` — fix README separately if confusing.

## How this page stays current

1. Grep the codebase for: `placeholder`, `stub`, `not wired`, `mock`, `not implemented`, `next pass`.
2. Update this table and **`docs/WIKI_CHANGELOG.md`** with **UTC date/time**.

**Last grep-based audit:** 2026-04-03 UTC.
