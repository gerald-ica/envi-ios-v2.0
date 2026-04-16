---
milestone: template-tab-v1
branch: feature/template-tab-v1
created: 2026-04-15
decisions:
  lynx-integration: B (Lynx-in-WKWebView for dynamic template catalog)
  embedding-atlas: C (extract UMAP/HDBSCAN algorithms natively in Swift)
  scan-strategy: B+C hybrid (onboarding last-500 + background full-library + lazy rescan)
---

# Template Tab v1 — Camera-Roll-Native Content Templates

**One-liner:** Users open the Template tab and see video/photo templates already populated with their own camera roll content — ranked by how well their media matches, so the best templates are ready to export in one tap.

## Differentiation vs CapCut

CapCut shows a remote catalog of templates with generic placeholders. ENVI scans the user's camera roll first, classifies every asset with Apple's Vision framework, then matches those assets into template slots. The thumbnails users see are made from **their own photos/videos**, and each template card shows "4/4 slots filled" so users know what's ready to use right now.

## Architecture Decisions (confirmed)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Lynx integration | **B**: Lynx-in-WKWebView | Ship new templates without App Store update, isolated complexity |
| embedding-atlas | **C**: Native Swift port | Zero WebView overhead for core matching; keep atlas as optional dev tool |
| Scan strategy | **B+C hybrid** | Onboarding scans last 500 with progress; full library continues in background via BGProcessingTask; Template tab lazy-rescans on open; PHPhotoLibraryChangeObserver for incremental updates |

## Six Phases

| # | Phase | Focus | Depends On |
|---|-------|-------|------------|
| 1 | Media Intelligence Core | MediaClassifier.swift + Vision + EXIF + SwiftData cache + PHPhotoLibraryChangeObserver | — |
| 2 | Native Embedding Pipeline | Cosine similarity on VNFeaturePrint + UMAP/HDBSCAN Swift ports | Phase 1 |
| 3 | Template Engine | VideoTemplate/Slot models + TemplateMatchEngine + ranking | Phase 2 |
| 4 | Lynx-in-WKWebView Bridge | Swift↔Lynx JS bridge + manifest schema + server catalog | Phase 3 |
| 5 | Template Tab UI | SwiftUI shell + category rows + slot-fill indicators + preview + export | Phase 4 |
| 6 | Optimization | Batched Vision + thermal-aware scheduling + background budget | Phase 5 |

## Execution Protocol

1. Each phase has its own `NN-PLAN.md` in this directory
2. Phases execute sequentially (outputs feed downstream)
3. Within a phase, independent files parallelize across subagents
4. **After each phase: commit all phase work and push to `feature/template-tab-v1`** (user requirement, 2026-04-15)
5. After all phases complete: PR to main

## Repo Context

- **Repo**: `/Users/wendyly/Documents/envi-ios-v2.0`
- **Branch**: `feature/template-tab-v1`
- **Swift**: 5.9, iOS 26+
- **Existing stack**: SwiftUI + UIKit + SceneKit + Firebase (Auth/Analytics/Crashlytics) + RevenueCat + SDWebImage + Lottie
- **Existing template system**: `ENVI/Models/BrandKitModels.swift` has `ContentTemplate` (caption/metadata templates) — this milestone adds a complementary `VideoTemplate` type for camera-roll-driven media templates. They coexist, do not conflict.
- **Existing Photos pipeline**: `ENVI/Core/Storage/PhotoLibraryManager.swift` is the entry point — extend, don't replace.
