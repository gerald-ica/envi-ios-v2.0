---
phase: 04-lynx-bridge
milestone: template-tab-v1
type: execute
domain: ios-webview-bridge
depends-on: 03-template-engine
---

<objective>
Integrate Lynx-in-WKWebView as a dynamic template catalog delivery mechanism — Swift hosts a Lynx surface, Lynx renders the server-delivered template catalog, Swift intercepts selections and passes them into Phase 3's TemplateMatchEngine. New templates can ship to users without App Store resubmission.

Purpose: Decision 1B. Matches CapCut's dynamic template strategy using Lynx specifically because CapCut does. Isolates complexity to one surface.
Output: LynxWebViewController + SwiftLynxBridge + TemplateCatalogClient + JSON manifest schema + local Lynx bundle resources.
</objective>

<execution_context>
~/.claude/get-shit-done/workflows/execute-phase.md
.planning/phases/template-tab-v1/MILESTONE.md
.planning/phases/template-tab-v1/03-SUMMARY.md
</execution_context>

<context>
@.planning/phases/template-tab-v1/MILESTONE.md
@.planning/phases/template-tab-v1/03-SUMMARY.md
@ENVI/Core/Data/Repositories/VideoTemplateRepository.swift
@ENVI/Core/Networking/APIClient.swift

**Lynx reference:** https://github.com/bytedance/lynx — cross-platform UI framework used by CapCut.
**Approach:** NOT native Lynx iOS SDK integration (too invasive). Instead: host Lynx runtime in WKWebView, communicate via JS messageHandlers.

**Context7 lookup required:** Before writing Lynx bridge code, use `mcp__context7__query-docs` to verify current Lynx runtime JS API. Lynx is evolving rapidly.
</context>

<tasks>

