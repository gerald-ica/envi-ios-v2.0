# Phase 19 — Plan 02 — Summary

**Status:** Complete
**Date:** 2026-04-17

## What shipped

### `Repositories` facade
New `@MainActor enum Repositories` in `ENVI/Core/Data/RepositoryProvider.swift` exposes a single, canonical entry point for the analytics family:

```swift
Repositories.analytics          // AnalyticsRepository
Repositories.advancedAnalytics  // AdvancedAnalyticsRepository
Repositories.benchmark          // BenchmarkRepository
```

Each property forwards to the existing `SomeRepositoryProvider.resolve()` method, so:
- Flag-aware dispatch (`FeatureFlags.shared.connectorsInsightsLive` → `FirestoreBacked…` vs `shared.repository`) is preserved.
- No ABI break for any existing caller.
- New VMs have one name to remember instead of 3 different provider enums.

### VM migration
- `AnalyticsViewModel` — `Repositories.analytics`
- `AdvancedAnalyticsViewModel` — `Repositories.advancedAnalytics`
- `BenchmarkViewModel` — `Repositories.benchmark`

### BenchmarkViewModel fallback
BenchmarkViewModel previously set `errorMessage = error.localizedDescription` on catch, with no dev-mode mock fallback. The sibling VMs (Analytics, AdvancedAnalytics) already had the dev→mock / prod→errorMessage split. BenchmarkViewModel now matches: in dev the VM populates `Benchmark.mock` / `InsightCard.mock` / `TrendSignal.mock` / `WeeklyDigest.mock` so local work stays useful; in staging/prod the VM surfaces a proper "Unable to load benchmarks right now." message.

### Tests
- `ENVITests/Phase19Plan02ProviderStandardizationTests.swift` — 4 tests:
  - `testRepositoriesAnalyticsReturnsValidInstance`
  - `testRepositoriesAdvancedAnalyticsReturnsValidInstance`
  - `testRepositoriesBenchmarkReturnsValidInstance`
  - `testBenchmarkViewModelDevFallbackOnError` — pins the new fallback path.

## Interpretation note

The plan text asked for migration to "canonical `RepositoryProvider.shared.X`". The existing `RepositoryProvider<T>` is a generic struct consumed as `SomeRepositoryProvider.shared.repository` + optional `.resolve()` — that IS the canonical pattern, already uniform across Analytics / AdvancedAnalytics / Benchmark. Rather than force a rename that would break every `SomeRepositoryProvider.shared.repository` caller across the app, I added the `Repositories` facade as an additive, forward-looking convention. Net effect matches the plan's intent: one canonical entry point, Benchmark fallback, tests pinning both.

## Verification
- `xcodebuild ... build` → `BUILD SUCCEEDED`.
- No ABI break; existing per-provider enums and `.resolve()` methods untouched.

## Next
`.planning/phases/19-p4-hygiene/19-03-PLAN.md` — orphan cleanup + chat mock gating + un-rot tests.
