# Archived UIKit Feed files — 2026-04-16

These files belonged to the original UIKit-based Feed flow
(`FeedViewController` + `SwipeableCardStack` + `ContentCardView`) that
was superseded by the SwiftUI `ForYouGalleryContainerView` /
`ForYouSwipeView` / `GalleryGridView` stack.

Archived (no live references in `ENVI/` as of 2026-04-16):

- `AIInsightPill.swift`
- `ContentCardView.swift`
- `ExpandableFeedCardView.swift`
- `ExploreGridView.swift`
- `FeedDetailViewController.swift`
- `FeedViewController.swift`
- `NotificationCenterView.swift`
- `SwipeableCardStack.swift`
- `TextPostCardView.swift`

Kept in the build target (still referenced elsewhere):

- `FeedSearchView.swift` — presented as a sheet from `ForYouGalleryContainerView`.
- `FeedViewModel.swift` — `FeedViewModel.imageNames` is reused by `ContentLibrary` in `WorldExplorerView`, and by `ForYouGalleryViewModel`.

Restore procedure if needed: copy a file back into
`ENVI/Features/HomeFeed/Feed/` and re-add it to the ENVI target via
Xcode's "Add Files…" dialog.
