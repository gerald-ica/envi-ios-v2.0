import SwiftUI

/// Small attribution footer showing "Powered by Perplexity".
/// Place at the bottom of chat responses or the chat container.
struct PerplexityAttributionView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: ENVISpacing.xs) {
            // Sparkle icon
            Image(systemName: "sparkle")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.white.opacity(0.30))

            // Attribution text
            Text("POWERED BY PERPLEXITY")
                .font(.spaceMono(10))
                .tracking(2.0)
                .foregroundColor(.white.opacity(0.30))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, ENVISpacing.sm)
    }
}

// MARK: - Preview

#if DEBUG
struct PerplexityAttributionView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Spacer()
                PerplexityAttributionView()
            }
        }
        .preferredColorScheme(.dark)
    }
}
#endif