<task type="auto">
  <name>Task 1: TemplateCatalogClient.swift + manifest schema</name>
  <files>ENVI/Core/Templates/TemplateCatalogClient.swift, ENVI/Core/Templates/TemplateManifest.swift</files>
  <action>
  **TemplateManifest.swift** — defines the JSON schema for server-delivered templates:
  
  ```swift
  struct TemplateManifest: Codable {
    let version: Int              // manifest schema version
    let generatedAt: Date
    let templates: [VideoTemplate]  // reuses Phase 3's VideoTemplate
    let categories: [VideoTemplateCategory]
    let lynxBundleURL: URL?       // optional CDN URL for the Lynx render bundle
    let lynxBundleHash: String?   // integrity check
  }
  ```
  
  **TemplateCatalogClient.swift** — fetches manifests from server:
  ```swift
  actor TemplateCatalogClient: VideoTemplateRepository {
    func fetchCatalog() async throws -> [VideoTemplate]
    func fetchTrending() async throws -> [VideoTemplate]
    func fetchByCategory(_: VideoTemplateCategory) async throws -> [VideoTemplate]
    func refreshBundle() async throws  // downloads lynxBundleURL if hash changed
  }
  ```
  
  Cache manifests locally at `~/Library/Caches/template-catalog.json` with ETag/If-None-Match. Offline-first: always return cached if network fails.
  
  For Phase 4, the server endpoint is stubbed — use the existing APIClient pattern with endpoint `/v1/templates/manifest`. Backend implementation is out of scope; the client expects responses matching TemplateManifest schema.
  
  AVOID: unbounded cache growth (prune manifests > 7 days), synchronous downloads blocking UI, using URLSession.shared (use ENVI's shared APIClient for auth tokens).
  </action>
  <verify>Unit test: mock server response JSON → TemplateCatalogClient returns parsed VideoTemplates; offline mode returns cached manifest</verify>
  <done>Client implements VideoTemplateRepository, manifests cached with ETag, Phase 3's VM can swap MockRepo for this</done>
</task>

<task type="auto">
  <name>Task 2: LynxWebViewController.swift — WKWebView host</name>
  <files>ENVI/Features/Templates/LynxWebViewController.swift, ENVI/Features/Templates/LynxWebViewRepresentable.swift</files>
  <action>
  UIKit view controller hosting a WKWebView configured for Lynx runtime:
  
  - Load local HTML shell from bundle (`Resources/lynx-shell.html`) that bootstraps the Lynx runtime
  - Inject user's classified asset thumbnails as base64 blobs (or local file URLs via WKURLSchemeHandler) so Lynx can display the user's actual content in template previews
  - WKWebViewConfiguration with: `limitsNavigationsToAppBoundDomains = true`, `suppressesIncrementalRendering = false`, userContentController with registered message handlers (see Task 3)
  - Size to fill container, transparent background, disable text selection, disable long-press menus
  
  SwiftUI wrapper via `UIViewControllerRepresentable` so Phase 5's SwiftUI TemplateTabView can host it.
  
  AVOID: loading remote HTML directly (App Store rejection risk + security — always load local HTML that fetches content via message bridge), enabling JavaScript eval from user input, letting WKWebView retain the controller (weak self in message handlers).
  </action>
  <verify>Manual: launch test harness, WKWebView loads shell HTML, console logs "lynx-shell-ready" message</verify>
  <done>Controller + SwiftUI wrapper compile, shell HTML loads, message handlers registered</done>
</task>

<task type="auto">
  <name>Task 3: SwiftLynxBridge.swift — JS ↔ Swift message protocol</name>
  <files>ENVI/Features/Templates/SwiftLynxBridge.swift, ENVI/Features/Templates/Resources/lynx-shell.html</files>
  <action>
  Bidirectional bridge via `WKScriptMessageHandler`:
  
  **JS → Swift messages** (register each as separate handler for type safety):
  - `envi.templateSelected` → payload: `{ templateId: string }` → VM.select()
  - `envi.slotSwapRequested` → payload: `{ templateId, slotId }` → presents iOS photo picker, returns replacement
  - `envi.catalogReady` → Lynx tells Swift it's ready to receive catalog data
  - `envi.requestUserAssets` → payload: `{ filter?: {...} }` → Swift returns JSON array of ClassifiedAsset summaries
  - `envi.requestThumbnail` → payload: `{ assetId, size }` → Swift returns base64 JPEG
  - `envi.telemetry` → payload: `{ event, properties }` → logs to TelemetryManager
  
  **Swift → JS calls** (via `webView.evaluateJavaScript`):
  - `window.envi.setCatalog(manifestJSON)`
  - `window.envi.setUserAssets(assetsJSON)`
  - `window.envi.updateScanProgress({ done, total })`
  - `window.envi.notifyError(message)`
  
  **lynx-shell.html** (50 lines): loads Lynx runtime (vendored or CDN-with-integrity-hash), exposes `window.envi` global, posts `envi.catalogReady` when Lynx boots. If the Lynx bundle comes from CDN per manifest, verify SHA-256 before evaluating.
  
  Security: all Swift→JS payloads are JSONEncoder-serialized + validated. All JS→Swift payloads strictly decoded against Codable structs. Reject unknown messages.
  
  AVOID: dynamic JS generation via string concat (XSS via asset names), trusting message payload without Codable validation, exposing full file URLs (use WKURLSchemeHandler for controlled access).
  </action>
  <verify>Integration test harness: Swift sends setCatalog → JS responds envi.catalogReady → Swift sends user assets → round-trip in < 100ms</verify>
  <done>All message types handled both directions, Codable validation on every payload, XSS impossible</done>
</task>

<task type="auto">
  <name>Task 4: Wire Phase 3 VM to Lynx + feature flag</name>
  <files>ENVI/Features/Templates/TemplateTabViewModel.swift (modify), ENVI/Core/Config/FeatureFlags.swift (modify or create)</files>
  <action>
  Modify Phase 3's `TemplateTabViewModel`:
  - Inject `VideoTemplateRepository` via protocol (already done in Phase 3)
  - Add feature flag `templateCatalog.source`: `"mock" | "lynx"` (default `"lynx"` in production, `"mock"` in debug/tests)
  - At init, resolve which repo to use based on flag
  
  Feature flag in ENVI/Core/Config/FeatureFlags.swift — if file doesn't exist, create a minimal version using `RemoteConfig` from Firebase (already an ENVI dependency). Defaults live in code; remote overrides possible.
  
  AVOID: hardcoding repo choice (breaks tests), removing MockVideoTemplateRepository (still useful for offline dev), skipping the flag (fail-open path for emergency rollback is required).
  </action>
  <verify>Unit test: flag=mock → MockRepo used; flag=lynx → TemplateCatalogClient used; both paths successfully load templates</verify>
  <done>Flag works, both repos can be swapped at runtime, no regression on Phase 3 tests</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>Phase 4 complete — Lynx-in-WKWebView dynamic template delivery. Server can now push new templates via the manifest endpoint and they render in the app without an App Store update. Feature-flagged so we can rollback to MockRepo instantly.</what-built>
  <how-to-verify>
    1. Run: `xcodebuild test -scheme ENVI`
    2. Run app in simulator, toggle feature flag to "lynx", observe WKWebView loads shell and receives catalog
    3. Toggle flag to "mock", observe MockRepo path still works
    4. Confirm: No crash on offline mode (cached manifest returned)
  </how-to-verify>
  <resume-signal>Type "approved" to commit + push + proceed to Phase 5</resume-signal>
</task>

</tasks>

<verification>
- [ ] `swift build` succeeds
- [ ] All Phase 4 tests pass
- [ ] WKWebView loads local shell HTML without network
- [ ] Feature flag toggles work
- [ ] Phase 4 commit pushed
</verification>

<success_criteria>
- 5 new files + 1 HTML resource
- JSON manifest schema documented
- Bridge is Codable-safe both directions
- Feature flag allows rollback to mock
- Phase committed and pushed
</success_criteria>

<output>
Create `.planning/phases/template-tab-v1/04-SUMMARY.md` with manifest schema, Lynx runtime version used, security model notes, and commit SHA.
</output>
