---
phase: 02-embedding-pipeline
milestone: template-tab-v1
type: execute
domain: ios-swift-ml
depends-on: 01-media-intelligence-core
---

<objective>
Build a native Swift embedding pipeline that turns VNFeaturePrintObservation data into clustered, visually similar groups of camera roll content — ports the algorithms from Apple's embedding-atlas (UMAP, HDBSCAN) to pure Swift, no WebView.

Purpose: Phase 3's template matching uses embeddings to find visually similar content ("more like this" slot fill) and to cluster the library into cohesive visual groups (templates prefer same-cluster content for consistency).
Output: SimilarityEngine + DimensionReducer (UMAP) + DensityClusterer (HDBSCAN) + EmbeddingIndex — all pure Swift, on-device.
</objective>

<execution_context>
~/.claude/get-shit-done/workflows/execute-phase.md
.planning/phases/template-tab-v1/MILESTONE.md
.planning/phases/template-tab-v1/01-SUMMARY.md
</execution_context>

<context>
@.planning/phases/template-tab-v1/MILESTONE.md
@.planning/phases/template-tab-v1/01-SUMMARY.md
@ENVI/Core/Media/ClassificationCache.swift
@ENVI/Core/Media/MediaClassifier.swift

**Reference material:**
- Apple's embedding-atlas: https://github.com/apple/embedding-atlas (UMAP + density clustering)
- VNFeatureprintObservation.computeDistance (built-in cosine similarity)
- Accelerate framework (BLAS vDSP for fast vector math)

**Parallelization:** Tasks 1-2 are independent (similarity vs UMAP). Task 3 (HDBSCAN) depends on Task 2's neighbor graph. Task 4 integrates all.
</context>

<tasks>

<task type="auto">
  <name>Task 1: SimilarityEngine.swift — cosine similarity + top-K search</name>
  <files>ENVI/Core/Embedding/SimilarityEngine.swift</files>
  <action>
  Actor wrapping VNFeaturePrintObservation operations + a custom k-NN index:
  - `similarity(between: Data, and: Data) -> Float` — decodes both feature prints and calls `.computeDistance(to:)` (returns distance, convert: `1 - distance`)
  - `topK(queryFeature: Data, candidates: [ClassifiedAsset], k: Int) -> [(ClassifiedAsset, Float)]` — brute force is fine for < 5000 items; use Accelerate `vDSP_distancesq` for speed
  - `findSimilar(to assetID: String, in cache: ClassificationCache, k: Int) -> [ClassifiedAsset]` — convenience
  - `buildIndex(for assets: [ClassifiedAsset]) -> EmbeddingIndex` — pre-computes matrix of L2-normalized vectors for fast batch cosine via `vDSP_mmul`
  
  AVOID: decoding VNFeaturePrintObservation repeatedly (cache decoded vectors in the index), scalar loops over vectors (use Accelerate), running on main actor for libraries > 1000.
  </action>
  <verify>Unit test: 3 clearly-similar photos + 3 dissimilar photos → topK(similar[0], k=3) returns the 2 other similar photos</verify>
  <done>Accelerate-accelerated, handles 5000 items in <500ms, correct similarity ordering</done>
</task>

<task type="auto">
  <name>Task 2: DimensionReducer.swift — UMAP port (2D/3D projection)</name>
  <files>ENVI/Core/Embedding/DimensionReducer.swift</files>
  <action>
  Port UMAP algorithm from embedding-atlas to native Swift. Implement the two stages:
  
  Stage 1: Build fuzzy simplicial complex
  - k-NN graph using Task 1's SimilarityEngine
  - Compute local connectivity ρ (distance to nearest neighbor) per point
  - Compute σ (normalization factor) per point via binary search so sum-of-memberships ≈ log2(n_neighbors)
  - Edge weights: `exp(-(max(0, d - ρ)) / σ)`
  - Symmetrize: `a + b - a*b`
  
  Stage 2: Optimize low-dim embedding
  - Initialize with spectral embedding (use `Accelerate/LAPACK` for eigendecomposition of normalized Laplacian)
  - Force-directed layout: attractive forces along edges, repulsive forces on random negative samples
  - 200 epochs default, cosine learning rate schedule
  - Output: [[Float; 2]] (2D coords per input point)
  
  API:
  ```swift
  struct DimensionReducer {
    let nNeighbors: Int = 15
    let minDist: Float = 0.1
    let nComponents: Int = 2  // 2 for UI, 3 for SceneKit integration w/ World Explorer
    func reduce(_ vectors: [[Float]]) async -> [[Float]]
  }
  ```
  
  AVOID: using Python's sklearn params blindly (Swift needs fewer iterations with Accelerate), allocating in inner loops (pre-allocate), full-matrix operations > 2000 points (use batched approach).
  </action>
  <verify>Unit test: 3 clusters of Gaussian-sampled 64-dim vectors → UMAP output preserves cluster separation (silhouette score > 0.5)</verify>
  <done>2D and 3D output, deterministic seed for reproducibility, < 2 sec for 500 points</done>
