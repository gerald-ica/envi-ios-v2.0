import SwiftUI

/// Top-level view for Tab 0 — For You / Gallery dual-mode.
///
/// Shows a pill-shaped segmented control at the top with a search icon,
/// switching between `ForYouSwipeView` and `GalleryGridView`.
struct ForYouGalleryContainerView: View {

    @StateObject private var viewModel = ForYouGalleryViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            ENVITheme.Dark.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerBar
                    .padding(.top, ENVISpacing.sm)

                // Content
                switch viewModel.selectedSegment {
                case .forYou:
                    ForYouSwipeView(viewModel: viewModel)
                case .gallery:
                    GalleryGridView(viewModel: viewModel)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: ENVISpacing.md) {
            // Search button
            Button {
                viewModel.showSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Pill segmented control
            segmentedControl

            Spacer()

            // Spacer to balance the search icon
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, ENVISpacing.lg)
    }

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(ForYouGalleryViewModel.Segment.allCases, id: \.self) { segment in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.selectedSegment = segment
                    }
                } label: {
                    Text(segment.rawValue)
                        .font(.spaceMonoBold(13))
                        .tracking(1.2)
                        .foregroundColor(
                            viewModel.selectedSegment == segment
                                ? .black
                                : .white.opacity(0.6)
                        )
                        .padding(.horizontal, ENVISpacing.lg)
                        .padding(.vertical, ENVISpacing.sm)
                        .background(
                            viewModel.selectedSegment == segment
                                ? Color.white
                                : Color.clear
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(ENVISpacing.xs)
        .background(ENVITheme.Dark.surfaceLow)
        .clipShape(Capsule())
    }
}

#Preview {
    ForYouGalleryContainerView()
        .preferredColorScheme(.dark)
}
