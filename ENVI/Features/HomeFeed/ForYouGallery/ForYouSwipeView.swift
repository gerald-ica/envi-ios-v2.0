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
                        // Infinite scroll: trigger a top-up when one of the
                        // trailing cards scrolls into view. Fires well before
                        // the actual bottom so the user never perceives a
                        // stall — ViewModel no-ops if a top-up is already in
                        // flight or the buffer is already saturated.
                        .onAppear {
                            let total = viewModel.forYouItems.count
                            if index >= total - 3 {
                                Task { await viewModel.topUpIfNeeded() }
                            }
                        }
                    }
                }
                .frame(width: resolvedScreenWidth)
                .padding(.bottom, 136)
            }
            .frame(width: resolvedScreenWidth)
        }
        // Pull-to-refresh: drags the spinner and re-runs the camera-roll
        // pipeline from offset 0 with the seen-log cleared, so the user
        // can actively re-explore their roll.
        .refreshable {
            await viewModel.refresh()
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
            if let assetID = item.assetLocalIdentifier {
                ForYouAssetThumbnailView(
                    assetLocalIdentifier: assetID,
                    fallbackImageName: item.imageName,
                    contentMode: .fill
                )
            } else if let imageName = item.imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
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
        // Hard-constrain to the card's exact size so a .fill image cannot
        // inflate its parent ZStack and blow up the caption's wrap width.
        .frame(width: cardWidth, height: cardHeight)
        .clipped()
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
    /// vertically at the top-right of the card. Icons are exported from
    /// the Sketch source file:
    /// - Confidence: icon-confidence.png (15×15) — ENVI AI ICON - CONFIDENCE
    /// - Best time:  icon-clock.png      (15×15) — Shape 01
    /// - Reach:      icon-reach.svg      (vector) — Reach icon symbol
    private var aiScorePreviews: some View {
        VStack(alignment: .trailing, spacing: 4) {
            scorePill(
                bitmap: "icon-confidence",
                size: CGSize(width: 13, height: 13),
                text: "\(Int(item.confidenceScore * 100))%"
            )
            scorePill(
                bitmap: "icon-clock",
                size: CGSize(width: 13, height: 13),
                text: item.bestTime
            )
            // Sketch source was exported at 11×11 but reads visually
            // smaller than confidence/clock (both 15×15 source). Scale it
            // up so the three pills feel like one family at a glance.
            scorePill(
                bitmap: "icon-reach",
                size: CGSize(width: 16, height: 16),
                text: item.estimatedReach
            )
        }
    }

    private func scorePill(bitmap: String, size: CGSize, text: String) -> some View {
        HStack(spacing: 5) {
            Image(bitmap)
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
            Text(text)
                .font(.interSemiBold(11))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    /// Whether this card should render the text caption + body preview
    /// over the media. Text-first surfaces (Threads, X) benefit from
    /// the preview; visual-first surfaces (Instagram, TikTok) do not.
    private var showsCaptionPreview: Bool {
        switch item.platform {
        case .threads, .x: return true
        default: return false
        }
    }

    /// Card foreground content — Sketch content-card "feed piece".
    /// Caption block anchors to the bottom of the card with a 20pt inset on
    /// all sides; the platform badge, handle, and bookmark live on a
    /// dedicated meta-row directly beneath the caption. A small 6pt gap
    /// separates the caption from the meta-row so they read as a group
    /// rather than an afterthought flush to the rim.
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer(minLength: 0)

            // Caption + body preview only read naturally on text-first
            // surfaces (Threads, X). For visual-first surfaces
            // (Instagram, TikTok) we let the media carry the card and
            // drop the preview so the creative isn't double-captioned.
            if showsCaptionPreview {
                Text(item.caption)
                    .font(.spaceMonoBold(20))
                    .tracking(-0.2)
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.45), radius: 6, y: 2)

                if let bodyText = item.bodyText {
                    Text(bodyText)
                        .font(.interRegular(13))
                        .foregroundColor(.white.opacity(0.72))
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                }
            }

            // Meta row — Sketch: platform badge (bottom-left) + handle +
            // bookmark (bottom-right). Spacing reset so the badge hugs the
            // handle rather than floating away.
            HStack(alignment: .center, spacing: 8) {
                platformBadge

                Text(item.creatorHandle)
                    .font(.interMedium(13))
                    .foregroundColor(.white.opacity(0.82))
                    .lineLimit(1)

                Spacer(minLength: 8)

                // Sketch "Graphic" (C8AB65C5) — 24×24 decorative/action
                // glyph anchored to the bottom-right of the card. Wired
                // to the bookmark toggle so the visible state still
                // tracks `item.isBookmarked` (icon dims when unset).
                Button(action: onBookmark) {
                    Image("card-graphic")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .opacity(item.isBookmarked ? 1.0 : 0.9)
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 1)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .padding(.top, 16)
    }

    /// Sketch "Platform Badge" (78F99BC1) — 18×19 platform chip that
    /// sits flush-left on the meta-row, immediately before the user's
    /// real social handle. Rendered as the exact PNG exported from the
    /// Sketch source so the logo reads as designed (no SF-Symbol swap).
    private var platformBadge: some View {
        Image("platform-badge")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 22, height: 22)
            .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
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
