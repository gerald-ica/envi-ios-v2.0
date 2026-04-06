import SwiftUI

struct ContentPlanningSectionView: View {
    let items: [ContentPlanItem]
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            HStack {
                Text("CONTENT PLAN")
                    .font(.spaceMono(11))
                    .tracking(0.88)
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if let errorMessage {
                HStack {
                    Text(errorMessage)
                        .font(.interRegular(12))
                        .foregroundColor(.red)
                    Spacer()
                    Button("Retry", action: onRetry)
                        .font(.interMedium(12))
                }
                .padding(.vertical, ENVISpacing.xs)
            }

            ForEach(items.prefix(5)) { item in
                HStack(spacing: ENVISpacing.sm) {
                    Circle()
                        .fill(item.platform.brandColor)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.interMedium(13))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                        Text(scheduleLabel(for: item))
                            .font(.interRegular(11))
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                    }

                    Spacer()

                    Text(item.status.rawValue.uppercased())
                        .font(.spaceMono(9))
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                }
                .padding(.vertical, ENVISpacing.xs)
            }
        }
    }

    private func scheduleLabel(for item: ContentPlanItem) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return "\(item.platform.rawValue) • \(formatter.string(from: item.scheduledAt))"
    }
}
