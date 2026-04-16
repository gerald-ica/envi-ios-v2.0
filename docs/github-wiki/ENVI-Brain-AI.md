# ENVI Brain (AI)

**Last updated:** 2026-04-16 UTC

## Purpose

**`ENVIBrain`** (`Core/AI/ENVIBrain.swift`) is a singleton `ObservableObject` that orchestrates **on-device** subsystems for content optimization, inspired by an “autoresearch” loop (documented at length in file header):

1. **Observe** — content library + metrics  
2. **Hypothesize** — predictions / recommendations  
3. **Execute** — user posts (outside Brain)  
4. **Measure** — outcomes vs predictions  
5. **Learn** — keep or discard hypotheses  
6. **Iterate**

## Subsystems

| Component | File | Role |
|-----------|------|------|
| `ContentAnalyzer` | `ContentAnalyzer.swift` | Library patterns; **mock** engagement breakdowns in places |
| `PredictionEngine` | `PredictionEngine.swift` | Recommendations; **mock** trends / time multipliers |
| `TrendForecaster` | `TrendForecaster.swift` | Trend opportunities; **mock** topic/signals |
| `InsightGenerator` | `InsightGenerator.swift` | User-facing insight strings |
| `ExperimentTracker` | `ExperimentTracker.swift` | Experiment log (keep/discard) |
| `ResearchLoop` | `ResearchLoop.swift` | Ties loop together |
| `ENVIBrainConfig` | `ENVIBrainConfig.swift` | Tunables |

## Published state (Brain)

Examples: `isProcessing`, `latestInsights`, `predictions`, `experimentLog`, `loopState`, `totalIterations`, `overallKeepRate`.

## Chat integration

**`EnhancedChatViewModel`:** Can call into **`ENVIBrain.shared`** for richer responses; **mock thread** dictionary remains fallback for exact-match quick actions and when Brain path does not produce a thread.

## Production expectations

Comments across AI files note **mock** data for: trend APIs, time-of-day multipliers, posting history, audio/topics, etc. Replacing mocks requires:

- Real analytics ingestion  
- Optional server-side LLM for chat  
- Secure API keys and user consent flows  

---

## Vision & Media Intelligence Pipeline

The on-device ML pipeline powers the **Template Tab** by classifying every photo-library asset through Apple Vision, metadata extraction, and embedding-based similarity — all without leaving the device.

### Core Components

| Component | File | Role |
|-----------|------|------|
| `MediaClassifier` | `Core/Media/MediaClassifier.swift` | Actor orchestrating PHAsset metadata + Vision ML + geocoding + SwiftData caching |
| `VisionAnalysisEngine` | `Core/Media/VisionAnalysisEngine.swift` | Wraps 9 Apple Vision ML requests per asset |
| `MediaMetadataExtractor` | `Core/Media/MediaMetadataExtractor.swift` | EXIF, GPS, TIFF, MakerApple metadata via ImageIO |
| `ClassificationCache` | `Core/Media/ClassificationCache.swift` | SwiftData persistent cache for classified assets |
| `ReverseGeocodeCache` | `Core/Media/ReverseGeocodeCache.swift` | CLGeocoder LRU cache for location strings |
| `MediaScanCoordinator` | `Core/Media/MediaScanCoordinator.swift` | Hybrid scan: onboarding batch + background + lazy + incremental |
| `ThermalAwareScheduler` | `Core/Media/ThermalAwareScheduler.swift` | Adaptive batch sizes per thermalState + Low Power Mode |
| `BatchedVisionRequests` | `Core/Media/BatchedVisionRequests.swift` | Single VNImageRequestHandler with shared Metal CIContext |
| `BackgroundTaskBudget` | `Core/Media/BackgroundTaskBudget.swift` | UserDefaults checkpoint for resumable background scans |

### Vision ML Requests

1. `ClassifyImageRequest` — scene/object labels
2. `CalculateImageAestheticsScoresRequest` — quality score + isUtility flag
3. `DetectFaceRectanglesRequest` — face count + bounding boxes
4. `GenerateImageSaliencyRequest` — attention heatmap
5. `GenerateFeaturePrintRequest` — 2048-dim embedding for cosine similarity
6. `RecognizeAnimalsRequest` — pet/animal detection
7. `DetectHorizonRequest` — tilt angle
8. `RecognizeDocumentsRequest` — document/receipt detection (iOS 26)
9. `DetectCameraLensSmudgeRequest` — lens quality (iOS 26)

### Embedding Pipeline

| Component | File | Role |
|-----------|------|------|
| `SimilarityEngine` | `Core/Embedding/SimilarityEngine.swift` | Accelerate vDSP cosine similarity search |
| `DimensionReducer` | `Core/Embedding/DimensionReducer.swift` | Native UMAP port (0.900 silhouette, 31ms/500pts) |
| `DensityClusterer` | `Core/Embedding/DensityClusterer.swift` | Native HDBSCAN port (0.989 silhouette, 16ms/500pts) |
| `EmbeddingIndex` | `Core/Embedding/EmbeddingIndex.swift` | JSON checkpoint + SHA-256 content-hash invalidation |

---

Update when Brain APIs stabilize or move server-side.
