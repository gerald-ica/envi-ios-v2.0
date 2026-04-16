import SwiftUI

/// Full-screen swipeable content pieces for the "For You" segment.
///
/// Vertical scroll browses cards; horizontal swipe right approves
/// (moves to Gallery / Social Media Arsenal), left disapproves.
struct ForYouSwipeView: View {

    @ObservedObject var viewModel: ForYouGalleryViewModel
    @Environment(\.colorScheme) private var colorScheme

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

            // Overlay a spinner when isLoading but we already have items
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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Instruction text
                Text("TAP THE CONTENT PIECES. AND EXPLORE")
                    .font(.spaceMonoBold(11))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.top, ENVISpacing.md)
                    .padding(.bottom, ENVISpacing.lg)

                LazyVStack(spacing: 0) {
                    ForEach(viewModel.forYouItems) { item in
                        SwipeableCardView(
                            item: item,
                            onApprove: { viewModel.approve(item) },
                            onDisapprove: { viewModel.disapprove(item.id) }
                        )
                    }
                }
            }
            .padding(.bottom, 100) // Space for tab bar
        }
    }

    // MARK: - Loading States

    private var analyzingState: some View {
        VStack(spacing: ENVISpacing.lg) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.2)
            Text("Analyzing your content...")
                .font(.interSemiBold(15))
                .foregroundColor(.white.opacity(0.7))
            Text("Scanning your camera roll to find the best matches")
                .font(.interRegular(13))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, ENVISpacing.xxxl)
        }
    }

    private var matchingState: some View {
        VStack(spacing: ENVISpacing.lg) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.2)
            Text("Matching templates...")
                .font(.interSemiBold(15))
                .foregroundColor(.white.opacity(0.7))
            Text("Finding the best content pieces from your library")
                .font(.interRegular(13))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, ENVISpacing.xxxl)
        }
    }

    private var emptyState: some View {
        VStack(spacing: ENVISpacing.lg) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))
            Text("No content pieces yet")
                .font(.interMedium(15))
                .foregroundColor(.white.opacity(0.5))
            Text("Add photos to your camera roll or wait for classification to complete")
                .font(.interRegular(13))
                .foregroundColor(.white.opacity(0.35))
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
    let onApprove: () -> Void
    let onDisapprove: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var showDetail = false

    /// Threshold (in points) to trigger approve/disapprove.
    private let swipeThreshold: CGFloat = 120

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-bleed image
            cardImage

            // Overlay gradient
            ENVITheme.cardOverlayGradient

            // Swipe indicator overlays
            swipeIndicators

            // Content overlay
            cardContent
        }
        .frame(maxWidth: .infinity)
        .frame(height: UIScreen.main.bounds.height * 0.7)
        .clipped()
        .offset(x: dragOffset)
        .rotationEffect(.degrees(Double(dragOffset) / 30), anchor: .bottom)
        .gesture(swipeGesture)
        .onTapGesture { showDetail = true }
        .fullScreenCover(isPresented: $showDetail) {
            FeedDetailView(item: item, onApprove: onApprove)
        }
    }

    private var cardImage: some View {
        Group {
            if let imageName = item.imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: UIScreen.main.bounds.height * 0.7)
                    .clipped()
            } else {
                Rectangle()
                    .fill(ENVITheme.Dark.surfaceLow)
            }
        }
    }

    @ViewBuilder
    private var swipeIndicators: some View {
        // Approve indicator (right swipe)
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

        // Disapprove indicator (left swipe)
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
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Spacer()

            // Caption
            Text(item.caption)
                .font(.interSemiBold(18))
                .foregroundColor(.white)
                .lineLimit(3)

            // Platform badge + stats
            HStack(spacing: ENVISpacing.md) {
                // Platform icon
                platformBadge

                Spacer()

                // Engagement stats
                HStack(spacing: ENVISpacing.lg) {
                    statLabel(icon: "heart.fill", value: formatCount(item.likes))
                    statLabel(icon: "bubble.left.fill", value: formatCount(item.comments))
                    statLabel(icon: "arrow.turn.up.right", value: formatCount(item.shares))
                }
            }

            // Creator info
            HStack(spacing: ENVISpacing.sm) {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(String(item.creatorName.prefix(1)))
                            .font(.interSemiBold(12))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 0) {
                    Text(item.creatorName)
                        .font(.interSemiBold(13))
                        .foregroundColor(.white)
                    Text(item.creatorHandle)
                        .font(.interRegular(11))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(ENVISpacing.xl)
    }

    private var platformBadge: some View {
        HStack(spacing: ENVISpacing.xs) {
            Image(systemName: item.platform.systemIconName)
                .font(.system(size: 14))
            Text(item.platform.rawValue)
                .font(.spaceMonoBold(11))
                .tracking(0.5)
        }
        .foregroundColor(.white)
        .padding(.horizontal, ENVISpacing.sm)
        .padding(.vertical, ENVISpacing.xs)
        .background(Color.white.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    private func statLabel(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(value)
                .font(.interMedium(11))
        }
        .foregroundColor(.white.opacity(0.8))
    }

    // MARK: - Swipe Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                dragOffset = value.translation.width
            }
            .onEnded { value in
                if value.translation.width > swipeThreshold {
                    // Approve
                    withAnimation(.easeOut(duration: 0.3)) {
                        dragOffset = UIScreen.main.bounds.width
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onApprove()
                    }
                } else if value.translation.width < -swipeThreshold {
                    // Disapprove
                    withAnimation(.easeOut(duration: 0.3)) {
                        dragOffset = -UIScreen.main.bounds.width
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onDisapprove()
                    }
                } else {
                    // Snap back
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Helpers

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - SocialPlatform Extension

private extension SocialPlatform {
    var systemIconName: String {
        switch self {
        case .instagram: return "camera.fill"
        case .tiktok:    return "play.rectangle.fill"
        case .x:         return "at"
        case .threads:   return "at.circle"
        case .linkedin:  return "briefcase.fill"
        case .youtube:   return "play.circle.fill"
        }
    }
}
