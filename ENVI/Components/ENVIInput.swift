import SwiftUI

/// Text input field with label and optional validation for the ENVI design system.
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
            // Label
            Text(label.uppercased())
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            // Field
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
            ? ENVITheme.primary(for: colorScheme)
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
