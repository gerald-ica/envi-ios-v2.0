import SwiftUI

/// Top-level view for Tab 0 — For You / Gallery dual-mode.
///
/// Per Sketch "10 - Feed" artboard:
/// - Search icon (34×32) at left, opens `FeedSearchView`
/// - For You / Gallery segmented toggle (220×40) centered
/// - Content Calendar icon (24×24) at right, opens calendar sheet
struct ForYouGalleryContainerView: View {

    @StateObject private var viewModel = ForYouGalleryViewModel()
    @State private var showSearch = false
    @State private var showCalendar = false

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
        .sheet(isPresented: $showSearch) {
            FeedSearchView()
        }
        .sheet(isPresented: $showCalendar) {
            CalendarSheet()
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
            onSearch: { showSearch = true },
            onCalendar: { showCalendar = true }
        )
    }
}

/// Sheet host for `ContentCalendarView`, providing the demo days the
/// calendar expects. Keeps the main container view lean.
private struct CalendarSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                ContentCalendarView(days: AnalyticsData.mock.calendarDays)
                    .padding(.top, ENVISpacing.lg)
            }
            .background(AppBackground(imageName: "feed-bg"))
            .navigationTitle("Content Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ForYouGalleryContainerView()
        .preferredColorScheme(.dark)
}