</task>

<task type="auto">
  <name>Task 3: DensityClusterer.swift — HDBSCAN port</name>
  <files>ENVI/Core/Embedding/DensityClusterer.swift</files>
  <action>
  Port HDBSCAN (Hierarchical Density-Based Spatial Clustering) — matches visually cohesive groups without pre-specifying cluster count.
  
  Algorithm stages:
  1. Compute core distance (distance to k-th nearest neighbor) per point
  2. Build mutual reachability graph: `max(core_a, core_b, dist(a,b))`
  3. Build minimum spanning tree of MR graph (Prim's or Kruskal's)
  4. Build hierarchy by removing edges in descending weight order
  5. Condense tree: collapse branches with < min_cluster_size points into their parent as "noise"
  6. Extract flat clustering via Excess of Mass method
  
  API:
  ```swift
  struct DensityClusterer {
    let minClusterSize: Int = 5
    let minSamples: Int = 3
    func cluster(_ vectors: [[Float]]) async -> [Int]  // cluster label per point, -1 = noise
  }
  ```
  
  Reuse SimilarityEngine's distance function. Reuse Accelerate for MST edge weight sorting.
  
  AVOID: custom priority queue (Swift's built-in is fine), recursive tree traversal on large libraries (iterative), forgetting that -1 is noise (don't treat it as cluster 1).
  </action>
  <verify>Unit test: 2 tight clusters + 5 noise points → clusters labeled {0, 0, 0, 1, 1, 1, -1, -1, -1, -1, -1}</verify>
  <done>Handles 5000 points in < 10s, returns cluster labels with -1 for noise, stable with repeated calls</done>
</task>

<task type="auto">
  <name>Task 4: EmbeddingIndex.swift — the public facade</name>
  <files>ENVI/Core/Embedding/EmbeddingIndex.swift</files>
  <action>
  Top-level actor that loads ClassifiedAsset feature prints and exposes everything Phase 3 needs:
  
  ```swift
  actor EmbeddingIndex {
    func rebuild(from cache: ClassificationCache) async  // called after full scan
    func findSimilar(to assetID: String, k: Int) async -> [String]  // returns asset IDs
    func clusters() async -> [String: Int]  // asset ID → cluster label
    func projection2D() async -> [String: (Float, Float)]  // asset ID → 2D coord
    func similarityMatrix(for assetIDs: [String]) async -> [[Float]]
    func saveCheckpoint() async  // persist reduced projection + cluster labels to disk
    func loadCheckpoint() async -> Bool  // fast-path: skip UMAP/HDBSCAN on app launch if library unchanged
  }
  ```
  
  Caches the expensive outputs (UMAP coords + cluster labels) to `~/Library/Application Support/EmbeddingIndex.cache` keyed by ClassificationCache content hash. Invalidate if any ClassifiedAsset updated since last checkpoint.
  
  AVOID: recomputing UMAP on every app launch (checkpoint aggressively), blocking Template tab open on UMAP rebuild (return cached + rebuild in background), letting the index grow unbounded (cap at most-recent 5000 assets by creationDate).
  </action>
  <verify>Integration test: 100 real camera roll assets → findSimilar returns reasonable results, clusters() returns 3-10 clusters, projection2D visible separation</verify>
  <done>Public API clean, checkpointing works, bounded memory, ready for Phase 3</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>Phase 2 complete — native Swift embedding pipeline. Every ClassifiedAsset now has feature-print similarity, UMAP 2D coords, and HDBSCAN cluster labels available for Phase 3's template matching.</what-built>
  <how-to-verify>
    1. Run: `xcodebuild test -scheme ENVI` — all Phase 2 tests pass
    2. Confirm: 4 new files at ENVI/Core/Embedding/ compile clean
    3. Confirm: No new SPM dependencies (pure Accelerate + Swift)
    4. Performance: 500-asset test library completes UMAP + HDBSCAN in < 5 seconds
  </how-to-verify>
  <resume-signal>Type "approved" to commit + push + proceed to Phase 3</resume-signal>
</task>

</tasks>

<verification>
- [ ] `swift build` succeeds
- [ ] All Phase 2 tests pass
- [ ] Accelerate framework linked (check via `otool -L` output has libaccelerate)
- [ ] Phase 2 commit pushed to origin/feature/template-tab-v1
</verification>

<success_criteria>
- 4 new Swift files at ENVI/Core/Embedding/
- SimilarityEngine handles 5000 assets in < 500ms
- UMAP converges on 500 assets in < 2 seconds
- HDBSCAN produces stable clusters (same input = same output)
- EmbeddingIndex checkpoints survive app restart
- Phase committed and pushed
</success_criteria>

<output>
Create `.planning/phases/template-tab-v1/02-SUMMARY.md` with algorithm tuning parameters chosen, perf numbers, and commit SHA.
</output>
