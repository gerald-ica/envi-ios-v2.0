import SwiftUI

/// Frosted glass progress overlay shown during export.
struct ProgressOverlayView: View {
    @State private var progress: Double = 0
    @State private var currentStage = 0
    var onDismiss: (() -> Void)?

    let stages = ["Analyzing", "Editing", "Rendering", "Done"]

    var body: some View {
        ZStack {
            // Frosted background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: ENVISpacing.xxl) {
                // Progress ring
                ENVIProgressRing(progress: progress, lineWidth: 8, size: 120)

                // Stage text
                Text(stages[min(currentStage, stages.count - 1)].uppercased())
                    .font(.spaceMonoBold(17))
                    .tracking(-0.5)
                    .foregroundColor(.white)

                // Stage pipeline
                HStack(spacing: ENVISpacing.md) {
                    ForEach(0..<stages.count, id: \.self) { index in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(index <= currentStage ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)

                            if index < stages.count - 1 {
                                Rectangle()
                                    .fill(index < currentStage ? Color.white : Color.white.opacity(0.3))
                                    .frame(width: 24, height: 2)
                            }
                        }
                    }
                }

                // Dismiss
                if currentStage >= stages.count - 1 {
                    ENVIButton("Done", variant: .primary, isFullWidth: false) {
                        onDismiss?()
                    }
                }
            }
        }
        .onAppear { startProgress() }
    }

    private func startProgress() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if progress >= 1.0 {
                timer.invalidate()
                currentStage = stages.count - 1
                return
            }
            progress += 0.01
            currentStage = Int(progress * Double(stages.count - 1))
        }
    }
}

#Preview {
    ProgressOverlayView()
}
