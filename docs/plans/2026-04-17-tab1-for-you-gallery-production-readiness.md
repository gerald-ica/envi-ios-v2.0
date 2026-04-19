# Tab 1 For You/Gallery Production Readiness Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace all placeholder content in Tab 1 (`FOR YOU` + `GALLERY`) with production-ready, user-specific, camera-roll-backed, template-assembled content pieces that the user approves before editing/publishing.

**Architecture:** Use `TemplateMatchEngine` + classified `PHAsset` data as the canonical source for candidate pieces, then map those candidates into a new feed model that carries real asset identifiers, real assembled preview media, and user profile/social identity data. Remove bundle-image and mock-user fallbacks from runtime paths; keep preview-only fixtures behind explicit debug/previews flags.

**Tech Stack:** SwiftUI, UIKit/Photos (`PHAsset`), existing Lynx bridge/webview stack, `TemplateMatchEngine`, `VideoTemplateRepository`, `AuthManager` + social OAuth connections, `ApprovedMediaLibraryStore`, XCTest.

---

## Current Placeholder Inventory (Tab 1)

- `ENVI/Features/HomeFeed/ForYouGallery/ForYouGalleryViewModel.swift`
  - `contentItem(from:)` hardcodes:
    - `creatorName: "ENVI AI"`
    - `creatorHandle: "@envi"`
    - `imageName` from `FeedViewModel.imageNames` (bundled art, not user media)
    - synthetic caption/body/metrics (`Fill rate`, random reach, `"Optimal"`)
  - `loadForYouContent()` falls back to repository mock/dev data when template pipeline is empty/fails.
  - Defaults `templateRepo` to `MockVideoTemplateRepository`.
- `ENVI/Models/ContentItem.swift`
  - Data model is bundle-image-centric (`imageName`) and has `mockFeed` with random creator identities/handles.
- `ENVI/Features/HomeFeed/ForYouGallery/ForYouSwipeView.swift`
  - `SwipeableCardView.cardImage` renders `Image(imageName)` (bundled assets), no `PHAsset`/thumbnail pipeline.
- `ENVI/Features/HomeFeed/ForYouGallery/FeedDetailView.swift` and `FeedDetailAltView.swift`
  - Hero image rendering depends on bundled `imageName`; fallback is colored rectangle.
  - Detail stats are placeholders and not tied to assembled output.
- `ENVI/Features/HomeFeed/ForYouGallery/GalleryGridView.swift`
  - Gallery tiles render `Image(item.imageName)` (bundle-only path).
  - `savedTemplatesSection` uses `TemplateItem.mockTemplates`.
- `ENVI/Features/HomeFeed/Library/LibraryViewModel.swift` + `LibraryItem`
  - `LibraryItem` stores `imageName` string only; fallback image names are platform-based bundles.
  - `mockItems` and `TemplateItem.mockTemplates` are used as fallback content.
- `ENVI/Core/Data/Repositories/ContentRepository.swift`
  - `MockContentRepository.fetchFeedItems/fetchLibraryItems()` returns `ContentItem.mockFeed`.

---

### Task 1: Define a production-grade Tab 1 content model

**Files:**
- Create: `ENVI/Features/HomeFeed/ForYouGallery/ForYouContentPiece.swift`
- Modify: `ENVI/Models/ContentItem.swift`
- Modify: `ENVI/Features/HomeFeed/Library/LibraryViewModel.swift`
- Test: `ENVITests/HomeFeed/ForYouContentPieceMappingTests.swift`

**Step 1: Write failing tests**
- Add tests asserting the model can carry:
  - `templateID`, `templateName`, `platform`
  - `sourceAssetLocalIdentifiers`
  - `previewSource` (asset identifier or cached file URL)
  - `ownerDisplayName`, `ownerPrimaryHandle`
  - optional assembled output metadata (`assemblyJobID`, `assembledMediaURL`).

**Step 2: Run test to verify it fails**
- Run: `xcodebuild test -scheme ENVI -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ENVITests/ForYouContentPieceMappingTests`
- Expected: compile/test failure due to missing model.

**Step 3: Implement minimal model changes**
- Introduce a dedicated Tab 1 domain type (or extend `ContentItem`) with first-class support for:
  - real user media references (`PHAsset.localIdentifier`)
  - non-placeholder owner/social identity
  - assembled output reference.
