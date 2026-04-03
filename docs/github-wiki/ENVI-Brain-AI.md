# ENVI Brain (AI)

**Last updated:** 2026-04-03 UTC

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

Update when Brain APIs stabilize or move server-side.
