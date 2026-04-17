# Phase 19 — Plan 01 — Summary

**Status:** Complete
**Date:** 2026-04-17

## What shipped

Removed the "repo-in-view" anti-pattern from the 3 outlier views. Each view was holding `private let repository = SomeRepositoryProvider.shared.repository` as a view-level property, which defeats testability (can't inject a fake repo without subclassing a View) and left loading/error states ad-hoc. Every other feature group in the app uses a ViewModel; these were the outliers.

### New ViewModels
- `ENVI/Features/Modals/Admin/SystemHealthViewModel.swift` — owns `[SystemHealthMetric]`, `overallStatus`, `healthyCount` + `load()`.
- `ENVI/Features/Modals/Enterprise/SSOConfigViewModel.swift` — owns `SSOConfig` + `SCIMConfig` state, `load()`, `save()`, `addMetadata(key:value:)`.
- `ENVI/Features/Modals/Enterprise/ContractManagerViewModel.swift` — owns `[EnterpriseContract]` + `[ComplianceCertification]`, `totalSeats` / `activeCount` / `renewalCount` derived.

All three follow the house pattern: `@MainActor final class`, `@Published` state, `init(repository: SomeRepository? = nil)` with a default resolving from the canonical provider, `load()` async method, `errorMessage` surface.

### Views updated
- `SystemHealthView` — `@StateObject var viewModel`, `.task { await viewModel.load() }`, `ENVILoadingState` + `ENVIErrorBanner` surfaces.
- `SSOConfigView` — same treatment. Domain/SCIM toggles bind directly to the VM (`$viewModel.config.domain` etc.). The `newMetaKey` / `newMetaValue` fields stay as local `@State` in the view (transient input buffer) but commit via `viewModel.addMetadata(...)`.
- `ContractManagerView` — same treatment; removed derived-count inline arithmetic in favor of VM-computed properties.

### Tests
- `ENVITests/Phase19Plan01RepoInViewRefactorTests.swift` — 9 tests total (3 per VM: default state empty, load populates from repo, error sets errorMessage).

### Project
- Added the new test file to `project.yml` ENVITests sources.
- Also took the opportunity to reconcile project.yml drift from Phase 17/18: added `GrowthViewModelTests`, `SupportViewModelTests`, `EducationViewModelTests`, `FeedDetailBookmarkTests`, `TemplateTabActionsTests` to project.yml so XcodeGen is the single source of truth again.

## Verification
- `xcodebuild -project ENVI.xcodeproj -scheme ENVI ... build` → `BUILD SUCCEEDED`
- 3 VMs compile, 3 views compile, 9 new tests compile.
- Behavior unchanged: views still .task-load via the VM, loading state still surfaced, save path preserved for SSO.

## Next
`.planning/phases/19-p4-hygiene/19-02-PLAN.md` — provider standardization + Benchmark fallback.
