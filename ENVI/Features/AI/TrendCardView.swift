import SwiftUI

/// Individual trend card displaying topic name, momentum bar, platform badges,
/// related hashtags, and a "Use This" action button.
struct TrendCardView: View {
    let trend: TrendTopic
    let onUse: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            // Header: topic + category
            HStack {
                Text(trend.topic)
                    .font(.interSemiBold(15))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .lineLimit(2)

                Spacer()

                Text(trend.category.uppercased())
                    .font(.spaceMono(9))
                    .tracking(0.5)
                    .padding(.horizontal, ENVISpacing.sm)
                    .padding(.vertical, 2)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }

            // Momentum bar
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("MOMENTUM")
                        .font(.spaceMono(8))
                        .tracking(0.5)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    Spacer()

                    Text("\(Int(trend.momentum))%")
                        .font(.spaceMonoBold(11))
                        .foregroundColor(momentumColor)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ENVITheme.border(for: colorScheme))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(momentumColor)
                            .frame(width: geo.size.width * trend.momentum / 100, height: 6)
                    }
                }
                .frame(height: 6)
            }

            // Platform badges
            HStack(spacing: ENVISpacing.xs) {
                ForEach(trend.platforms) { platform in
                    HStack(spacing: 3) {
                        Image(systemName: platform.iconName)
                            .font(.system(size: 9))
                        Text(platform.rawValue)
                            .font(.spaceMono(9))
                    }
                    .padding(.horizontal, ENVISpacing.sm)
                    .padding(.vertical, 3)
                    .foregroundColor(platform.brandColor)
                    .background(platform.brandColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                }
            }

            // Related hashtags
            if !trend.relatedHashtags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ENVISpacing.xs) {
                        ForEach(trend.relatedHashtags, id: \.self) { hashtag in
                            Text(hashtag)
                                .font(.spaceMono(10))
                                .foregroundColor(ENVITheme.accent)
                        }
                    }
                }
            }

            // Use This button
            HStack {
                Spacer()
                Button(action: onUse) {
                    HStack(spacing: ENVISpacing.xs) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .medium))
                        Text("Use This")
                            .font(.interMedium(12))
                    }
                    .padding(.horizontal, ENVISpacing.md)
                    .padding(.vertical, ENVISpacing.sm)
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.sm)
                            .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                    )
                }
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    private var momentumColor: Color {
        if trend.momentum > 80 { return .green }
        if trend.momentum > 50 { return .orange }
        return ENVITheme.error
    }
}

#Preview {
    VStack(spacing: 12) {
        TrendCardView(trend: TrendTopic.mockList[0]) {}
        TrendCardView(trend: TrendTopic.mockList[1]) {}
    }
    .padding()
    .preferredColorScheme(.dark)
}
