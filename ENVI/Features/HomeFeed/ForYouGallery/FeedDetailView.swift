import SwiftUI

/// Feed Detail — Sketch artboard "11 - Feed Detail" (393×1320, scrollable).
///
/// Layout, top to bottom:
///  • Hero (393×589) with platform tag overlay and top back/bookmark buttons
///  • INSTAGRAM row — platform label + handle left, bookmark right
///  • POST ANGLE card — muted grey fill, 3-line caption
///  • 2×2 STAT GRID — BEST TIME | EST. REACH / ENGAGEMENT | DISCUSSION
///  • WHY ENVI LIKES IT card — rationale blurb
///  • EDIT IN EDITOR button (red `#E20000`)
///  • CONTENT CALENDAR month grid
///
/// Bookmark toggle is optimistic through `ContentRepository.setBookmarked`
/// with rollback + inline toast on failure.
struct FeedDetailView: View {

    let item: ContentItem
    var onApprove: (() -> Void)?

    /// Repository driving the bookmark mutation. Defaulted so call-sites
    /// (ForYouSwipeView etc.) stay unchanged; tests inject a spy.
    var repository: ContentRepository = ContentRepositoryProvider.shared.repository

    @Environment(\.dismiss) private var dismiss

    private let heroHeight: CGFloat = 589

    // Shared design tokens pulled straight from the Sketch spec so the file
    // stays self-documenting.
    private let cardFill = Color(hex: "#3E3E3E")
    private let cardStroke = Color.white.opacity(0.12)
    private let cardCornerRadius: CGFloat = 18
    private let editRed = Color(hex: "#E20000")
    private let editRedLight = Color(hex: "#F20000")

    // MARK: - Bookmark state

    @State private var isBookmarked: Bool = false
    @State private var bookmarkErrorVisible: Bool = false
    @State private var bookmarkInFlight: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    hero

                    instagramRow
                        .padding(.top, 18)
                        .padding(.horizontal, 16)

                    postAngleCard
                        .padding(.top, 16)
                        .padding(.horizontal, 16)

                    statsGrid
                        .padding(.top, 14)
                        .padding(.horizontal, 16)

                    whyEnviCard
                        .padding(.top, 14)
                        .padding(.horizontal, 16)

                    editInEditorButton
                        .padding(.top, 20)
                        .padding(.horizontal, 16)

