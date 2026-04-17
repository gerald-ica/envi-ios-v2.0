import SwiftUI

/// Feed Detail — Sketch artboard "11a - Feed Detail" (393×1320, scrollable).
///
/// Full-bleed hero image (589pt), back + bookmark overlays, platform tag,
/// a Post Angle caption card, a 3-stat row (EST. REACH, BEST TIME,
/// ENVI SCORE), an Edit CTA, and the month Content Calendar. The
/// alternate 2×2 stat layout lives in `FeedDetailAltView` (11b).
struct FeedDetailView: View {

    let item: ContentItem
    var onApprove: (() -> Void)?

    /// Repository driving the bookmark mutation. Defaulted so call-sites
    /// (ForYouSwipeView etc.) stay unchanged; tests inject a spy.
    var repository: ContentRepository = ContentRepositoryProvider.shared.repository

    @Environment(\.dismiss) private var dismiss

    private let heroHeight: CGFloat = 589

    // MARK: - Bookmark state
    //
    // `isBookmarked` ships with `ContentItem` (default false) — we drive a local
    // `@State` mirror so the tap feels instant. On repo failure we rebind to
    // the prior value + surface a brief inline toast.
    @State private var isBookmarked: Bool = false
    @State private var bookmarkErrorVisible: Bool = false
    @State private var bookmarkInFlight: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    hero
                    postAngleCard
                        .padding(.top, ENVISpacing.xl)
                        .padding(.horizontal, 19)
                    statsRow
                        .padding(.top, ENVISpacing.lg)
                        .padding(.horizontal, 19)
                    editButton
                        .padding(.top, ENVISpacing.xxl)
                        .padding(.horizontal, 16)
                    calendar
                        .padding(.top, ENVISpacing.xl)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 120)
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
            // Seed local mirror from the ContentItem default the first time the
            // sheet appears. Subsequent toggles drive state directly.
            isBookmarked = item.isBookmarked
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            if let name = item.imageName, UIImage(named: name) != nil {
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

    /// Toggles the bookmark optimistically, then persists via `ContentRepository`.
    /// On failure: reverts the icon + surfaces a 2-second inline toast so the
    /// user knows the write did not land.
    private func toggleBookmark() {
        let previous = isBookmarked
        let next = !previous

        // Optimistic flip first — UI responds instantly.
        isBookmarked = next
        bookmarkInFlight = true

        Task { @MainActor in
            defer { bookmarkInFlight = false }
            do {
                try await repository.setBookmarked(contentID: item.id, bookmarked: next)
            } catch {
                // Rollback — restore the pre-tap state and flash the toast.
                isBookmarked = previous
                withAnimation { bookmarkErrorVisible = true }
                try? await Task.sleep(for: .seconds(2))
                withAnimation { bookmarkErrorVisible = false }
            }
        }
    }

    /// Subtle inline error banner shown briefly when bookmark write fails.
    /// Kept non-modal so it doesn't block the hero or require a tap to dismiss.
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
        .background(Color(hex: "#2A2A2A"))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Stats row — EST. REACH | BEST TIME | ENVI SCORE

    private var statsRow: some View {
        HStack(spacing: 0) {
            stat(
                icon: AnyView(eyeIcon),
                value: item.estimatedReach,
                label: "EST.\nREACH"
            )
            statDivider
            stat(
                icon: AnyView(clockIcon),
                value: item.bestTime,
                label: "BEST\nTIME"
            )
            statDivider
            stat(
                icon: AnyView(sparkIcon),
                value: "\(Int(item.confidenceScore * 100))%",
                label: "ENVI\nSCORE"
            )
        }
        .padding(.vertical, 20)
        .background(Color(hex: "#2A2A2A"))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 44)
    }

    private func stat(icon: AnyView, value: String, label: String) -> some View {
        HStack(spacing: 10) {
            icon
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.interSemiBold(14))
                    .foregroundColor(.white)
                Text(label)
                    .font(.spaceMonoBold(9))
                    .tracking(1.3)
                    .foregroundColor(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var eyeIcon: some View {
        Image(systemName: "eye.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
    }

    private var clockIcon: some View {
        Image(systemName: "clock.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
    }

    private var sparkIcon: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
    }

    // MARK: - Edit button

    private var editButton: some View {
        Button {
            onApprove?()
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .semibold))
                Text("EDIT")
                    .font(.spaceMonoBold(12))
                    .tracking(1.8)
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
