import SwiftUI

/// Top-level view for Tab 0 — For You / Gallery dual-mode.
///
/// Shows a pill-shaped segmented control at the top with a search icon,
/// switching between `ForYouSwipeView` and `GalleryGridView`.
struct ForYouGalleryContainerView: View {

    @StateObject private var viewModel = ForYouGalleryViewModel()

    var body: some View {
        ZStack(alignment: .top) {
            backgroundLayer
                .ignoresSafeArea()

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
    }

    private var backgroundLayer: some View {
        ZStack {
            Color.black

            LinearGradient(
                colors: [
                    Color(hex: "#0A0A0A"),
                    Color(hex: "#050505"),
                    Color(hex: "#000000")
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [Color.white.opacity(0.06), .clear],
                center: .topLeading,
                startRadius: 12,
                endRadius: 320
            )

            RadialGradient(
                colors: [Color(hex: "#30217C").opacity(0.12), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 420
            )
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: ENVISpacing.md) {
            MainAppUtilityChatPill {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.selectedSegment = viewModel.selectedSegment == .forYou ? .gallery : .forYou
                }
            }

            Spacer(minLength: 0)

            segmentedControl

            Spacer(minLength: 0)

            MainAppUtilityIcon(systemName: "arrow.clockwise") {
                Task { await viewModel.refresh() }
            }
        }
        .padding(.horizontal, 16)
    }

    private var segmentedControl: some View {
        MainAppTopSegmentSwitch(
            options: ForYouGalleryViewModel.Segment.allCases.map(\.rawValue),
            selectedIndex: viewModel.selectedSegment == .forYou ? 0 : 1
        ) { index in
            withAnimation(.easeInOut(duration: 0.25)) {
                viewModel.selectedSegment = index == 0 ? .forYou : .gallery
            }
        }
    }
}

#Preview {
    ForYouGalleryContainerView()
        .preferredColorScheme(.dark)
}