- Keep backward compatibility adapters for existing screens.

**Step 4: Run test to verify it passes**
- Re-run the same test target and confirm pass.

**Step 5: Commit**
- `git add ...`
- `git commit -m "feat: introduce production-ready Tab 1 content piece model"`

---

### Task 2: Build user identity + social handle resolver for feed cards

**Files:**
- Create: `ENVI/Features/HomeFeed/ForYouGallery/ForYouIdentityResolver.swift`
- Modify: `ENVI/Core/Auth/AuthManager+CurrentUser.swift`
- Modify: `ENVI/Features/HomeFeed/ForYouGallery/ForYouGalleryViewModel.swift`
- Test: `ENVITests/HomeFeed/ForYouIdentityResolverTests.swift`

**Step 1: Write failing tests**
- Cases:
  - signed-in user with profile handle
  - signed-in user with connected platform handles
  - fallback to onboarding `UserDefaultsManager.userName` when auth profile is partial.

**Step 2: Run test to verify it fails**
- Run targeted tests for resolver.

**Step 3: Implement minimal resolver**
- Resolve owner identity in strict order:
  1) `AuthManager.currentUser()`
  2) connected platform handle for target platform
  3) onboarding name/handle fallback (never random mock user).

**Step 4: Run test to verify it passes**
- Re-run targeted tests.

**Step 5: Commit**
- `git add ...`
- `git commit -m "feat: resolve Tab 1 creator identity from real user profile"`

---

### Task 3: Replace For You card media path with camera-roll-backed previews

**Files:**
- Modify: `ENVI/Features/HomeFeed/ForYouGallery/ForYouGalleryViewModel.swift`
- Modify: `ENVI/Features/HomeFeed/ForYouGallery/ForYouSwipeView.swift`
- Create: `ENVI/Features/HomeFeed/ForYouGallery/ForYouAssetThumbnailView.swift`
- Test: `ENVITests/HomeFeed/ForYouGalleryViewModelTests.swift`

**Step 1: Write failing tests**
- Assert that generated For You items from populated templates:
  - carry non-empty `sourceAssetLocalIdentifiers`
  - do not use bundled `FeedViewModel.imageNames`
  - are filtered out when no eligible user assets exist.

**Step 2: Run test to verify it fails**
- Run targeted test class.

**Step 3: Implement minimal media wiring**
- In `contentItem(from:)`:
  - map first matched `FilledSlot.matchedAsset.localIdentifier` into preview source.
  - remove bundled fallback image assignment for runtime builds.
- In `ForYouSwipeView`:
  - render via new `ForYouAssetThumbnailView` (PHImageManager-backed) for asset IDs.
  - keep a debug-only visual fallback for previews/tests.

**Step 4: Run test to verify it passes**
- Re-run targeted tests and smoke test Tab 1 UI manually.

**Step 5: Commit**
- `git add ...`
- `git commit -m "feat: render For You cards from user camera-roll assets"`

---

### Task 4: Surface assembled/edited outputs (not raw placeholders)

**Files:**
- Modify: `ENVI/Features/HomeFeed/ForYouGallery/ForYouGalleryViewModel.swift`
- Modify: `ENVI/Core/Networking/ContentPieceAssembler.swift`
- Create: `ENVI/Features/HomeFeed/ForYouGallery/ForYouAssemblyCoordinator.swift`
- Modify: `ENVI/Features/HomeFeed/ForYouGallery/FeedDetailView.swift`
- Test: `ENVITests/HomeFeed/ForYouAssemblyCoordinatorTests.swift`

**Step 1: Write failing tests**
- Assert approval queue items can include assembled output references.
- Assert details view prefers assembled preview/media when available.

**Step 2: Run test to verify it fails**
- Run targeted tests.

**Step 3: Implement minimal assembly integration**
- For each top-ranked populated template, enqueue/resolve an assembly job that produces preview-ready output.
- Attach assembly metadata to feed cards.
- In detail views, show assembled result first; if unavailable, show matched camera-roll preview (never random bundle art).

**Step 4: Run test to verify it passes**
- Re-run tests and manual in-app verification.

**Step 5: Commit**
- `git add ...`
- `git commit -m "feat: wire template-assembled outputs into Tab 1 approval flow"`

---

### Task 5: Make Gallery production-ready with approved real media

