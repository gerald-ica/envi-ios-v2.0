import SwiftUI

/// Chat input bar with text field, send button, and tool chips.
struct ChatInputBar: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: ENVISpacing.sm) {
            // Tool chips
            HStack(spacing: ENVISpacing.sm) {
                ToolChip(icon: "paperclip", label: "Attach")
                ToolChip(icon: "mic.fill", label: "Voice")
                ToolChip(icon: "video.fill", label: "Edit Video")
                Spacer()
            }
            .padding(.horizontal, ENVISpacing.lg)

            // Input field
            HStack(spacing: ENVISpacing.sm) {
                TextField("Ask ENVI AI...", text: $viewModel.inputText)
                    .font(.interRegular(15))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.lg)
                    .padding(.vertical, ENVISpacing.md)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(Capsule())

                Button(action: { viewModel.sendMessage() }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(
                            viewModel.inputText.isEmpty
                                ? ENVITheme.textLight(for: colorScheme)
                                : ENVITheme.primary(for: colorScheme)
                        )
                }
                .disabled(viewModel.inputText.isEmpty)
            }
            .padding(.horizontal, ENVISpacing.lg)
        }
        .padding(.vertical, ENVISpacing.sm)
        .background(ENVITheme.background(for: colorScheme))
    }
}

private struct ToolChip: View {
    let icon: String
    let label: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
            Text(label)
                .font(.interMedium(12))
        }
        .foregroundColor(ENVITheme.textLight(for: colorScheme))
        .padding(.horizontal, ENVISpacing.md)
        .padding(.vertical, ENVISpacing.sm)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(Capsule())
    }
}
