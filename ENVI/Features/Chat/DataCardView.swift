import SwiftUI

/// Inline analytics card displayed in chat responses.
struct DataCardView: View {
    let dataCard: ChatMessage.DataCard
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text(dataCard.title.uppercased())
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            ForEach(dataCard.metrics) { metric in
                HStack {
                    Text(metric.label)
                        .font(.interRegular(14))
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))

                    Spacer()

                    Text(metric.value)
                        .font(.interSemiBold(14))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    if let change = metric.change {
                        Text(change)
                            .font(.spaceMono(11))
                            .foregroundColor(metric.isPositive ? ENVITheme.success : ENVITheme.error)
                    }
                }
                .padding(.vertical, ENVISpacing.xs)

                if metric.id != dataCard.metrics.last?.id {
                    Divider()
                        .background(ENVITheme.border(for: colorScheme))
                }
            }
        }
        .padding(ENVISpacing.lg)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }
}
