# ENVI iOS v2 — Cleanup & Error Fix Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Fix all compilation errors, clean up code quality issues, remove debug artifacts, and standardize the codebase.

**Architecture:** iOS app (Swift, iOS 26+), XcodeGen project, Swift Package Manager dependencies.

**Scope:** 440 Swift files in `ENVI/`, project config, build artifacts.

---

## Phase 0: Fix Compilation Errors (BLOCKING)

These 2 errors prevent the project from building.

### Task 0.1: Fix `VideoTemplateCategory.iconName` missing member

**Objective:** Add `iconName` computed property to `VideoTemplateCategory` enum.

**File:**
- Modify: `ENVI/Models/VideoTemplateModels.swift:141-173`

**Problem:** `ApprovalFlowView.swift:251` references `match.category?.iconName` but the enum only has `id` and `displayName`. Other files (`MarketplaceView.swift:74`, `TemplateEditorView.swift:396`, `TemplateGalleryView.swift:196`) also use `.iconName` — so this property is expected but missing.

**Step 1: Add `iconName` property to `VideoTemplateCategory`**

After the `displayName` computed property (line 172), add:

```swift
    var iconName: String {
        switch self {
        case .grwm:          return "shirt.fill"
        case .cooking:       return "fork.knife"
        case .ootd:          return "hanger"
        case .travel:        return "airplane"
        case .fitness:       return "figure.walk"
        case .product:       return "shippingbox.fill"
        case .beauty:        return "sparkles"
        case .lifestyle:     return "house.fill"
        case .fashion:       return "bag.fill"
        case .food:          return "croissant.fill"
        case .educational:   return "book.fill"
        case .entertainment: return "film.fill"
        }
    }
```

**Step 2: Verify compile**

Run: `cd /Users/wendyly/Documents/envi-ios-v2 && xcodebuild -project ENVI.xcodeproj -scheme ENVI -destination 'generic/platform=iOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO -quiet build 2>&1 | grep 'error:'`
Expected: No `iconName` error remaining.

**Step 3: Commit**

```bash
git add ENVI/Models/VideoTemplateModels.swift
git commit -m "fix: add missing iconName property to VideoTemplateCategory enum"
```

---

### Task 0.2: Fix `TemplateMatchResult` missing `archetype` and `niche.rawValue` errors

**Objective:** Fix `ApprovalFlowView.swift` references to non-existent members.

**File:**
- Modify: `ENVI/Features/Editing/ApprovalFlowView.swift:293-300`

**Problem:** Two issues on lines 296-297:
1. `match.archetype.displayName` — `TemplateMatchResult` has no `archetype` member
2. `match.niche.rawValue` — `niche` is `String?`, not an enum, so `.rawValue` doesn't exist

**Step 1: Read current code**

```swift
// Lines 295-300 (TemplateInfoBar):
HStack {
    TagView(text: match.archetype.displayName, color: .purple)
    TagView(text: match.niche.rawValue, color: .orange)
    if let ops = match.templateNamemetadata?.operationsApplied {
        TagView(text: "\(ops.count) ops", color: .blue)
    }
}
```

**Step 2: Replace with safe references**

`TemplateMatchResult` (in `ReverseEditingPipeline.swift:109-138`) has these fields: `id`, `templateID`, `templateName`, `score`, `category`, `style`, `niche` (String?), `operationsCount`.

Replace the HStack with:

```swift
HStack {
    if let style = match.style {
        TagView(text: style, color: .purple)
    }
    if let niche = match.niche {
        TagView(text: niche, color: .orange)
    }
    TagView(text: "\(match.operationsCount) ops", color: .blue)
}
```

**Step 3: Verify compile**

Run: `cd /Users/wendyly/Documents/envi-ios-v2 && xcodebuild -project ENVI.xcodeproj -scheme ENVI -destination 'generic/platform=iOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO -quiet build 2>&1 | grep 'error:'`
Expected: No errors.

