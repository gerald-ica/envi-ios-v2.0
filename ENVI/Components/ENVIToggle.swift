import SwiftUI

/// Custom toggle switch for the ENVI design system.
/// On state: white track + black thumb (dark mode). No purple.
struct ENVIToggle: View {
    @Binding var isOn: Bool
    var label: String? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            if let label {
                Text(label)
                    .font(.interRegular(15))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                Spacer()
            }

            Button(action: { withAnimation(.spring(response: 0.3)) { isOn.toggle() } }) {
                ZStack(alignment: isOn ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(isOn
                            ? (colorScheme == .dark ? Color.white : Color.black)
                            : ENVITheme.surfaceHigh(for: colorScheme)
                        )
                        .frame(width: 50, height: 30)

                    Circle()
                        .fill(isOn
                            ? (colorScheme == .dark ? Color.black : Color.white)
                            : Color.white
                        )
                        .frame(width: 26, height: 26)
                        .padding(2)
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ENVIToggle(isOn: .constant(true), label: "Instagram")
        ENVIToggle(isOn: .constant(false), label: "TikTok")
    }
    .padding()
    .preferredColorScheme(.dark)
}