**Files:**
- Modify: `ENVI/Core/Storage/ApprovedMediaLibraryStore.swift`
- Modify: `ENVI/Features/HomeFeed/Library/LibraryViewModel.swift`
- Modify: `ENVI/Features/HomeFeed/ForYouGallery/GalleryGridView.swift`
- Create: `ENVI/Features/HomeFeed/ForYouGallery/GalleryAssetThumbnailView.swift`
- Test: `ENVITests/HomeFeed/ApprovedMediaLibraryStoreTests.swift`

**Step 1: Write failing tests**
- Assert approved items persist with real media references (asset IDs or assembled URLs), not only image names.
- Assert rehydrate path restores media source and title correctly.

**Step 2: Run test to verify it fails**
- Run targeted tests.

**Step 3: Implement minimal gallery migration**
- Extend stored item schema to include media source type + identifier.
- Add migration for old `imageName`-only records.
- Update gallery item renderer to load from media source first.

**Step 4: Run test to verify it passes**
- Re-run tests and manual app relaunch persistence check.

**Step 5: Commit**
- `git add ...`
- `git commit -m "feat: persist and render approved Gallery items from real user media"`

---

### Task 6: Remove runtime mock/template placeholders from Tab 1 path

**Files:**
- Modify: `ENVI/Features/HomeFeed/ForYouGallery/ForYouGalleryViewModel.swift`
- Modify: `ENVI/Features/HomeFeed/ForYouGallery/GalleryGridView.swift`
- Modify: `ENVI/Core/Data/Repositories/ContentRepository.swift`
- Modify: `ENVI/Features/HomeFeed/Library/LibraryViewModel.swift`
- Test: `ENVITests/HomeFeed/ForYouProductionGuardrailsTests.swift`

**Step 1: Write failing tests**
- Assert Tab 1 runtime path in production/dev does not emit:
  - `ContentItem.mockFeed`
  - `TemplateItem.mockTemplates`
  - random creator handles/names.

**Step 2: Run test to verify it fails**
- Run guardrail tests.

**Step 3: Implement minimal guardrails**
- Gate all mock fallbacks behind explicit preview/test flags.
- Introduce user-facing empty states when no classified assets or no assembled outputs are available.

**Step 4: Run test to verify it passes**
- Re-run tests.

**Step 5: Commit**
- `git add ...`
- `git commit -m "chore: remove Tab 1 runtime placeholder fallbacks"`

---

### Task 7: Validation, telemetry, and rollout safety

**Files:**
- Modify: `ENVI/Core/Telemetry/TelemetryManager.swift`
- Modify: `ENVI/Features/HomeFeed/ForYouGallery/ForYouGalleryViewModel.swift`
- Modify: `ENVI/Features/HomeFeed/ForYouGallery/ForYouSwipeView.swift`
- Test: `ENVITests/HomeFeed/ForYouTelemetryTests.swift`

**Step 1: Write failing tests**
- Assert emitted events for:
  - template-populated card shown
  - assembled preview available/missing
  - approve/disapprove with source type.

**Step 2: Run test to verify it fails**
- Run telemetry tests.

**Step 3: Implement telemetry + safeguards**
- Add counters for placeholder regressions:
  - number of cards with bundle image source
  - number of cards with non-user handle.
- Add assertion/log hooks for debug builds.

**Step 4: Run test to verify it passes**
- Re-run telemetry tests + full HomeFeed smoke tests.

**Step 5: Commit**
- `git add ...`
- `git commit -m "chore: add Tab 1 production-readiness telemetry and safeguards"`

---

## End-to-End Verification Checklist

- Run unit tests touched above.
- Run:
  - `xcodebuild test -scheme ENVI -destination 'platform=iOS Simulator,name=iPhone 16'`
- Manual QA:
  - On a signed-in account with photo access + connected social accounts.
  - Confirm `FOR YOU` cards use camera-roll media, user identity, and non-placeholder text.
  - Approve items and confirm `GALLERY` shows the same real assets after app relaunch.
  - Open detail view and confirm assembled preview/media is prioritized.

## Release Strategy

- Ship behind a feature flag (`tab1ProductionContentPipeline`) for staged rollout.
- Stage 1 (internal): 100% staff, monitor placeholder guardrail metrics.
- Stage 2 (beta): 10% users, verify no regression in card load latency.
- Stage 3: 100% after 48h stable metrics.
