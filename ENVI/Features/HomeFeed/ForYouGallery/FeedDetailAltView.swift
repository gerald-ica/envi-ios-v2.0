import SwiftUI

/// Alternate Feed Detail — Sketch artboard "11b - Feed Detail (Alt)" (393×1320).
///
/// Same hero treatment as 11a but uses a 2×2 stat grid (BEST TIME,
/// EST. REACH, ENGAGEMENT, DISCUSSION) on dark `#3D3D3D` cards and a
/// "CAPTION"-prefixed Post Angle card. Content Calendar at bottom.
struct FeedDetailAltView: View {

    let item: ContentItem
    var engagementRate: String = "8.4%"
    var discussionCount: String = "124"

    @Environment(\.dismiss) private var dismiss

    private let heroHeight: CGFloat = 586
    private let cardBG = Color(hex: "#3D3D3D")

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    hero
                    captionCard
                        .padding(.top, ENVISpacing.xl)
                        .padding(.horizontal, 16)
                    statsGrid
                        .padding(.top, ENVISpacing.lg)
                        .padding(.horizontal, 16)
                    calendar
                        .padding(.top, ENVISpacing.xxl)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 120)
                }
            }
            .ignoresSafeArea(edges: .top)

            topOverlays
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .topTrailing) {
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

            aiScorePreviews
                .padding(.top, 44)
                .padding(.trailing, 16)
        }
        .frame(height: heroHeight)
    }

    private var aiScorePreviews: some View {
        VStack(alignment: .trailing, spacing: 4) {
            scorePill(system: "sparkles", text: "\(Int(item.confidenceScore * 100))%")
            scorePill(system: "clock.fill", text: item.bestTime)
            scorePill(system: "eye.fill", text: item.estimatedReach)
        }
    }

    private func scorePill(system: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: system)
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

    // MARK: - Top overlays

    private var topOverlays: some View {
        HStack {
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
        }
        .padding(.top, 22)
    }

    // MARK: - Caption card

    private var captionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CAPTION")
                .font(.spaceMonoBold(11))
                .tracking(1.8)
                .foregroundColor(.white.opacity(0.55))
            Text(item.caption)
                .font(.interSemiBold(15))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 2×2 stats grid

    private var statsGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                statCell(icon: "clock.fill", label: "BEST TIME", value: item.bestTime)
                statCell(icon: "eye.fill", label: "EST. REACH", value: item.estimatedReach)
            }
            HStack(spacing: 8) {
                statCell(icon: "sparkles", label: "ENGAGEMENT", value: engagementRate)
                statCell(icon: "bubble.left.fill", label: "DISCUSSION", value: discussionCount)
            }
        }
    }

    private func statCell(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.spaceMonoBold(10))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.55))
                Text(value)
                    .font(.interSemiBold(14))
                    .foregroundColor(.white)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Calendar

    private var calendar: some View {
        ContentCalendarView(days: AnalyticsData.mock.calendarDays)
    }
}

#Preview {
    FeedDetailAltView(item: ContentItem.mockFeed[0])
}
