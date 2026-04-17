import SwiftUI

/// Landing state for the enhanced chat — editorial layout with large heading,
/// quick-action chips in a wrapping flow layout, and underline-style text input.
struct EnhancedChatHomeView: View {
    @ObservedObject var viewModel: EnhancedChatViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: - Header label "[01] ENVI AI"
                HStack(spacing: ENVISpacing.md) {
                    Text("[01]")
                        .font(.spaceMono(11))
                        .foregroundColor(ENVITheme.text(for: colorScheme).opacity(0.3))

                    Text("ENVI AI")
                        .font(.spaceMonoBold(11))
                        .tracking(11 * 0.15) // 0.15em tracking
                        .textCase(.uppercase)
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }
                .padding(.bottom, 40)

                // MARK: - Display heading
                Text("HOW CAN I\nHELP YOU\nCREATE?")
                    .font(.interBlack(32))
                    .tracking(-0.5)
                    .lineSpacing(-4)
                    .textCase(.uppercase)
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .padding(.bottom, ENVISpacing.xl)

                // MARK: - Subtitle
                Text("Ask about your patterns, connections, or get personalized insights.")
                    .font(.spaceMono(12))
                    .foregroundColor(ENVITheme.text(for: colorScheme).opacity(0.5))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, ENVISpacing.xxxl)

                // MARK: - Quick action chips (wrapping flow)
                FlowLayout(horizontalSpacing: ENVISpacing.sm, verticalSpacing: ENVISpacing.sm) {
                    ForEach(viewModel.quickActions, id: \.self) { action in
                        Button(action: { viewModel.selectQuickAction(action) }) {
                            Text(action.uppercased())
                                .font(.spaceMono(11))
                                .tracking(11 * 0.08) // 0.08em tracking
                                .foregroundColor(ENVITheme.text(for: colorScheme).opacity(0.7))
                                .padding(.horizontal, 14)
                                .padding(.vertical, ENVISpacing.sm)
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            ENVITheme.text(for: colorScheme).opacity(0.2),
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, ENVISpacing.xxxl)

                // MARK: - Divider
                Rectangle()
                    .fill(ENVITheme.border(for: colorScheme))
                    .frame(height: 1)
                    .padding(.bottom, ENVISpacing.xxxl)

                // Removed Message input area
            }
            .padding(.horizontal, ENVISpacing.xxl)
            .padding(.top, 80)
            .padding(.bottom, ENVISpacing.xxxl)
        }
    }
}

#Preview {
    EnhancedChatHomeView(viewModel: EnhancedChatViewModel())
        .background(Color.black)
        .preferredColorScheme(.dark)
}
