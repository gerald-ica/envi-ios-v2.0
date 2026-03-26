import SwiftUI

/// Text input field with label and optional validation.
/// Label: Space Mono, UPPERCASE. Input text: Inter Regular, sentence case.
/// Focus border: white (dark) / black (light) — not purple.
struct ENVIInput: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var errorMessage: String? = nil
    var isSecure: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            // Label — Space Mono, UPPERCASE
            Text(label.uppercased())
                .font(.spaceMonoBold(11))
                .tracking(2.5)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            // Field — Inter Regular, sentence case
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.interRegular(15))
            .foregroundColor(ENVITheme.text(for: colorScheme))
            .padding(.horizontal, ENVISpacing.lg)
            .padding(.vertical, ENVISpacing.md)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.md)
                    .strokeBorder(borderColor, lineWidth: 1.5)
            )
            .focused($isFocused)

            // Error
            if let errorMessage {
                Text(errorMessage)
                    .font(.interMedium(12))
                    .foregroundColor(ENVITheme.error)
            }
        }
    }

    private var borderColor: Color {
        if errorMessage != nil {
            return ENVITheme.error
        }
        return isFocused
            ? ENVITheme.text(for: colorScheme)
            : ENVITheme.border(for: colorScheme)
    }
}

#Preview {
    VStack(spacing: 16) {
        ENVIInput(label: "Email", placeholder: "you@email.com", text: .constant(""))
        ENVIInput(label: "Password", placeholder: "••••••••", text: .constant(""), isSecure: true)
        ENVIInput(label: "Name", placeholder: "Enter name", text: .constant(""), errorMessage: "Name is required")
    }
    .padding()
    .preferredColorScheme(.dark)
}
