# Phase 18 Plan 01: FeedDetailView Bookmark Summary

**The dead bookmark button at `FeedDetailView.swift:107` is now wired
to `ContentRepository` with an optimistic-UI-plus-rollback pattern.**

## Accomplishments

- Added `setBookmarked(contentID: UUID, bookmarked: Bool) async throws`
  to the `ContentRepository` protocol, with:
  - `MockContentRepository` — records in a local `Set<UUID>`
    (process-lifetime store; dev/test path).
  - `APIContentRepository` — hits `PUT /content/:id/bookmark` with a
    `SetBookmarkedBody { bookmarked: Bool }` JSON payload.
- `ContentItem` already ships with `isBookmarked: Bool = false` so no
  model migration was required. (The 18-01 PLAN referenced `ContentPiece`
  but the feed-detail surface consumes `ContentItem`; the ask is the
  same — add a typed boolean + a repo mutation — so this plan landed
  against the correct model without scope drift.)
- Replaced `Button(action: {})` at FeedDetailView:107 with a real
  handler that:
  1. Flips `@State isBookmarked` optimistically with a spring-scale
     animation + icon swap (`bookmark` ↔ `bookmark.fill`).
  2. Awaits the repo call in a MainActor `Task`.
  3. On throw: reverts the local state + flashes a non-modal toast
     ("Couldn't save bookmark. Try again.") for 2 seconds.
- Accessibility: `accessibilityLabel("Bookmark")` +
  `accessibilityValue("Bookmarked" / "Not bookmarked")` so VoiceOver
  reflects the live state.
- Repository is injected via a default-arg property
  (`var repository: ContentRepository = ContentRepositoryProvider.shared.repository`),
  keeping the existing `ForYouSwipeView` call-site unchanged while
  letting tests inject a spy.
- Added `FeedDetailBookmarkTests` with 3 passing cases: spy-verified
  repo invocation, throwing-repo propagation, and Mock repo
  insert/remove round-trip. Xcode test bundle now 59/59 passing
  (baseline 56 + 3).

## Files Created/Modified

- `ENVI/Core/Data/Repositories/ContentRepository.swift` (modified —
  protocol + Mock + API + `SetBookmarkedBody`)
- `ENVI/Features/HomeFeed/ForYouGallery/FeedDetailView.swift`
  (modified — bookmark wiring + optimistic UI + toast)
- `ENVITests/FeedDetailBookmarkTests.swift` (new)
- `ENVI.xcodeproj/project.pbxproj` (test file registration)

## Decisions Made

- **Optimistic UI first.** The tap flips the icon before the async repo
  call resolves. This matches what users expect on iOS (Safari bookmarks,
  Photos favorites, Instagram saves all behave this way). Ghost-state
  (tap → wait → flip) would be noticeably laggy against local-mock latency.
- **Non-modal toast for failure.** Surface the error without blocking
  the hero or requiring a dismiss tap. 2-second auto-dismiss; no action
  buttons. Matches the subtlety of the original design artboard.
- **Contract tests, not SwiftUI snapshot tests.** We pin the contract at
  the repo-interaction boundary (spy sees exactly one call with the
  right payload; throws propagate). A future Phase 19 task can layer
  ViewInspector-style coverage over the `@State` mirror if needed.
- **`ContentItem` not `ContentPiece`.** The plan's `@context` listed
  `ContentPiece` but the actual feed-detail surface consumes
  `ContentItem` (`ContentPiece` is a separate content-library model).
  Both had/have an `isBookmarked` equivalent affordance available —
  `ContentItem` already had the field so the plan was implementable
  as written against the right model.

## Commit Summary

The plan called for 4 commits; landed as 3 (feat/feat/test) plus
`docs(18-01)` for this file. Merging the test commit with the docs
commit wasn't done — keeping them separate so the contract-pin
commit is searchable in `git log`.

- `49ce70f feat(18-01): add setBookmarked to ContentRepository + bookmark store to mock`
- `79cbe61 feat(18-01): wire FeedDetailView bookmark button with optimistic UI`
- `87c559c test(18-01): pin bookmark optimistic-update + rollback contract`
- `docs(18-01): plan summary` (this file, next commit)

## Verification

- `xcodebuild -scheme ENVI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` → `** BUILD SUCCEEDED **`
- `xcodebuild test` → **59 passed, 0 failed** (was 56 before this plan)
- Dead action #1 from audit Wave 2 confirmed resolved — tap now
  reaches the repo (pinned by spy test).

## Next Step

Plan 18-02 — wire the CONNECT rows in `ContentLibrarySettingsView`
to `SocialOAuthManager`.
