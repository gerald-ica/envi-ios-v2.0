import SwiftUI

/// Voice input UI stub — no actual speech recognition, just the interface.
/// Presented as a sheet/modal when the user taps the Voice chip.
struct VoiceInputView: View {
    var onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            // Glass-morphic card
            VStack(spacing: ENVISpacing.xxl) {
                Spacer()

                // Pulsing microphone icon
                ZStack {
                    // Pulse ring
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isPulsing ? 1.25 : 0.9)
                        .opacity(isPulsing ? 0.0 : 0.5)

                    // Mic icon
                    Image(systemName: "mic.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.white)
                        .scaleEffect(isPulsing ? 1.08 : 0.95)
                }
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: isPulsing
                )

                // Labels
                VStack(spacing: ENVISpacing.sm) {
                    Text("LISTENING...")
                        .font(.spaceMonoBold(15))
                        .tracking(2.5)
                        .foregroundColor(.white)

                    Text("TAP TO STOP")
                        .font(.spaceMono(11))
                        .tracking(1.5)
                        .foregroundColor(.white.opacity(0.45))
                }

                Spacer()

                // Cancel button
                Button {
                    HapticManager.shared.lightImpact()
                    onCancel()
                } label: {
                    Text("CANCEL")
                        .font(.spaceMonoBold(11))
                        .tracking(2.5)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, ENVISpacing.xxl)
                        .padding(.vertical, ENVISpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .padding(.bottom, ENVISpacing.xxxxl)
            }
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial.opacity(0.5))
        }
        .onAppear { isPulsing = true }
    }
}

// MARK: - Preview

#if DEBUG
struct VoiceInputView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceInputView(onCancel: {})
            .preferredColorScheme(.dark)
    }
}
#endif
