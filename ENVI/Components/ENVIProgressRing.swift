import SwiftUI

/// Circular progress indicator for the ENVI design system.
struct ENVIProgressRing: View {
    let progress: Double     // 0.0–1.0
    var lineWidth: CGFloat = 6
    var size: CGFloat = 60

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(
                    ENVITheme.surfaceHigh(for: colorScheme),
                    lineWidth: lineWidth
                )

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ENVITheme.primary(for: colorScheme),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)

            // Center label
            Text("\(Int(progress * 100))%")
                .font(.spaceMonoBold(size * 0.22))
                .foregroundColor(ENVITheme.text(for: colorScheme))
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 24) {
        ENVIProgressRing(progress: 0.25, size: 50)
        ENVIProgressRing(progress: 0.65, size: 70)
        ENVIProgressRing(progress: 0.92, size: 90)
    }
    .preferredColorScheme(.dark)
}
