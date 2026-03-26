import SwiftUI

/// Bottom input bar for the enhanced chat — tool chips row + underline text input with send button.
struct EnhancedChatInputBar: View {
    @State private var text: String = ""
    let onSend: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: ENVISpacing.md) {

            // MARK: - Tool chips row
            HStack(spacing: ENVISpacing.sm) {
                InputToolChip(icon: "paperclip", label: "Attach")
                InputToolChip(icon: "mic", label: "Voice")
                InputToolChip(icon: "clock", label: "Timeline")
                Spacer()
            }

            // MARK: - Input row
            HStack(alignment: .bottom, spacing: ENVISpacing.md) {
                // Underline-style text field
                TextField("Ask ENVI anything...", text: $text)
                    .font(.spaceMono(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .padding(.bottom, ENVISpacing.sm)
                    .overlay(
                        Rectangle()
                            .fill(ENVITheme.text(for: colorScheme).opacity(0.2))
                            .frame(height: 1),
                        alignment: .bottom
                    )
                    .onSubmit {
                        handleSend()
                    }

                // Circular send button — only visible when text is non-empty
                if hasText {
                    Button(action: { handleSend() }) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(
                                colorScheme == .dark
                                    ? Color.black
                                    : Color.white
                            )
                            .frame(width: 36, height: 36)
                            .background(ENVITheme.text(for: colorScheme))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: hasText)
        }
        .padding(.horizontal, ENVISpacing.lg)
        .padding(.top, ENVISpacing.md)
        .padding(.bottom, ENVISpacing.sm)
        .background(ENVITheme.background(for: colorScheme))
        .overlay(
            Rectangle()
                .fill(ENVITheme.border(for: colorScheme))
                .frame(height: 1),
            alignment: .top
        )
    }

    private func handleSend() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onSend(trimmed)
        text = ""
    }
}

// MARK: - Input Tool Chip (private to this file)

/// Small bordered chip for tool actions in the input bar.
private struct InputToolChip: View {
    let icon: String
    let label: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))

                Text(label.uppercased())
                    .font(.spaceMono(11))
                    .tracking(1.0)
            }
            .foregroundColor(ENVITheme.text(for: colorScheme).opacity(0.7))
            .padding(.horizontal, ENVISpacing.md)
            .padding(.vertical, 6)
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

#Preview {
    VStack {
        Spacer()
        EnhancedChatInputBar(
            onSend: { _ in }
        )
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}
