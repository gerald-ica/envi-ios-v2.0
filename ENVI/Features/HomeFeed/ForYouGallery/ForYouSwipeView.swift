import SwiftUI
import UIKit

/// Full-screen swipeable content pieces for the "For You" segment.
///
/// Vertical scroll browses cards; horizontal swipe right approves
/// (moves to Gallery / Social Media Arsenal), left disapproves.
struct ForYouSwipeView: View {

    @ObservedObject var viewModel: ForYouGalleryViewModel
    @State private var screenWidth: CGFloat = ScreenWidthDefaults.currentWidth

    var body: some View {
        ZStack {
            switch viewModel.loadingPhase {
            case .idle, .analyzing:
                analyzingState
            case .matchingTemplates:
                matchingState
            case .ready:
                if viewModel.forYouItems.isEmpty {
                    emptyState
                } else {
                    cardStack
                }
            case .empty:
                emptyState
            case .error(let message):
                errorState(message: message)
            }

            if viewModel.isLoading && !viewModel.forYouItems.isEmpty {
                VStack {
                    ProgressView()
                        .tint(.white)
                        .padding(ENVISpacing.md)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                    Spacer()
                }
                .padding(.top, ENVISpacing.xl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Card Stack

    private var cardStack: some View {
        // UIScreen.main.bounds.width is the reliable source for the actual
        // device width in this view. GeometryReader reports an inflated
        // proposal here because AppBackground's .ignoresSafeArea() extends
        // the parent ZStack's bounds beyond the screen, and the ScrollView
        // does not propose its own width back to content.
        let resolvedScreenWidth = screenWidth > 0 ? screenWidth : ScreenWidthDefaults.currentWidth
        let contentWidth = resolvedScreenWidth - 32

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                Text("[ TAP THE CONTENT PIECES, AND EXPLORE ]")
                    .font(.spaceMonoBold(11))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.46))
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(.top, 14)
                    .padding(.bottom, 16)

                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.forYouItems.enumerated()), id: \.element.id) { index, item in
                        SwipeableCardView(
                            item: item,
                            cardWidth: contentWidth,
                            cardHeight: MainAppSketch.feedCardHeight,
                            dismissDistance: 280,
                            onApprove: { viewModel.approve(item) },
                            onDisapprove: { viewModel.disapprove(item.id) },
                            onBookmark: { viewModel.bookmarkCard(id: item.id) }
                        )
                        .padding(.bottom, index == viewModel.forYouItems.count - 1 ? 0 : 16)
                        .zIndex(Double(viewModel.forYouItems.count - index))
                    }
                }
                .frame(width: resolvedScreenWidth)
                .padding(.bottom, 136)
            }
            .frame(width: resolvedScreenWidth)
        }
    }

    // MARK: - Loading States

    private var analyzingState: some View {
        VStack(spacing: ENVISpacing.lg) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.2)
            Text("ANALYZING YOUR CONTENT")
                .font(.spaceMonoBold(13))
                .tracking(1.8)
                .foregroundColor(.white.opacity(0.72))
            Text("Scanning your camera roll to find the strongest matches.")
                .font(.interRegular(13))
                .foregroundColor(.white.opacity(0.44))
                .multilineTextAlignment(.center)
                .padding(.horizontal, ENVISpacing.xxxl)
        }
    }

    private var matchingState: some View {
        VStack(spacing: ENVISpacing.lg) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.2)
            Text("MATCHING TEMPLATES")
                .font(.spaceMonoBold(13))
                .tracking(1.8)
                .foregroundColor(.white.opacity(0.72))
            Text("Finding the best content pieces from your library.")
                .font(.interRegular(13))
                .foregroundColor(.white.opacity(0.44))
                .multilineTextAlignment(.center)
                .padding(.horizontal, ENVISpacing.xxxl)
        }
    }

    private var emptyState: some View {
        VStack(spacing: ENVISpacing.lg) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))
            Text("NO CONTENT PIECES YET")
                .font(.spaceMonoBold(13))
                .tracking(1.5)
                .foregroundColor(.white.opacity(0.55))
            Text("Add photos to your camera roll or wait for classification to complete.")
                .font(.interRegular(13))
                .foregroundColor(.white.opacity(0.38))
                .multilineTextAlignment(.center)
                .padding(.horizontal, ENVISpacing.xxxl)
            Button("Refresh") {
                Task { await viewModel.refresh() }
            }
            .font(.spaceMonoBold(13))
            .foregroundColor(.black)
            .padding(.horizontal, ENVISpacing.xxl)
            .padding(.vertical, ENVISpacing.sm)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: ENVISpacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))
            Text(message)
                .font(.interMedium(14))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, ENVISpacing.xxxl)
            Button("Try Again") {
                Task { await viewModel.refresh() }
            }
            .font(.spaceMonoBold(13))
            .foregroundColor(.black)
            .padding(.horizontal, ENVISpacing.xxl)
            .padding(.vertical, ENVISpacing.sm)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
    }
}

private enum ScreenWidthDefaults {
    static let fallbackWidth: CGFloat = 393

    static var currentWidth: CGFloat {
        let screenWidth = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .windowScene?
            .screen
            .bounds.width

        return screenWidth ?? fallbackWidth
    }
}

// MARK: - Swipeable Card

