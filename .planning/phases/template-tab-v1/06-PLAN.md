---
phase: 06-optimization
milestone: template-tab-v1
type: execute
domain: ios-performance
depends-on: 05-template-tab-ui
---

<objective>
Optimize the full Template Tab v1 pipeline for production: batched Vision requests to hit Apple's best practices, thermal-aware scheduling so background scans don't melt users' phones, and background task budget management so iOS doesn't kill scans mid-flight.

Purpose: A feature that works on an iPhone 16 Pro but degrades an iPhone 13 to a hand warmer won't ship. This phase tunes for real-world devices.
Output: 3 optimization utilities, performance regressions test suite, and release-ready memory/battery profile.
</objective>

<execution_context>
~/.claude/get-shit-done/workflows/execute-phase.md
.planning/phases/template-tab-v1/MILESTONE.md
.planning/phases/template-tab-v1/05-SUMMARY.md
</execution_context>

<context>
@.planning/phases/template-tab-v1/MILESTONE.md
@.planning/phases/template-tab-v1/01-SUMMARY.md
@.planning/phases/template-tab-v1/05-SUMMARY.md
@ENVI/Core/Media/MediaClassifier.swift
@ENVI/Core/Media/VisionAnalysisEngine.swift
@ENVI/Core/Media/MediaScanCoordinator.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: ThermalAwareScheduler.swift — adaptive work throttling</name>
  <files>ENVI/Core/Media/ThermalAwareScheduler.swift</files>
  <action>
  Actor that all background work calls into before scheduling the next unit:
  
  ```swift
  actor ThermalAwareScheduler {
    enum WorkBudget {
      case full           // nominal thermal, process normally
      case reduced        // fair thermal, process 50% slower
      case minimal        // serious thermal, pause non-essential
      case none           // critical thermal, stop all optional work
    }
    
    var currentBudget: WorkBudget { get }  // from ProcessInfo.thermalState + powerMode
    func waitForWorkSlot() async  // suspends if budget is .none, returns when .minimal or better
    func batchSize(for work: WorkType) -> Int  // dynamically adjusts batch sizes
    func beginObserving()  // registers NotificationCenter for thermal + lowPower changes
  }
  ```
  
  Integrate into:
  - `MediaClassifier.classifyBatch()` — awaits budget before each chunk
  - `MediaScanCoordinator.scheduleBackgroundScan()` — chunk size respects batchSize
  - `EmbeddingIndex.rebuild()` — pauses if thermal serious
  
  Log thermal transitions to TelemetryManager for analytics.
  
  AVOID: polling thermalState in a loop (use NotificationCenter), silently failing when .critical (surface a UI toast via Phase 5 VM), ignoring `ProcessInfo.isLowPowerModeEnabled` (users care).
  </action>
  <verify>Unit test with mock ProcessInfo: thermalState transitions trigger budget changes correctly; waitForWorkSlot() suspends and resumes</verify>
  <done>All background work respects scheduler, UI shows "Paused due to device heat" when applicable</done>
</task>

