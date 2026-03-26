import SwiftUI

/// Compact bottom-right voice input pill matching the React WorldExplorer.tsx voice widget.
/// Shows an ENVI AI orb with glow, waveform bars, "ENVI listening…" text, a timer, and end button.
/// NOT a full-screen modal — positioned as a floating pill in the bottom-right corner.
struct VoiceInputView: View {
    var onCancel: () -> Void

    @State private var isAnimating = false
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Transparent full-screen tap target to dismiss
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { closeVoice() }
                .ignoresSafeArea()

            // Voice pill positioned bottom-right
            ZStack {
                // Local glow behind pill
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.24, green: 0.39, blue: 0.78).opacity(0.35),
                                Color(hex: "#30217C").opacity(0.2),
                                Color.clear,
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 15)
                    .opacity(isAnimating ? 0.8 : 0.4)
                    .animation(
                        .easeInOut(duration: 4.0).repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                // Pill
                HStack(spacing: 12) {
                    // ENVI AI Orb
                    orbView

                    // Info column: waveform, label, timer
                    VStack(alignment: .leading, spacing: 1) {
                        waveformBars
                            .padding(.bottom, 2)

                        Text("ENVI listening…")
                            .font(.interMedium(12))
                            .foregroundColor(.white)
                            .tracking(-0.12) // -0.01em

                        Text(timerLabel)
                            .font(.spaceMono(10))
                            .foregroundColor(.white.opacity(0.4))
                            .monospacedDigit()
                    }

                    // End button (red circle with X)
                    Button(action: { closeVoice() }) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.86, green: 0.2, blue: 0.2).opacity(0.8))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                )

                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 4)
                }
                .padding(.leading, 10)
                .padding(.trailing, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color(red: 0.098, green: 0.047, blue: 0.196).opacity(0.8))
                )
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .opacity(0.5)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 24)
            .transition(.scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity))
        }
        .onAppear {
            isAnimating = true
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    // MARK: - ENVI AI Orb (4×4 dot grid inside radial gradient sphere)

    private var orbView: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.31, green: 0.55, blue: 1.0).opacity(0.5),
                            Color(red: 0.2, green: 0.39, blue: 0.86).opacity(0.3),
                            Color.clear,
                        ],
                        center: UnitPoint(x: 0.4, y: 0.4),
                        startRadius: 0,
                        endRadius: 31
                    )
                )
                .frame(width: 62, height: 62)
                .scaleEffect(isAnimating ? 1.05 : 0.95)
                .animation(
                    .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                    value: isAnimating
                )

            // Inner glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.43, green: 0.71, blue: 1.0).opacity(0.7),
                            Color(red: 0.24, green: 0.47, blue: 0.94).opacity(0.5),
                            Color(red: 0.16, green: 0.35, blue: 0.82).opacity(0.3),
                            Color.clear,
                        ],
                        center: UnitPoint(x: 0.38, y: 0.38),
                        startRadius: 0,
                        endRadius: 24
                    )
                )
                .frame(width: 48, height: 48)
                .scaleEffect(isAnimating ? 0.95 : 1.05)
                .animation(
                    .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                    value: isAnimating
                )

            // 4×4 dot grid
            VStack(spacing: 2.5) {
                ForEach(0..<4, id: \.self) { _ in
                    HStack(spacing: 2.5) {
                        ForEach(0..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.white.opacity(0.88))
                                .frame(width: 3.5, height: 3.5)
                        }
                    }
                }
            }
        }
        .frame(width: 42, height: 42)
    }

    // MARK: - Waveform Bars (5 bars with staggered animation)

    private var waveformBars: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array([5, 10, 14, 8, 5].enumerated()), id: \.offset) { index, height in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white.opacity(0.75))
                    .frame(width: 2.5, height: isAnimating ? CGFloat(height) : CGFloat(height) * 0.4)
                    .animation(
                        .easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.12),
                        value: isAnimating
                    )
            }
        }
        .frame(height: 14)
    }

    // MARK: - Timer

    private var timerLabel: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startTimer() {
        elapsedSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func closeVoice() {
        HapticManager.shared.lightImpact()
        stopTimer()
        onCancel()
    }
}

// MARK: - Preview

#if DEBUG
struct VoiceInputView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VoiceInputView(onCancel: {})
        }
        .preferredColorScheme(.dark)
    }
}
#endif
