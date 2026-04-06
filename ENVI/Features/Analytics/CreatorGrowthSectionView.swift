import SwiftUI

struct CreatorGrowthSectionView: View {
    let growth: CreatorGrowthSnapshot
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("CREATOR GROWTH")
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            HStack(spacing: ENVISpacing.md) {
                metricTile(title: "Follower Growth", value: String(format: "%.1f%%", growth.followerGrowthPercent))
                metricTile(title: "Net New", value: "+\(growth.netNewFollowers)")
                metricTile(title: "Retention", value: String(format: "%.1f%%", growth.weeklyRetentionPercent))
            }

            Text("Top channel: \(growth.topPerformingPlatform.rawValue)")
                .font(.interRegular(12))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            ForEach(growth.channels) { channel in
                HStack {
                    Circle()
                        .fill(channel.platform.brandColor)
                        .frame(width: 8, height: 8)
                    Text(channel.platform.rawValue)
                        .font(.interMedium(12))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                    Spacer()
                    Text("+\(channel.netFollowers)")
                        .font(.spaceMono(11))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                    Text(String(format: "(%.1f%%)", channel.growthPercent))
                        .font(.interRegular(11))
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                }
            }
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    private func metricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.interRegular(11))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))
            Text(value)
                .font(.spaceMonoBold(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
