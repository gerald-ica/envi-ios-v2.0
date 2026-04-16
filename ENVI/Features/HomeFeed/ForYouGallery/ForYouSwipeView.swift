import SwiftUI

/// Full-screen swipeable content pieces for the "For You" segment.
///
/// Vertical scroll browses cards; horizontal swipe right approves
/// (moves to Gallery / Social Media Arsenal), left disapproves.
struct ForYouSwipeView: View {

    @ObservedObject var viewModel: ForYouGalleryViewModel

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
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    Text("[ TAP THE CONTENT PIECES TO EXPAND ]")
                        .font(.spaceMonoBold(11))
                        .tracking(1.5)
                        .foregroundColor(.white.opacity(0.46))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 16)

                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.forYouItems.enumerated()), id: \.element.id) { index, item in
                            SwipeableCardView(
                                item: item,
                                cardHeight: min(480, max(430, geo.size.height * 0.64)),
                                dismissDistance: geo.size.width,
                                onApprove: { viewModel.approve(item) },
                                onDisapprove: { viewModel.disapprove(item.id) },
                                onBookmark: { viewModel.bookmarkCard(id: item.id) }
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, index == viewModel.forYouItems.count - 1 ? 0 : -28)
                            .padding(.top, index == 0 ? 0 : 4)
                            .zIndex(Double(viewModel.forYouItems.count - index))
                        }
                    }
                }
                .padding(.bottom, 136)
            }
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

// MARK: - Swipeable Card

/// Individual feed card with horizontal swipe gesture for approve/disapprove.
private struct SwipeableCardView: View {
    let item: ContentItem
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
        ZStack(alignment: .bottom) {
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

            cardContent
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .clipped()
        .background(ENVITheme.Dark.surfaceLow.opacity(0.92))
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

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Spacer()

            HStack(alignment: .top, spacing: ENVISpacing.sm) {
                platformBadge

                Spacer()

                Button(action: onBookmark) {
                    Image(systemName: item.isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

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
                    .lineLimit(3)
            }

            HStack(spacing: ENVISpacing.sm) {
                metricPill(title: "REACH", value: item.estimatedReach)
                metricPill(title: "TIME", value: item.bestTime)
                metricPill(title: "SCORE", value: "\(Int(item.confidenceScore * 100))%")
            }

            HStack(spacing: ENVISpacing.sm) {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(item.creatorName.prefix(1)))
                            .font(.interSemiBold(13))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 0) {
                    Text(item.creatorName)
                        .font(.interSemiBold(14))
                        .foregroundColor(.white)
                    Text(item.creatorHandle)
                        .font(.interRegular(12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
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

    private func metricPill(title: String, value: String) -> some View {
        HStack(spacing: ENVISpacing.xs) {
            Text(title)
                .font(.spaceMonoBold(9))
                .tracking(1.2)
                .foregroundColor(.white.opacity(0.45))

            Text(value)
                .font(.interSemiBold(12))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
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
