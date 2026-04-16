import SwiftUI

/// Full-screen detail view when a content piece is tapped in For You.
///
/// Shows full-screen image, platform badge, caption, metric circles
/// (Reach, Time, Score), and an "EDIT IN EDITOR" button.
struct FeedDetailView: View {

    let item: ContentItem
    var onApprove: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color.black.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                    // Hero image
                    heroImage

                    // Platform badge
                    platformBadge
                        .padding(.horizontal, ENVISpacing.xl)

                    // Caption
                    Text(item.caption)
                        .font(.interSemiBold(18))
                        .foregroundColor(.white)
                        .padding(.horizontal, ENVISpacing.xl)

                    if let bodyText = item.bodyText {
                        Text(bodyText)
                            .font(.interRegular(14))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, ENVISpacing.xl)
                    }

                    // Metric circles
                    metricsRow
                        .padding(.horizontal, ENVISpacing.xl)

                    // Creator info
                    creatorRow
                        .padding(.horizontal, ENVISpacing.xl)

                    // Action buttons
                    actionButtons
                        .padding(.horizontal, ENVISpacing.xl)

                    Spacer().frame(height: 40)
                }
            }

            // Close button
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .padding(.leading, ENVISpacing.xl)
                .padding(.top, ENVISpacing.sm)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Hero Image

    private var heroImage: some View {
        Group {
            if let imageName = item.imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: UIScreen.main.bounds.height * 0.45)
                    .clipped()
            } else {
                Rectangle()
                    .fill(ENVITheme.Dark.surfaceLow)
                    .frame(height: UIScreen.main.bounds.height * 0.45)
            }
        }
    }

    // MARK: - Platform Badge

    private var platformBadge: some View {
        HStack(spacing: ENVISpacing.sm) {
            Image(systemName: "camera.fill")
                .font(.system(size: 12))
            Text("DESIGNED FOR \(item.platform.rawValue.uppercased())")
                .font(.spaceMonoBold(11))
                .tracking(1.2)
        }
        .foregroundColor(.white)
        .padding(.horizontal, ENVISpacing.md)
        .padding(.vertical, ENVISpacing.sm)
        .background(Color.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    // MARK: - Metrics

    private var metricsRow: some View {
        HStack(spacing: ENVISpacing.xxl) {
            metricCircle(
                label: "REACH",
                value: item.estimatedReach,
                color: ENVITheme.info
            )
            metricCircle(
                label: "TIME",
                value: item.bestTime,
                color: ENVITheme.warning
            )
            metricCircle(
                label: "SCORE",
                value: "\(Int(item.confidenceScore * 100))",
                color: ENVITheme.success
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func metricCircle(label: String, value: String, color: Color) -> some View {
        VStack(spacing: ENVISpacing.sm) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 4)
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0, to: item.confidenceScore)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))

                Text(value)
                    .font(.interSemiBold(14))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
            }

            Text(label)
                .font(.spaceMonoBold(10))
                .tracking(1.5)
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Creator

    private var creatorRow: some View {
        HStack(spacing: ENVISpacing.md) {
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 40, height: 40)
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
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: ENVISpacing.md) {
            // Edit in Editor button
            Button {
                // Navigation to EditorViewController handled via UIKit bridge
                dismiss()
            } label: {
                HStack(spacing: ENVISpacing.sm) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                    Text("EDIT IN EDITOR")
                        .font(.spaceMonoBold(13))
                        .tracking(1.5)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ENVISpacing.md)
                .background(ENVITheme.error)
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            }
            .buttonStyle(.plain)

            // Approve button
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
                    .padding(.vertical, ENVISpacing.md)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
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
