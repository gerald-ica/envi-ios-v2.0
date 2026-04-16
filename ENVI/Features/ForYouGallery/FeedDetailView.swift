import SwiftUI

/// Full-screen detail view when a content piece is tapped in For You.
///
/// Shows a large hero image, platform badge, caption, compact metric
/// tiles, creator info, and action buttons in the same dark language as
/// the main feed.
struct FeedDetailView: View {

    let item: ContentItem
    var onApprove: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                backgroundLayer
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                        heroImage(containerHeight: geo.size.height)
                            .padding(.top, ENVISpacing.sm)

                        VStack(alignment: .leading, spacing: ENVISpacing.md) {
                            platformBadge

                            Text(item.caption)
                                .font(.spaceMonoBold(22))
                                .tracking(-0.8)
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)

                            if let bodyText = item.bodyText {
                                Text(bodyText)
                                    .font(.interRegular(14))
                                    .foregroundColor(.white.opacity(0.68))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            metricsRow

                            creatorRow

                            actionButtons
                        }
                        .padding(ENVISpacing.xl)
                        .background(ENVITheme.Dark.surfaceLow.opacity(0.88))
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .padding(.horizontal, ENVISpacing.lg)
                    }
                    .padding(.bottom, 128)
                }

                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(ENVITheme.Dark.surfaceLow.opacity(0.9))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, ENVISpacing.lg)
                    .padding(.top, ENVISpacing.sm)

                    Spacer()
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            Color.black

            LinearGradient(
                colors: [Color(hex: "#090909"), Color(hex: "#000000")],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [Color.white.opacity(0.05), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 320
            )
        }
    }

    // MARK: - Hero Image

    private func heroImage(containerHeight: CGFloat) -> some View {
        Group {
            if let imageName = item.imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: containerHeight * 0.44)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [
                        ENVITheme.Dark.surfaceLow,
                        Color.black.opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: containerHeight * 0.44)
            }
        }
        .frame(maxWidth: .infinity)
        .background(ENVITheme.Dark.surfaceLow.opacity(0.92))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
        .padding(.horizontal, ENVISpacing.lg)
    }

    // MARK: - Platform Badge

    private var platformBadge: some View {
        HStack(spacing: ENVISpacing.xs) {
            Image(systemName: "camera.fill")
                .font(.system(size: 12, weight: .semibold))
            Text("DESIGNED FOR \(item.platform.rawValue.uppercased())")
                .font(.spaceMonoBold(11))
                .tracking(1.2)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    // MARK: - Metrics

    private var metricsRow: some View {
        HStack(spacing: ENVISpacing.sm) {
            metricTile(
                label: "REACH",
                value: item.estimatedReach,
                tint: ENVITheme.info
            )
            metricTile(
                label: "TIME",
                value: item.bestTime,
                tint: ENVITheme.warning
            )
            metricTile(
                label: "SCORE",
                value: "\(Int(item.confidenceScore * 100))%",
                tint: ENVITheme.success
            )
        }
    }

    private func metricTile(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.spaceMonoBold(9))
                .tracking(1.4)
                .foregroundColor(.white.opacity(0.48))

            Text(value)
                .font(.interSemiBold(15))
                .foregroundColor(.white)
                .lineLimit(1)

            Rectangle()
                .fill(tint)
                .frame(width: 24, height: 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Creator

    private var creatorRow: some View {
        HStack(spacing: ENVISpacing.md) {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 42, height: 42)
                .overlay(
                    Text(String(item.creatorName.prefix(1)))
                        .font(.interSemiBold(16))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.creatorName)
                    .font(.interSemiBold(15))
                    .foregroundColor(.white)
                Text(item.creatorHandle)
                    .font(.interRegular(13))
                    .foregroundColor(.white.opacity(0.56))
            }

            Spacer()
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: ENVISpacing.md) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: ENVISpacing.sm) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                    Text("BACK TO FEED")
                        .font(.spaceMonoBold(13))
                        .tracking(1.5)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ENVITheme.Dark.surfaceLow)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)

            if let onApprove {
                Button {
                    onApprove()
                    dismiss()
                } label: {
                    HStack(spacing: ENVISpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("APPROVE TO ARSENAL")
                            .font(.spaceMonoBold(13))
                            .tracking(1.5)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    FeedDetailView(
        item: ContentItem.mockFeed[0],
        onApprove: {}
    )
}
