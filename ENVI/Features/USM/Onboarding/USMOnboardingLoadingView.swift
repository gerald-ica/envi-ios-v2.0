import SwiftUI

/// Animated loading state shown after USM onboarding submission while the
/// server-side recompute fan-out is running. Cycles through voice-translated
/// copy (no banned methodology terms — see Sprint 3 banned_terms.yml).
///
/// The card rotation is purely cosmetic: server-side processing may complete
/// in 30–60s; cards cycle on a 3-second interval regardless.
struct USMOnboardingLoadingView: View {
    @Environment(\.colorScheme) private var colorScheme

    private static let cards: [LoadingCard] = [
        LoadingCard(title: "Reading your week", subtitle: "Turning light into story"),
        LoadingCard(title: "Mapping the week ahead", subtitle: "Listening to the currents"),
        LoadingCard(title: "Gathering your weather", subtitle: "Watching the shape of your days"),
        LoadingCard(title: "Finding your rhythm", subtitle: "Tracing how you move"),
        LoadingCard(title: "Setting the tone", subtitle: "Tuning to how you feel"),
        LoadingCard(title: "Writing your first page", subtitle: "Catching the thread you're pulling")
    ]

    @State private var index: Int = 0
    @State private var task: Task<Void, Never>?

    private struct LoadingCard: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let subtitle: String
    }

    var body: some View {
        VStack(spacing: ENVISpacing.xl) {
            Spacer()

            // Pulsing circle
            ZStack {
                Circle()
                    .stroke(ENVITheme.primary(for: colorScheme), lineWidth: 2)
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)

                Circle()
                    .fill(ENVITheme.primary(for: colorScheme).opacity(0.1))
                    .frame(width: 80, height: 80)
            }

            // Card that fades between entries
            VStack(spacing: ENVISpacing.sm) {
                Text(Self.cards[index].title)
                    .font(.spaceMonoBold(24))
                    .tracking(-1.0)
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .multilineTextAlignment(.center)

                Text(Self.cards[index].subtitle)
                    .font(.interRegular(15))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
            }
            .id(index)  // forces re-render on change
            .transition(.opacity)

            Spacer()
        }
        .padding(.horizontal, ENVISpacing.xl)
        .background(ENVITheme.background(for: colorScheme))
        .onAppear {
            startCycling()
        }
        .onDisappear {
            task?.cancel()
        }
    }

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 1.0

    private func startCycling() {
        // Start pulse animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.3
            pulseOpacity = 0
        }

        // Start card cycling
        task = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                if Task.isCancelled { break }
                withAnimation(.easeInOut(duration: 0.6)) {
                    index = (index + 1) % Self.cards.count
                }
            }
        }
    }
}

#Preview {
    USMOnboardingLoadingView()
        .preferredColorScheme(.light)
}

#Preview {
    USMOnboardingLoadingView()
        .preferredColorScheme(.dark)
}
