# Phase 18 Plan 03: Template Duplicate + Hide Summary

**The `onDuplicate` and `onHide` TODO closures at
`TemplateTabView.swift:231-232` are now real. Duplicate creates a clone
through `VideoTemplateRepository`; Hide removes the card locally and
persists the hide across relaunches via `UserDefaultsManager`.**

## Accomplishments

- Added `duplicate(templateID:) async throws -> VideoTemplate` to the
  `VideoTemplateRepository` protocol. `MockVideoTemplateRepository`
  deep-copies the source template (fresh UUID, " Copy" name suffix);
  `TemplateCatalogClient` (the Lynx-manifest actor implementation)
  mirrors the same deep-copy semantics since the server catalog is
  read-only. A future phase can wire a "saved clones" collection
  server-side; today clones are session-local.
- Added `hiddenTemplateIDs: Set<String>` to `UserDefaultsManager`
  (round-trips through the `stringArray` defaults primitive; `Set` is
  not a plist type on its own).
- Extended `TemplateTabViewModel` (`@Observable`, no
  `@Published`) with four new public surfaces:
  - `hiddenIDs: Set<String>` — restored from `UserDefaultsManager` on
    init so a relaunched VM sees prior hides immediately.
  - `visibleTemplates: [PopulatedTemplate]` — derived from
    `populatedTemplates` filtered against `hiddenIDs`. Views bind
    here instead of `populatedTemplates` so Hide actually removes
    cards.
  - `hide(_ populated:)` — inserts into the set + persists.
  - `unhideAll()` — clears + persists (scope-expansion hedge for the
    future "show hidden" toggle).
  - `duplicate(_ populated:) async` — calls repo, runs the matcher
    over the clone (so thumbnails + slot fill are consistent with
    other cards), prepends to both `populatedTemplates` and the
    category bucket so both the For You grid and the per-category
    row see the new card.
- `TemplateTabView` replaced both `{ /* TODO: Find similar content */ }`
  and `{ /* TODO: Hide template */ }` no-op closures with:
  - `onDuplicate: { Task { await viewModel.duplicate(populated) } }`
  - `onHide: { viewModel.hide(populated) }`
  Applied at both call sites (the 2-column For You grid and the
  horizontal category row).
- Added `TemplateTabActionsTests` with 4 passing cases:
  `testDuplicateCallsRepoAndAppendsClone`,
  `testHidePersistsAcrossVMInstances`,
  `testVisibleTemplatesExcludesHidden`,
  `testUnhideAllClearsSetAndPersistence`.
- Xcode test bundle is now **67/67 passing** (56 baseline + 3 18-01 +
  4 18-02 + 4 18-03).

## Files Created/Modified

- `ENVI/Core/Data/Repositories/VideoTemplateRepository.swift` (protocol
  + Mock conformer + `ThrowMode.onDuplicate` injection)
- `ENVI/Core/Templates/TemplateCatalogClient.swift` (actor conformer)
- `ENVI/Core/Storage/UserDefaultsManager.swift` (`hiddenTemplateIDs`)
- `ENVI/Features/HomeFeed/Templates/TemplateTabViewModel.swift`
  (`hiddenIDs`, `visibleTemplates`, `hide`, `unhideAll`, `duplicate`,
  `preferences` DI)
- `ENVI/Features/HomeFeed/Templates/TemplateTabView.swift` (wired
  context-menu callbacks at both call sites, `visibleTemplates`
  binding)
- `ENVITests/TemplateTabActionsTests.swift` (new)
- `ENVITests/Features/Templates/TemplateTabViewModelTests.swift`
  (SpyRepository extended with `duplicate(templateID:) + duplicateCalls`
  recorder so the SPM-only suite still compiles)
- `ENVI.xcodeproj/project.pbxproj` (test file registration)

## Decisions Made

- **Clone is session-local for the Lynx path.** The catalog is a
  read-only server manifest (ETag-driven). We deep-copy with a fresh
  UUID on both repo conformers rather than inventing a server endpoint
  the broker doesn't support. If a "saved clones" collection ships
  later, `TemplateCatalogClient.duplicate(...)` is the one spot to
  swap in a POST.
- **Hide is local-only.** Per the plan: hide is a UX preference, not
  a server-synced account setting. UserDefaults is the right store —
  it's fast, per-device, and doesn't require a migration.
- **`Set<String>` for the hidden ids (stored as `[String]`).** Using
  the UUID string form avoids a second Codable layer for a
  `Set<UUID>` and matches how PlatformConnection etc. key on
  `apiSlug: String`. The set-based API is public; the array is an
  implementation detail of the UserDefaults round-trip.
- **`visibleTemplates` as a derived property, not a mutation.** Keeping
  `populatedTemplates` as the source of truth makes `unhideAll()`
  fast (no refetch) and gives the VM a clean seam if Phase 19 wants
  to move `hiddenIDs` into the server-synced user preferences.
- **Preferences injected via default-arg.** `preferences:
  UserDefaultsManager = .shared` lets tests drive a specific instance
  while production call-sites stay unchanged. We didn't swap to
  `UserDefaults` direct injection because a few places already call
  `UserDefaultsManager.shared.*` — keeping the shim preserves that
  call shape.

## Commit Summary

The plan called for 5 commits (feat/feat/test/docs/phase-roll-up);
landed as 5:

- `de1544e feat(18-03): add duplicate + hide to TemplateTabViewModel + VideoTemplateRepository`
- `b33bd77 feat(18-03): wire onDuplicate + onHide in TemplateTabView`
- `d1ec45a test(18-03): pin duplicate + hide behavior`
- `docs(18-03): plan summary` (this file, next commit)
- `docs(18): phase 18 complete — 4 dead actions fixed` (phase
  roll-up, after this commit)

## Verification

- `xcodebuild -scheme ENVI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` → `** BUILD SUCCEEDED **`
- `xcodebuild test` → **67 passed, 0 failed** (grew from baseline 56)
- Dead actions #3 + #4 (Duplicate / Hide) from audit Wave 2 both
  resolved — repo-call + persistence pinned by the VM tests.
- Hide survives across VM instances — confirmed by
  `testHidePersistsAcrossVMInstances`.

## Next Step

Phase 18 roll-up (ROADMAP + STATE + phase SUMMARY), then Phase 19
(p4-hygiene) is the last v1.2 phase.
