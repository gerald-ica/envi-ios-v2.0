import SwiftUI

/// Animated typing indicator with three staggered bouncing dots.
struct TypingDotsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var animating = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(ENVITheme.text(for: colorScheme).opacity(0.4))
                    .frame(width: 6, height: 6)
                    .offset(y: animating ? -6 : 0)
                    .animation(
                        .easeInOut(duration: 0.45)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .padding(.vertical, ENVISpacing.xxl)
        .padding(.horizontal, ENVISpacing.xs)
        .onAppear {
            animating = true
        }
    }
}

#Preview {
    TypingDotsView()
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
}