<task type="auto">
  <name>Task 2: BatchedVisionRequests.swift — Vision request coalescing</name>
  <files>ENVI/Core/Media/BatchedVisionRequests.swift, ENVI/Core/Media/VisionAnalysisEngine.swift (modify)</files>
  <action>
  Wrap VNImageRequestHandler to run multiple request types in a **single** handler invocation — Apple's guidance is that a single handler running [classify, aesthetics, face, saliency, featureprint] is significantly faster than 5 separate handlers.
  
  ```swift
  struct BatchedVisionRequests {
    func analyze(
      image: CGImage,
      orientation: CGImagePropertyOrientation
    ) async throws -> VisionAnalysis
  }
  ```
  
  Inside: creates one VNImageRequestHandler, perform([classify, aesthetics, face, faceQuality, human, animal, saliency, featureprint, horizon]), collects results, composes into VisionAnalysis.
  
  Modify VisionAnalysisEngine to delegate to BatchedVisionRequests. Benchmark before/after: expect ~2x speedup on 100-image batch.
  
  Also: release CGImage immediately after handler completes (don't retain in Task), use `VNImageRequestHandler`'s `options: [.ciContext: sharedContext]` to reuse a Metal-backed CIContext across calls.
  
  AVOID: creating a new CIContext per image (expensive), running on the main thread (blocks UI even in background), retaining VNImageRequestHandler beyond the call.
  </action>
  <verify>Benchmark: classify 100 sample images. Before refactor: record baseline time. After: < 60% of baseline</verify>
  <done>VisionAnalysisEngine uses BatchedVisionRequests, benchmark shows 1.5x+ speedup, memory usage flat across batch</done>
</task>

<task type="auto">
  <name>Task 3: BackgroundTaskBudget.swift + telemetry + release profile</name>
  <files>ENVI/Core/Media/BackgroundTaskBudget.swift, ENVI/Core/Media/MediaScanCoordinator+BackgroundTasks.swift (modify), ENVITests/Performance/TemplateTabPerformanceTests.swift</files>
  <action>
  **BackgroundTaskBudget** — manages iOS-assigned background execution time:
  ```swift
  actor BackgroundTaskBudget {
    func remaining() -> TimeInterval   // from task.expirationHandler countdown
    func shouldCheckpoint() -> Bool    // true when remaining < 30s
    func checkpoint(lastProcessedID: String) async  // saves to UserDefaults
    func resumeFromCheckpoint() async -> String?
  }
  ```
  
  Modify `MediaScanCoordinator+BackgroundTasks.swift`: between every chunk of 10 assets, check `shouldCheckpoint()` — if true, save progress and submit next BGProcessingTaskRequest for continuation. This survives iOS killing the task.
  
  **Performance test suite**:
  - `ENVITests/Performance/TemplateTabPerformanceTests.swift`: XCTest performance tests with `measure { }` blocks
  - Baseline metrics: classifyBatch(500) < 120s, EmbeddingIndex.rebuild(500) < 8s, TemplateMatchEngine.populateAll(20, from: 500) < 1s
  - Memory: peak resident < 250MB during classification
  
  **Telemetry additions to TelemetryManager**:
  - `media_scan_started`, `media_scan_completed` (with asset count + duration)
  - `media_scan_thermal_pause`, `media_scan_thermal_resume`
  - `template_tab_opened`, `template_selected`, `template_slot_swapped`, `template_exported`
  
  AVOID: running performance tests in CI without a baseline file (flaky), logging PII in telemetry events (no asset IDs, no location), forgetting the checkpoint (cold start after iOS kill re-scans from zero = bad).
  </action>
  <verify>Run performance tests: all baselines hit. Simulate iOS task expiration via BGTaskScheduler debug menu: coordinator resumes from checkpoint</verify>
  <done>Performance baselines established, background scan survives iOS kills, telemetry events fire, no PII leakage</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>Phase 6 complete — the Template tab now plays nice with thermal limits, uses batched Vision requests for 1.5x+ speedup, and survives iOS background-task expiration via checkpointing. Performance regression tests lock in the gains.</what-built>
  <how-to-verify>
    1. Run performance tests: `xcodebuild test -scheme ENVI -only-testing:ENVITests/Performance` — all pass
    2. Profile on a physical device (iPhone 13 or older) — run classifyBatch(500) and monitor thermal state in Xcode → should not hit .serious
    3. Simulate background task expiration (Xcode debug menu) during a scan — confirm coordinator picks up where it left off on next invocation
    4. Check telemetry events appear in debug console with correct payloads, no PII
  </how-to-verify>
  <resume-signal>Type "approved" to commit + push + open PR to main</resume-signal>
</task>

</tasks>

<verification>
- [ ] `xcodebuild test -scheme ENVI -only-testing:ENVITests/Performance` passes
- [ ] Thermal scheduler actually pauses work when thermalState triggered
- [ ] Batched Vision benchmarks 1.5x+ faster than baseline
- [ ] Background task resumes from checkpoint
- [ ] Phase 6 commit pushed
- [ ] PR from feature/template-tab-v1 → main opened via `gh pr create`
</verification>

<success_criteria>
- 3 new files + 2 modified files + 1 test file
- Performance baselines locked in test suite
- Thermal-aware + checkpointable
- Telemetry wired up with no PII
- PR to main created
- All 6 phases shipped
</success_criteria>

<output>
Create `.planning/phases/template-tab-v1/06-SUMMARY.md` with perf benchmark deltas, thermal test results, commit SHA, and PR URL. Also create `.planning/phases/template-tab-v1/MILESTONE-COMPLETE.md` summarizing the entire Template Tab v1 shipping.
</output>