                    calendar
                        .padding(.top, 22)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 140)
                }
            }
            .ignoresSafeArea(edges: .top)

            topOverlays

            if bookmarkErrorVisible {
                bookmarkErrorToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            isBookmarked = item.isBookmarked
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            if let assetID = item.assetLocalIdentifier {
                ForYouAssetThumbnailView(
                    assetLocalIdentifier: assetID,
                    fallbackImageName: item.imageName,
                    contentMode: .fill
                )
                .frame(maxWidth: .infinity)
                .frame(height: heroHeight)
                .clipped()
            } else if let name = item.imageName, UIImage(named: name) != nil {
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: heroHeight)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(hex: "#4A5FB2"))
                    .frame(height: heroHeight)
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: heroHeight)
            .allowsHitTesting(false)

            platformTag
                .padding(.leading, 19)
                .padding(.bottom, 18)
        }
        .frame(height: heroHeight)
    }

    private var platformTag: some View {
        HStack(spacing: 6) {
            Image(systemName: item.platform.iconName)
                .font(.system(size: 11, weight: .semibold))
            Text("DESIGNED FOR \(item.platform.rawValue.uppercased())")
                .font(.spaceMonoBold(11))
                .tracking(1.2)
        }
        .foregroundColor(.white)
    }

    // MARK: - Top overlays (back + bookmark)

    private var topOverlays: some View {
        HStack(alignment: .top) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 11)

            Spacer()

            Button(action: toggleBookmark) {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Circle())
                    .scaleEffect(isBookmarked ? 1.08 : 1.0)
                    .animation(.spring(response: 0.28, dampingFraction: 0.6), value: isBookmarked)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 14)
            .accessibilityLabel("Bookmark")
            .accessibilityValue(isBookmarked ? "Bookmarked" : "Not bookmarked")
            .disabled(bookmarkInFlight)
        }
        .padding(.top, 36)
    }

    /// Optimistic bookmark toggle that reverts + shows a toast on failure.
    private func toggleBookmark() {
        let previous = isBookmarked
        let next = !previous

        isBookmarked = next
        bookmarkInFlight = true

        Task { @MainActor in
            defer { bookmarkInFlight = false }
            do {
                try await repository.setBookmarked(contentID: item.id, bookmarked: next)
            } catch {
                isBookmarked = previous
                withAnimation { bookmarkErrorVisible = true }
                try? await Task.sleep(for: .seconds(2))
                withAnimation { bookmarkErrorVisible = false }
            }
        }
    }

    private var bookmarkErrorToast: some View {
        VStack {
            Spacer().frame(height: 96)
            Text("Couldn't save bookmark. Try again.")
                .font(.interMedium(12))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.75))
                .clipShape(Capsule())
            Spacer()
        }
    }

    // MARK: - INSTAGRAM row

    private var instagramRow: some View {
        HStack(spacing: 10) {
            Image(systemName: item.platform.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Text(item.platform.rawValue.uppercased())
                .font(.spaceMonoBold(12))
                .tracking(1.7)
                .foregroundColor(.white)

            Text(item.creatorHandle)
                .font(.interRegular(13))
                .foregroundColor(.white.opacity(0.58))
                .lineLimit(1)

            Spacer()

            Button(action: toggleBookmark) {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .disabled(bookmarkInFlight)
        }
        .frame(height: 28)
    }

    // MARK: - Post Angle Card

    private var postAngleCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("POST ANGLE")
                .font(.spaceMonoBold(10))
                .tracking(2.0)
                .foregroundColor(.white.opacity(0.48))
            Text(item.caption)
                .font(.interSemiBold(15))
                .foregroundColor(.white)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(cardFill)
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    }

    // MARK: - 2×2 Stat Grid — BEST TIME | EST. REACH / ENGAGEMENT | DISCUSSION

    private var statsGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                statCell(
                    systemName: "clock.fill",
                    value: item.bestTime,
                    label: "BEST TIME"
                )
                statCell(
                    systemName: "eye.fill",
                    value: item.estimatedReach,
                    label: "EST. REACH"
                )
            }
            HStack(spacing: 10) {
                statCell(
                    systemName: "sparkles",
                    value: "\(Int(item.confidenceScore * 100))%",
                    label: "ENGAGEMENT"
                )
                statCell(
                    systemName: "bubble.left.and.bubble.right.fill",
                    value: formattedDiscussion,
                    label: "DISCUSSION"
                )
            }
        }
    }

    /// Compact display for the total of comments + shares.
    private var formattedDiscussion: String {
        let total = item.comments + item.shares
        if total >= 1000 {
            let k = Double(total) / 1000.0
            return String(format: "%.1fK", k)
        }
        return "\(total)"
    }

    private func statCell(systemName: String, value: String, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.interSemiBold(14))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(label)
                    .font(.spaceMonoBold(9))
                    .tracking(1.3)
                    .foregroundColor(.white.opacity(0.55))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(cardFill)
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    }

    // MARK: - Why ENVI Likes It

    private var whyEnviCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHY ENVI LIKES IT")
                .font(.spaceMonoBold(10))
                .tracking(2.0)
                .foregroundColor(.white.opacity(0.48))

            Text(whyEnviCopy)
                .font(.interRegular(13))
                .foregroundColor(.white.opacity(0.84))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(cardFill)
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    }

    private var whyEnviCopy: String {
        let scorePct = Int(item.confidenceScore * 100)
        let platformName = item.platform.rawValue
        return "Matches a \(scorePct)% confidence pattern across recent \(platformName) content. Strong visual pacing, an on-brand subject, and posting during your peak window makes this a high-leverage post."
    }

    // MARK: - Edit in Editor — red CTA

    private var editInEditorButton: some View {
        Button {
            onApprove?()
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .semibold))
                Text("EDIT IN EDITOR")
                    .font(.spaceMonoBold(12))
                    .tracking(1.8)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                LinearGradient(
                    colors: [editRedLight, editRed],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: editRed.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Calendar

    private var calendar: some View {
        ContentCalendarView(days: AnalyticsData.mock.calendarDays)
    }
}

#Preview {
    FeedDetailView(item: ContentItem.mockFeed[0])
}
