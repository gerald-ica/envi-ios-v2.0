---
phase: 04-lynx-bridge
status: complete
completed: 2026-04-15
---

# Phase 4: Lynx-in-WKWebView Bridge — Summary

**Dynamic server-delivered template catalog shipped. Server pushes new templates via manifest endpoint → Swift fetches with ETag/offline-first → Lynx bundle downloads with SHA-256 integrity → renders in sandboxed WKWebView with strict JS↔Swift bridge. Feature-flagged for instant rollback.**

## Files Created (10 total: 7 prod + 3 test + 2 resources)

**Production:**
- `ENVI/Core/Templates/TemplateManifest.swift` — JSON schema (version, templates, categories, Lynx bundle URL + SHA-256)
- `ENVI/Core/Templates/TemplateCatalogClient.swift` — actor repo, ETag caching, bundle download+verify
- `ENVI/Features/Templates/LynxWebViewController.swift` — WKWebView host + EnviAssetSchemeHandler
- `ENVI/Features/Templates/LynxWebViewRepresentable.swift` — SwiftUI wrapper
- `ENVI/Features/Templates/SwiftLynxBridge.swift` — WKScriptMessageHandler with strict Codable validation + token-bucket rate limit
- `ENVI/Core/Config/FeatureFlags.swift` — `@Observable` remote-config-ready flags

**Resources:**
- `ENVI/Features/Templates/Resources/lynx-shell.html` — CSP-locked bootstrap
- `ENVI/Features/Templates/Resources/shell.js` — dynamic import of Lynx bundle

**Tests:**
- `ENVITests/Templates/TemplateCatalogClientTests.swift` — 8 tests (parse, offline, schema mismatch, hash)
- `ENVITests/Features/Templates/SwiftLynxBridgeTests.swift` — 10 tests (security gates, rate limit, payloads)
- `ENVITests/Features/Templates/TemplateTabViewModelTests.swift` (modified) — 3 feature-flag tests added

## Manifest Schema

```json
{
  "version": 1,
  "generatedAt": "ISO-8601",
  "templates": [VideoTemplate],
  "categories": [VideoTemplateCategory],
  "lynxBundleURL": "https://cdn.../bundle.js",
  "lynxBundleHash": "sha256-hex-lowercase"
}
```

- **Schema version**: Rejects `> 1` with fallback to cache
- **Bundle verification**: SHA-256 mismatch always throws (no silent fallback — security invariant)
- **Cache location**: `~/Library/Caches/template-catalog.json` + sibling `.etag.json`
- **Bundle path**: `~/Library/Application Support/LynxBundles/<hash>/bundle.bin` (hash-in-path for coexistence)

## Lynx API Approach (verified via context7)

Using `@lynx-js/web-core` programmatic API:
- `createLynxView({container, template, initialData, onError})`
- Shell dynamically `import()`s the bundle path Swift provides
- Forwards Swift payloads via `lynxView.updateData({channel, payload})`
- Graceful fallback: "Loading templates…" div when bundle not yet downloaded

## Security Measures

1. **Strict Codable validation**: Every JS→Swift payload validates against hand-rolled `init(from:)` with `assertNoUnknownKeys` — extra fields rejected
2. **UUID re-validation** post-decode on all ID fields
3. **TelemetryPropertyValue enum** restricts values to `String | Int | Double | Bool` — nested objects rejected
4. **No string-interpolated JS eval** — all Swift→JS via `JSONEncoder`-produced payloads
5. **Frame/origin gates**: `isMainFrame == true` required; `securityOrigin` matched if provided
6. **10 MB payload cap** — DoS protection
7. **Token-bucket rate limit**: 50 thumbnail reqs/sec per bridge instance, burst=50
8. **CSP policy**: `default-src 'none'; script-src 'self'; img-src 'self' data: blob: envi-asset:; base-uri 'none'`
9. **`envi-asset://` custom scheme**: Controlled file access without exposing filesystem paths
10. **Weak WebView ref** in bridge — no retain cycle

## Feature Flag

`FeatureFlags.shared.templateCatalogSource`:
- DEBUG default: `"mock"` → `MockVideoTemplateRepository` (Phase 3)
- Release default: `"lynx"` → `TemplateCatalogClient` (this phase)
- Unknown value → `assertionFailure` in DEBUG, fallback to mock in release
- Firebase Remote Config integration wired via `#if canImport(FirebaseRemoteConfig)` — activates automatically when SPM dep is added

## TemplateTabViewModel.makeDefault()

New static factory:
```swift
TemplateTabViewModel.makeDefault(cache:index:scanner:)
```
Internally reads `FeatureFlags.shared.templateCatalogSource` → picks repo. Original `init(repo:...)` unchanged (for tests).

## Readiness for Phase 5

✅ `TemplateTabViewModel.makeDefault()` ready for Phase 5 view init
✅ `LynxWebView` (SwiftUIRepresentable) ready to host in Template tab
✅ `EnviAssetSchemeHandler` stub serves deterministic JPEGs — Phase 5 wires real PHImageManager

## Decisions Made

- **ManifestFetching protocol** added to bypass APIClient limitation (doesn't expose headers/status). Ephemeral URLSession matches APIClient's auth header pattern without modifying APIClient.
- **Hash-in-path bundle storage** enables coexisting versions + clean rollback
- **Token-bucket rate limit over sliding-window counter** — lower memory, same fairness
- **Separate message handlers per type** (not one big switch) — type-safe, testable individually
- **Coordinator doubles as WKScriptMessageHandler** for template selection events

## Parse Verification

All 27 Phase 1-4 files parse clean together on iOS 26:
```
xcrun -sdk iphonesimulator swiftc -parse -target arm64-apple-ios26.0-simulator [27 files]
```

## Commits

Phase 4 commit SHA: [see git log]
Branch: `feature/template-tab-v1`
Pushed to origin.