**Step 4: Commit**

```bash
git add ENVI/Features/Editing/ApprovalFlowView.swift
git commit -m "fix: replace non-existent archetype/niche.rawValue with available TemplateMatchResult fields"
```

---

### Task 0.3: Fix `ApprovalFlowView` unused `await` warnings

**Objective:** Remove unnecessary `await` on non-async expressions.

**File:**
- Modify: `ENVI/Features/Editing/ApprovalFlowView.swift:153,159`

**Step 1: Read lines 150-165**

```swift
// Around line 153 and 159 — likely:
await someNonAsyncCall()
```

**Step 2: Remove the `await` keyword** from both lines since the called functions are not async.

**Step 3: Verify**

Run: `cd /Users/wendyly/Documents/envi-ios-v2 && xcodebuild -project ENVI.xcodeproj -scheme ENVI -destination 'generic/platform=iOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO -quiet build 2>&1 | grep 'warning:'`
Expected: No `await` warnings.

**Step 4: Commit**

```bash
git add ENVI/Features/Editing/ApprovalFlowView.swift
git commit -m "fix: remove unnecessary await on non-async expressions"
```

---

## Phase 1: Remove Debug/Temporary Code (HIGH PRIORITY)

### Task 1.1: Remove debug JWT minter from production

**Objective:** Remove or guard the debug JWT minter flagged with `TODO(gerald): remove before release`.

**File:**
- Modify: `ENVI/Features/Auth/OnboardingCoordinator.swift:159,181-195`

**Problem:** Lines 159 and 181-195 contain a debug-only HS256 JWT minter that should not ship.

**Step 1: Read the code**

```swift
// Line 159:
authTokenProvider: { Self.mintDebugJWT(userId: debugUserId) }

// Lines 181-195:
/// TODO(gerald): remove before release. Debug-only HS256 JWT minter...
private static func mintDebugJWT(userId: String) -> String {
    let header = #"{"alg":"HS256","typ":"JWT"}"#
    // ... implementation
}
```

**Step 2: Replace debug JWT with proper auth flow**

If the proper Firebase-token → backend-JWT exchange endpoint exists, use it. Otherwise:
- Wrap the debug code in `#if DEBUG` so it only compiles in debug builds
- Replace line 159 with the proper auth token provider

```swift
#if DEBUG
    authTokenProvider: { Self.mintDebugJWT(userId: debugUserId) }
#else
    authTokenProvider: { /* proper auth token provider */ }
#endif
```

And add `#if DEBUG` / `#endif` around the `mintDebugJWT` function.

**Step 3: Commit**

```bash
git add ENVI/Features/Auth/OnboardingCoordinator.swift
git commit -m "fix: gate debug JWT minter behind #if DEBUG"
```

---

### Task 1.2: Replace debug `print()` statements with `Logger`

**Objective:** Replace 7 remaining `print()` calls with proper `OSLog`/`Logger` calls.

**Files:**
- `ENVI/Core/Purchases/PurchaseManager.swift:48`
- `ENVI/Core/Editing/GenerationEngine.swift:697`
- `ENVI/Features/Modals/Editor/EditorProjectManager.swift:166,175,197,213`
- `ENVI/Features/HomeFeed/Templates/SwiftLynxBridge.swift:176`

**Step 1: Add Logger import**

At the top of each affected file, add:
```swift
import os
private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.geraldwelly.envi", category: "<CategoryName>")
```

**Step 2: Replace each `print()` with appropriate logger call**

| Current | Replacement |
|---------|-------------|
| `print("Warning: ...")` | `logger.warning("...")` |
| `print("Error: ...")` | `logger.error("...")` |
| `print("...")` | `logger.info("...")` |

**Step 3: Verify compile**

**Step 4: Commit each file individually**

---

## Phase 2: Fix Unsafe Code Patterns (MEDIUM PRIORITY)

### Task 2.1: Replace force unwraps (`!`) with safe optional binding

