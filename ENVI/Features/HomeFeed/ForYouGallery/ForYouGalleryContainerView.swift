import SwiftUI

/// Top-level view for Tab 0 — For You / Gallery dual-mode.
///
/// Per Sketch "10 - Feed" artboard + post-Sprint-03 3-tab revision:
/// - Search icon (34×32) at left, opens `FeedSearchView`
/// - For You / Gallery segmented toggle (220×40) centered
/// - Right-side cluster: calendar icon (24×24) + publishing paperplane
///   pill (34×32). Publishing is the rightmost action per the 3-tab spec
///   (Publishing is NOT a tab — it surfaces from here).
struct ForYouGalleryContainerView: View {

    @StateObject private var viewModel = ForYouGalleryViewModel()
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground(imageName: "main-bg", vignetteOpacity: 0.0)

            VStack(spacing: 0) {
                headerBar
                    // Extra top breathing room below the Dynamic Island.
                    // ENVISpacing.xl (~20) was close but still felt tight next
                    // to the status bar — bump to 36pt so the header settles
                    // clearly below the island.
                    .padding(.top, 36)
                    .padding(.bottom, ENVISpacing.md)

                switch viewModel.selectedSegment {
                case .forYou:
                    ForYouSwipeView(viewModel: viewModel)
                case .gallery:
                    GalleryGridView(viewModel: viewModel)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $router.sheet) { destination in
            AppDestinationSheetResolver(destination: destination)
        }
        .fullScreenCover(item: $router.fullScreen) { destination in
            AppDestinationFullScreenResolver(destination: destination)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        MainAppHeader(
            selectedIndex: viewModel.selectedSegment == .forYou ? 0 : 1,
            onSegmentChange: { index in
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.selectedSegment = index == 0 ? .forYou : .gallery
                }
            },
            onSearch: { router.present(.search) },
            onCalendar: { router.present(.contentCalendar) },
            onPublishing: { router.present(.publishing) }
        )
    }
}

/// Backward-compatible name used by legacy tab bar wiring.
typealias HomeFeedContainerView = ForYouGalleryContainerView

#Preview {
    ForYouGalleryContainerView()
        .environmentObject(AppRouter())
        .preferredColorScheme(.dark)
}
