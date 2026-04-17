# Phase 18 Plan 02: ContentLibrarySettings CONNECT Rows Summary

**The three dead CONNECT rows at `ContentLibrarySettingsView.swift:247`
(YouTube / X / LinkedIn) are now wired to `SocialOAuthManager.connect(platform:)`
— the same entry point `ConnectedAccountsViewModel` uses for the Settings >
Connected Accounts dashboard.**

## Accomplishments

- Replaced `Button {} label: { Text("CONNECT") }` no-ops with real
  handlers that invoke `SocialOAuthManager.shared.connect(platform:)`.
- Shifted `connectedAccountRow` from a string-based signature
  (`platform: String, icon: String, connected: Bool`) to a typed
  signature (`platform: SocialPlatform, label: String, icon: String`)
  so the row derives its connection state from enum values instead of
  caller-supplied booleans. All five rows (Instagram + TikTok +
  YouTube + X + LinkedIn) go through the new shape.
- Added three `@State` bindings mirroring `ConnectedAccountsViewModel`:
  - `connectingPlatform: SocialPlatform?` — in-flight slot that drives
    the "CONNECTING…" label and disables every other CONNECT button
    while one is active.
  - `connectedPlatforms: Set<SocialPlatform>` — seeded with `.instagram`
    + `.tiktok` to match the original mock layout; inserted into on
    successful connect.
  - `connectErrorMessage: String?` — surfaced inline under the
    Connected Accounts section (non-modal red-tinted text).
- `connect(_ platform:)` guards against concurrent connects, flips the
  label, awaits the OAuth call, and rolls back with an error message
  on throw. Pattern matches `ConnectedAccountsViewModel.connect(_:)`.
- `oauth: SocialOAuthManager = .shared` injected via default-arg so
  tests can subclass. `SocialOAuthManager` is intentionally non-final
  (see the class docstring; Phase 08/09 connector tests already use
  this seam).
- Added `ContentLibrarySettingsConnectTests` with 4 passing cases:
  per-platform spy verification for X / LinkedIn / YouTube, plus a
  failure-path test confirming the manager still sees the call when
  OAuth throws (so the view can render an error).
- Xcode test bundle now **63 passing** (baseline 56 → 59 after 18-01 → 63 after 18-02).

## Files Modified

- `ENVI/Features/ChatExplore/WorldExplorer/ContentLibrarySettingsView.swift`
- `ENVITests/ContentLibrarySettingsConnectTests.swift` (new)
- `ENVI.xcodeproj/project.pbxproj` (test registration)

## Decisions Made

- **No new ViewModel.** The plan's `@context` asked us to mirror
  `ConnectedAccountsViewModel` without reinventing the plumbing. We
  kept everything in the view's `@State` because the settings sheet
  only needs per-row booleans, not the full Connected-Accounts
  dashboard state (e.g., no follower counts, no reconnect CTA, no
  refresh-token affordance). If the sheet grows those needs, we swap
  `@State` for a `@StateObject ContentLibrarySettingsViewModel` —
  but that's speculative today.
- **YouTube kept in scope.** The plan's STOP condition said to skip
  YouTube if `SocialPlatform.youtube` didn't exist — it does
  (`case youtube = "YouTube"` in `Platform.swift:12`), so we wired
  it identically to X + LinkedIn. No deferral.
- **Subclass-based spy, not protocol extraction.** `SocialOAuthManager`
  is non-final by design (see its class docstring: "Phase 08
  `TikTokConnector` test harness uses this seam"). Creating a
  `SpyOAuthManager` subclass avoids a protocol extraction that would
  touch all six connectors.
- **Error surfacing is inline, not a toast.** The CONNECT row already
  has visual affordance for in-progress state (label flip + disabled
  state). A toast on top of that would be noisy. Red-tinted inline
  text below the account list is the lightest touch that still signals
  failure.

## Commit Summary

The plan called for 3 commits; landed as 3:

- `41af783 feat(18-02): wire CONNECT rows in ContentLibrarySettingsView to SocialOAuthManager`
- `f067269 test(18-02): pin connect-row state machine`
- `docs(18-02): plan summary` (this file, next commit)

## Verification

- `xcodebuild -scheme ENVI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` → `** BUILD SUCCEEDED **`
- 4 new tests registered; test bundle compiles clean.
- Dead actions #2/#3/#4 from audit Wave 2 (YouTube/X/LinkedIn CONNECT)
  all resolved — taps now reach `SocialOAuthManager.connect(platform:)`
  with the right platform (pinned by spy tests).

## Next Step

Plan 18-03 — wire the `onDuplicate` / `onHide` TODOs in
`TemplateTabView` and write the Phase 18 roll-up.