**Objective:** Replace 29 force unwraps with `guard let`/`if let`/`??` fallbacks.

**Priority files (crash risks):**

| File | Line | Issue | Fix |
|------|------|-------|-----|
| `Core/Config/AppEnvironment.swift` | 28-32 | 3 URL force unwraps | Use `guard let URL(string:) else { fatalError("Bad config") }` or `??` with fallback |
| `Core/Storage/UserDefaultsManager.swift` | 71 | `Bundle.main.bundleIdentifier!` | `Bundle.main.bundleIdentifier ?? "unknown"` |
| `Core/Editing/GenerationEngine.swift` | 228,832 | `FileManager...first!` | `guard let url = ...first else { throw ... }` |
| `Core/Editing/GenerationEngine.swift` | 1159-1160 | `makeCommandBuffer()!`, `makeComputeCommandEncoder()!` | `guard let` with Metal error handling |
| `Core/Data/Repositories/AdminRepository.swift` | 21,31 | `.mock.first!` | Test data — guard with fatalError("No mock data") |
| `Features/HomeFeed/Templates/LynxWebViewController.swift` | 59 | `WKWebView!` IUO property | Initialize in `loadView()` properly |
| `Features/HomeFeed/Templates/TemplateTabViewModel.swift` | 91 | `AsyncStream.Continuation!` | Use optional with proper lifecycle |

**Step 1: Fix AppEnvironment.swift (highest crash risk)**

Read `ENVI/Core/Config/AppEnvironment.swift` and replace force unwraps with explicit config validation:

```swift
// Instead of:
let apiURL = URL(string: "...")!

// Use:
guard let apiURL = URL(string: "...") else {
    fatalError("Invalid API URL in configuration")
}
```

**Step 2: Fix each remaining file**

Commit each file separately with descriptive messages.

---

### Task 2.2: Replace `try!` with proper error handling

**Objective:** Fix 2 `try!` calls that can crash at runtime.

**Files:**
- `ENVI/Core/Media/MediaClassifier.swift:92`
- `ENVI/Features/Auth/OnboardingPhotosAccessView.swift:60`

**Step 1: Fix MediaClassifier**

```swift
// Before:
let cache = try! ClassificationCache(inMemory: true)

// After:
do {
    let cache = try ClassificationCache(inMemory: true)
    // use cache
} catch {
    logger.error("Failed to create classification cache: \(error)")
    // fallback behavior
}
```

**Step 2: Fix OnboardingPhotosAccessView** — same pattern.

---

### Task 2.3: Replace `as!` force cast with `as?`

**Objective:** Fix 1 force cast in `TemplatePlayerView.swift`.

**File:**
- Modify: `ENVI/Features/HomeFeed/Templates/TemplatePlayerView.swift:400`

**Step 1: Replace**

```swift
// Before:
let playerLayer = layer as! AVPlayerLayer

// After:
guard let playerLayer = layer as? AVPlayerLayer else { return }
```

---

## Phase 3: Clean Up Build Artifacts & Repo (LOW PRIORITY)

### Task 3.1: Remove stale build directories

**Objective:** Clean ~6GB of stale build artifacts.

**Directories to remove:**
- `.build/` — 4.1GB (SPM build cache)
- `build_output/` — 2.0GB (stale xcodebuild output)
- `build-device 2/` — 24KB (stale device build)
- `build/` — empty

**Step 1: Remove stale directories**

```bash
cd /Users/wendyly/Documents/envi-ios-v2
rm -rf build/ "build-device 2/" build_output/
# Don't remove .build/ — it's SPM's cache, will be cleaned by xcodebuild clean
```

**Step 2: Verify .gitignore covers these**

Check that `.gitignore` already excludes these (it does: `build/`, `build_output/`, `.build/`).

---

### Task 3.2: Clean up `.DS_Store` files

**Objective:** Remove `.DS_Store` files from the repo.

