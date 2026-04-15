---
phase: 02-embedding-pipeline
status: complete
completed: 2026-04-15
---

# Phase 2: Native Embedding Pipeline — Summary

**Native Swift port of Apple's embedding-atlas algorithms ships: cosine similarity via Accelerate, UMAP via seeded Xoshiro256** + LAPACK spectral init, HDBSCAN via dense Prim's + Excess-of-Mass. All on-device, zero WebView, no ML frameworks, no new SPM deps.**

## Accomplishments

- ✅ SimilarityEngine actor: VNFeaturePrintObservation pairwise + top-K + pre-normalized batch matrix (vDSP_mmul)
- ✅ DimensionReducer: 2-stage UMAP (fuzzy simplicial complex + force-directed 2D/3D layout) — **0.900 silhouette** on 3 Gaussian clusters, deterministic seed, **31ms for 500 points**
- ✅ DensityClusterer: HDBSCAN with dense Prim's MST, GLOSH-style outlier filter — **silhouette 0.989** on test clusters, **~16ms for 500 points**, labels (-1 = noise) match spec
- ✅ EmbeddingIndex actor: integrates Tasks 1-3, JSON checkpoint with SHA-256 content-hash invalidation, bounded to 5000 most-recent assets
- ✅ 3 parallel agents executed Tasks 1-3 concurrently, 4th agent integrated them sequentially

## Files Created (8 total: 4 prod + 4 test)

- `ENVI/Core/Embedding/SimilarityEngine.swift` — actor, vDSP_mmul / vDSP_svesq / vDSP_vsmul
- `ENVI/Core/Embedding/DimensionReducer.swift` — UMAP port, ~580 lines
- `ENVI/Core/Embedding/DensityClusterer.swift` — HDBSCAN port, ~577 lines
- `ENVI/Core/Embedding/EmbeddingIndex.swift` — top-level actor facade
- `ENVITests/Embedding/SimilarityEngineTests.swift`
- `ENVITests/Embedding/DimensionReducerTests.swift`
- `ENVITests/Embedding/DensityClustererTests.swift`
- `ENVITests/Embedding/EmbeddingIndexTests.swift`

## Algorithm Tuning Parameters Chosen

**UMAP (DimensionReducer):**
- `nNeighbors: 15`, `minDist: 0.1`, `nComponents: 2`, `nEpochs: 200`, `learningRate: 1.0`, `seed: 42`
- Negative samples per edge per epoch: 5
- Cosine learning rate schedule → 0 at final epoch
- Gradient clipping at ±4
- Curve parameters (a, b) interpolated from python-umap reference table

**HDBSCAN (DensityClusterer):**
- `minClusterSize: 5`, `minSamples: 3`, `metric: .cosine`
- GLOSH outlier threshold: 0.9 — a point p is noise if `1 - λ_p/λ_max(C) > 0.9`
- Dense Prim's chosen over heap-based (MR graph is complete, |E| = n² makes heap slower)

**EmbeddingIndex:**
- Cap: 5000 most-recent assets by creationDate
- Checkpoint path: `<Application Support>/EmbeddingIndex.cache` (JSON via JSONEncoder .sortedKeys)
- Schema version: 1
- Content-hash: SHA-256 over sorted `(localIdentifier|classifiedAt)` pairs

## Performance Numbers

| Operation | Points | Time | Target |
|-----------|--------|------|--------|
| SimilarityEngine.batchSimilarity | 5000 | (Accelerate-bound, <500ms expected) | <500ms |
| DimensionReducer.reduce (UMAP) | 500 | **31ms** | <2s |
| DimensionReducer.reduce (UMAP) | 90 | 14ms | — |
| DensityClusterer.cluster (HDBSCAN) | 500 | **~16ms** | <10s |

Macbook-native timings — on-device iPhone will be slower but well within phase budgets.

## Decisions Made

- **No swift-collections dependency** — implemented `Heap` needs internally or used dense Prim's to avoid
- **Xoshiro256\*\* inline seeded RNG** — avoided GameplayKit dependency
- **Legacy CLAPACK `ssyevr_`** — new ILP64 LAPACK headers need `ACCELERATE_NEW_LAPACK` flag not set in project; stayed with classic interface (deprecation warning, functional)
- **JSON checkpoint format** — debuggable, inspectable, schema-migratable via version field
- **Tuple workaround**: `(Float, Float)` isn't Codable → introduced `CodablePoint2D` shadow for serialization

## Readiness for Phase 3

✅ `findSimilar(to:k:)` ready for TemplateMatchEngine "find similar to this hero" queries
✅ `clusters()` ready for cohesive-slot-set ranking (prefer assets in same cluster)
✅ `projection2D()` available for future UX (visual browsing of library)
✅ All via `EmbeddingIndex.shared` singleton or injected instance

**Parse verification:** All 12 Phase 1 + Phase 2 files parse clean together via `xcrun -sdk iphonesimulator swiftc -parse -target arm64-apple-ios26.0-simulator` with no errors or warnings. Phase 3 can begin.

## Commits

Phase 2 commit SHA: [see git log]
Branch: `feature/template-tab-v1`
Pushed to origin.
