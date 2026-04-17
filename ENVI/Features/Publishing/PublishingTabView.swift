import SwiftUI

/// Phase 16-01 — 4th-tab container for Publishing.
///
/// Hosts `ScheduleQueueView` as the primary surface (queue/status
/// dashboard) and exposes router-driven entry points for the related
/// publishing modals:
///   - `.schedulePost` — new-post composer (SchedulePostView)
///   - `.publishResults` — distribution reconciliation history
///   - `.linkedInAuthorPicker` — "post as" picker for LinkedIn companies
///
/// The existing `ScheduleQueueView` already owns its own
/// `SchedulingViewModel` via `@StateObject`, so this container just
/// embeds it and provides the tab-level title / toolbar affordances.
/// The in-view `+` / row-tap sheets inside `ScheduleQueueView` remain
/// functional — this tab is purely an entry-point surface.
struct PublishingTabView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScheduleQueueView()
                .navigationTitle("Publishing")
                .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .sheet(item: $router.sheet) { destination in
            AppDestinationSheetResolver(destination: destination)
        }
        .fullScreenCover(item: $router.fullScreen) { destination in
            AppDestinationFullScreenResolver(destination: destination)
        }
    }
}

#if DEBUG
struct PublishingTabView_Previews: PreviewProvider {
    static var previews: some View {
        PublishingTabView()
            .environmentObject(AppRouter())
            .preferredColorScheme(.dark)
    }
}
#endif