/// Individual feed card with horizontal swipe gesture for approve/disapprove.
private struct SwipeableCardView: View {
    let item: ContentItem
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let dismissDistance: CGFloat
    let onApprove: () -> Void
    let onDisapprove: () -> Void
    let onBookmark: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var showDetail = false

    /// Threshold (in points) to trigger approve/disapprove.
    private let swipeThreshold: CGFloat = 120

    var body: some View {
        ZStack(alignment: .topTrailing) {
            cardImage

            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.26),
                    Color.black.opacity(0.84)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            swipeIndicators

            // Sketch: AI SCORE PREVIEWS 77×78 at (269, 12) — 3 stacked pills.
            aiScorePreviews
                .padding(.top, 12)
                .padding(.trailing, 12)

            cardContent
        }
        .frame(width: cardWidth, height: cardHeight)
        // Sketch Content Card fill #4A60B2 — visible only when no image.
        .background(Color(hex: "#4A60B2"))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .offset(x: dragOffset)
        .rotationEffect(.degrees(Double(dragOffset) / 30), anchor: .bottom)
        .gesture(swipeGesture)
        .onTapGesture { showDetail = true }
        .fullScreenCover(isPresented: $showDetail) {
            FeedDetailView(item: item, onApprove: onApprove)
        }
        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
    }

    private var cardImage: some View {
        Group {
            if let imageName = item.imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: cardHeight)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [
                        ENVITheme.Dark.surfaceLow,
                        Color.black.opacity(0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    @ViewBuilder
    private var swipeIndicators: some View {
        if dragOffset > 30 {
            HStack {
                VStack(spacing: ENVISpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                    Text("APPROVE")
                        .font(.spaceMonoBold(13))
                        .tracking(1.5)
                }
                .foregroundColor(ENVITheme.success)
                .opacity(min(1, Double(dragOffset) / swipeThreshold))
                .padding(.leading, ENVISpacing.xxxl)

                Spacer()
            }
        }

        if dragOffset < -30 {
            HStack {
                Spacer()

                VStack(spacing: ENVISpacing.xs) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 48))
                    Text("PASS")
                        .font(.spaceMonoBold(13))
                        .tracking(1.5)
                }
                .foregroundColor(ENVITheme.error)
                .opacity(min(1, Double(abs(dragOffset)) / swipeThreshold))
                .padding(.trailing, ENVISpacing.xxxl)
            }
        }
    }

    /// Sketch: AI SCORE PREVIEWS — 3 grey translucent pills stacked
    /// vertically at the top-right of the card. Icons are the exact
    /// bitmaps from the Sketch symbols:
    /// - Confidence: envi-ai-confidence.png (14×10)
    /// - Best time:  shape-01.png           (15×15)
    /// - Reach:      eye.fill SF Symbol     (Sketch uses a vector path)
    private var aiScorePreviews: some View {
        VStack(alignment: .trailing, spacing: 4) {
            scorePill(
                bitmap: "envi-ai-confidence",
                size: CGSize(width: 14, height: 10),
                text: "\(Int(item.confidenceScore * 100))%"
            )
            scorePill(
                bitmap: "shape-01",
                size: CGSize(width: 15, height: 15),
                text: item.bestTime
            )
            scorePill(
                systemName: "eye.fill",
                text: item.estimatedReach
            )
        }
    }

    private func scorePill(bitmap: String, size: CGSize, text: String) -> some View {
        HStack(spacing: 4) {
            Image(bitmap)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
                .foregroundColor(.white)
            Text(text)
                .font(.interSemiBold(11))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: "#8B8B8B").opacity(0.75))
        .clipShape(Capsule())
    }

    private func scorePill(systemName: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
            Text(text)
                .font(.interSemiBold(11))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: "#8B8B8B").opacity(0.75))
        .clipShape(Capsule())
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Spacer()

            Text(item.caption)
                .font(.spaceMonoBold(18))
                .tracking(-0.2)
                .foregroundColor(.white)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if let bodyText = item.bodyText {
                Text(bodyText)
                    .font(.interRegular(14))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(2)
            }

            // Sketch: Platform Badge (bottom-left) + handle + bookmark (bottom-right)
            HStack(alignment: .center, spacing: ENVISpacing.sm) {
                platformBadge

                Text(item.creatorHandle)
                    .font(.interRegular(13))
                    .foregroundColor(.white.opacity(0.72))
                    .lineLimit(1)

                Spacer()

                Button(action: onBookmark) {
                    Image(systemName: item.isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ENVISpacing.xl)
    }

    private var platformBadge: some View {
        HStack(spacing: ENVISpacing.xs) {
            Image(systemName: item.platform.iconName)
                .font(.system(size: 13, weight: .semibold))
            Text(item.platform.rawValue)
                .font(.spaceMonoBold(10))
                .tracking(1.4)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.08))
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    // MARK: - Swipe Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                dragOffset = value.translation.width
            }
            .onEnded { value in
                if value.translation.width > swipeThreshold {
                    withAnimation(.easeOut(duration: 0.3)) {
                        dragOffset = dismissDistance
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onApprove()
                    }
                } else if value.translation.width < -swipeThreshold {
                    withAnimation(.easeOut(duration: 0.3)) {
                        dragOffset = -dismissDistance
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onDisapprove()
                    }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        dragOffset = 0
                    }
                }
            }
    }
}