**Step 1: Remove existing .DS_Store files**

```bash
cd /Users/wendyly/Documents/envi-ios-v2
find . -name '.DS_Store' -delete
```

**Step 2: Add global gitignore rule**

```bash
# Already in .gitignore — verify it's working
git check-ignore .DS_Store
```

---

### Task 3.3: Remove or archive `.agents`, `.claude`, `.commandcode`, `.continue`, `.cursor`, `.factory`, `.kiro`, `.qwen`, `.trae`, `.windsurf`, `.remember`, `.planning` directories

**Objective:** These are AI editor config directories. Most should be `.gitignore`'d.

**Step 1: Check which are tracked by git**

```bash
cd /Users/wendyly/Documents/envi-ios-v2
git ls-files | grep '^\.' | grep -v '.git'
```

**Step 2: Add to .gitignore if not already**

Add to `.gitignore`:
```
# AI editor configs
.agents/
.claude/
.commandcode/
.continue/
.factory/
.kiro/
.qwen/
.remember/
.planning/
.windsurf/
```

Note: `.cursor/` and `.trae/` may contain project-specific config — review before ignoring.

---

## Phase 4: Resolve TODOs/FIXMEs

### Task 4.1: Audit and resolve 12 TODO/FIXME comments

**Files:**

| File | TODO | Action |
|------|------|--------|
| `Core/Config/FeatureFlags.swift:231` | `TODO(phase-4): When FirebaseRemoteConfig is added` | Create issue or implement if phase 4 is done |
| `Core/Storage/PhotoLibraryManager+MediaScan.swift:16` | `TODO(Info.plist): remember to add...` | Add the plist entry or remove TODO if done |
| `Core/Media/MediaScanCoordinator.swift:17` | `TODO(Info.plist): Add...` | Same as above |
| `Core/Media/Models/ClassifiedAsset.swift:18,48,53` | 3 TODOs for typed alias | Implement or convert to tracked issue |
| `Features/Auth/OnboardingCoordinator.swift:181` | `TODO(gerald): remove before release` | **Done in Task 1.1** |
| `Features/ChatExplore/WorldExplorer/WorldExplorerView.swift:6` | `TODO: Migrate from SceneKit → RealityKit` | Create issue, leave TODO |

**Step 1: For each TODO, determine if it's:**
- ✅ Already done → remove the TODO comment
- 🔄 Should be done now → implement
- 📋 Future work → convert to a tracked issue/GitHub issue

---

## Phase 5: Refactor Large Files (OPTIONAL, LONG-TERM)

### Task 5.1: Split files over 1000 lines

**Files to refactor:**

| Lines | File | Suggested Split |
|-------|------|----------------|
| 1,330 | `Core/Templates/ContentArchetypes/StyleModels.swift` | Split by style category |
| 1,285 | `Core/Editing/GenerationEngine.swift` | Extract Metal pipeline, prewarm, and rendering into separate files |
| 1,224 | `Core/Templates/ContentArchetypes/ContentArchetype.swift` | Split by archetype group |
| 1,203 | `Features/ChatExplore/WorldExplorer/HelixSceneController.swift` | Extract scene setup, interaction, animation |

**Note:** These are architectural refactors — do them one at a time with full test coverage.

---

## Summary

| Phase | Tasks | Impact | Effort |
|-------|-------|--------|--------|
| 0 | Fix 2 compile errors + 2 warnings | **Project builds** | 10 min |
| 1 | Remove debug JWT, replace prints | **Security + logging** | 20 min |
| 2 | Fix force unwraps, try!, as! | **Crash prevention** | 45 min |
| 3 | Clean build artifacts, DS_Store | **Repo hygiene** | 5 min |
| 4 | Resolve TODOs | **Code clarity** | 15 min |
| 5 | Refactor large files | **Maintainability** | 2-4 hours |

---

**After all phases:** Run full `xcodebuild` clean build and verify zero errors/warnings.
