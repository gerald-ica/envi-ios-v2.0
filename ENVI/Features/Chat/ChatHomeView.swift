import SwiftUI

/// Landing state for the Chat screen — shows ENVI AI badge and quick actions.
struct ChatHomeView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: ENVISpacing.xxl) {
            Spacer()

            // AI Badge
            ENVIBadge(text: "ENVI AI", color: ENVITheme.primary(for: colorScheme))

            // Title
            Text("How can I help\nyou create?")
                .font(.interBlack(32))
                .multilineTextAlignment(.center)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            // Quick action chips
            VStack(spacing: ENVISpacing.sm) {
                ForEach(viewModel.quickActions, id: \.self) { action in
                    Button(action: { viewModel.selectQuickAction(action) }) {
                        HStack {
                            Text(action)
                                .font(.interRegular(14))
                                .foregroundColor(ENVITheme.text(for: colorScheme))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                        }
                        .padding(.horizontal, ENVISpacing.lg)
                        .padding(.vertical, ENVISpacing.md)
                        .background(ENVITheme.surfaceLow(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                    }
                }
            }
            .padding(.horizontal, ENVISpacing.xxl)

            Spacer()
            Spacer()
        }
    }
}
