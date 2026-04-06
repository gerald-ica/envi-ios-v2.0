import SwiftUI

/// Dashboard section showing source/channel attribution for followers and engagement.
struct SourceAttributionView: View {
    let attributions: [SourceAttribution]
    @Environment(\.colorScheme) private var colorScheme

    private var sorted: [SourceAttribution] {
        attributions.sorted { $0.conversions > $1.conversions }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("SOURCE ATTRIBUTION")
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            ForEach(sorted) { item in
                HStack(spacing: ENVISpacing.sm) {
                    // Source + channel
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.source)
                            .font(.interMedium(12))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                        if let channel = item.channel {
                            Text(channel)
                                .font(.interRegular(11))
                                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                        }
                    }

                    Spacer()

                    // Visitors
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(item.visitors)")
                            .font(.spaceMono(11))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                        Text("visitors")
                            .font(.interRegular(9))
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                    }

                    // Conversions
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(item.conversions)")
                            .font(.spaceMono(11))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                        Text("converted")
                            .font(.interRegular(9))
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                    }

                    // Conversion rate badge
                    Text(String(format: "%.1f%%", item.conversionRate))
                        .font(.spaceMono(10))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .padding(.horizontal, ENVISpacing.sm)
                        .padding(.vertical, 4)
                        .background(ENVITheme.background(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                }
            }
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }
}
