import SwiftUI

// MARK: - Suggestion Pill View

/// Floating pill at the bottom of the explorer that pulses and shows an AI suggestion
/// about the user's content timeline. Tap to expand into a suggestion card; dismiss via close button.
struct SuggestionPillView: View {

    var onTap: () -> Void
    var onDismiss: () -> Void

    @State private var isExpanded: Bool = false
    @State private var isPulsing: Bool = false

    var body: some View {
        VStack(spacing: ENVISpacing.md) {
            if isExpanded {
                expandedCard
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.92).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
            } else {
                pillButton
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isExpanded)
    }

    // MARK: - Collapsed Pill

    private var pillButton: some View {
        Button {
            withAnimation {
                isExpanded = true
            }
        } label: {
            HStack(spacing: ENVISpacing.sm) {
                // Sparkle icon
                Text("✦")
                    .font(.system(size: 14))
                    .foregroundColor(.white) // Flat white

                Text("AI HAS A SUGGESTION")
                    .font(.spaceMonoBold(11))
                    .tracking(2.0)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, ENVISpacing.xl)
            .padding(.vertical, ENVISpacing.sm) // Tighter
            .background(
                Capsule()
                    .fill(Color(hex: "#1A1A1A")) // Flat dark
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        Color.white.opacity(isPulsing ? 0.4 : 0.1),
                        lineWidth: 1
                    )
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isPulsing
                    )
            )
            .shadow(color: Color.black.opacity(0.3), radius: 10, y: 4)
        }
        .onAppear {
            isPulsing = true
        }
    }

    // MARK: - Expanded Card

    private var expandedCard: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Header row
            HStack {
                HStack(spacing: ENVISpacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 12))
                        .foregroundColor(ENVITheme.Dark.accent)
                    Text("AI SUGGESTION")
                        .font(.spaceMonoBold(10))
                        .tracking(2.5)
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Button(action: {
                    withAnimation {
                        isExpanded = false
                    }
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.white.opacity(0.05)))
                        .overlay(
                            Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                }
            }

            // Suggestion text — about the user's content timeline
            Text("Your top-performing content this week is video format. Consider converting your \"Product Flat Lay\" photo into a 15-second showcase reel — similar transitions have seen 2.4x more reach.")
                .font(.interRegular(13))
                .foregroundColor(.white.opacity(0.6))
                .lineSpacing(4)

            // Action button
            Button(action: onTap) {
                Text("VIEW SUGGESTIONS")
                    .font(.spaceMonoBold(11))
                    .tracking(2.0)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ENVISpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: ENVIRadius.lg)
                            .fill(ENVITheme.Dark.accent)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.lg)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
        }
        .padding(ENVISpacing.xl)
        .frame(maxWidth: 340)
        .background(
            RoundedRectangle(cornerRadius: ENVIRadius.xl)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.xl)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 24, y: 8)
    }
}

#if DEBUG
struct SuggestionPillView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Spacer()
                SuggestionPillView(onTap: {}, onDismiss: {})
                    .padding()
            }
        }
        .preferredColorScheme(.dark)
    }
}
#endif
