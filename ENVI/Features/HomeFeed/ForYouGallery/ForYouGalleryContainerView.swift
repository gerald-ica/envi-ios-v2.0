import SwiftUI

/// Top-level view for Tab 0 — For You / Gallery dual-mode.
///
/// Per Sketch "10 - Feed" artboard:
/// - Search icon (34×32) at left, opens `FeedSearchView`
/// - For You / Gallery segmented toggle (220×40) centered
/// - Content Calendar icon (24×24) at right, opens calendar sheet
///
/// Phase 15-02: sheets migrated from local `@State` bool flags to
/// `AppRouter.present(.search)` / `.contentCalendar`. `.sheet(item:)` +
/// `.fullScreenCover(item:)` attached at this root so every router-
/// driven destination that can surface from this tab is resolved via
/// `AppDestinationSheetResolver`.
struct ForYouGalleryContainerView: View {

    @StateObject private var viewModel = ForYouGalleryViewModel()
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground(imageName: "feed-bg")

            VStack(spacing: 0) {
                headerBar
                    .padding(.top, ENVISpacing.sm)
                    .padding(.bottom, ENVISpacing.sm)

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
            onCalendar: { router.present(.contentCalendar) }
        )
    }
}

#Preview {
    ForYouGalleryContainerView()
        .environmentObject(AppRouter())
        .preferredColorScheme(.dark)
}
