import SwiftUI

/// Customer health gauge showing overall score, contributing factors, and recommendation.
struct HealthScoreView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var healthScore: HealthScore = .mock
    @State private var animatedProgress: Double = 0

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                gaugeCard
                factorsSection
                recommendationCard
                lifecycleSection
            }
            .padding(ENVISpacing.lg)
        }
        .background(ENVITheme.background(for: colorScheme).ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animatedProgress = Double(healthScore.score) / 100.0
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("HEALTH SCORE")
                .font(.spaceMono(22))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Your account health overview")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
    }

    // MARK: - Gauge Card

    private var gaugeCard: some View {
        VStack(spacing: ENVISpacing.lg) {
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(ENVITheme.surfaceHigh(for: colorScheme), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(135))

                // Progress arc
                Circle()
                    .trim(from: 0, to: animatedProgress * 0.75)
                    .stroke(tierColor(healthScore.tier), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(135))

                // Score text
                VStack(spacing: 2) {
                    Text("\(healthScore.score)")
                        .font(.spaceMonoBold(42))
                        .tracking(-2)
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text(healthScore.tier.displayName.uppercased())
                        .font(.spaceMono(11))
                        .tracking(1.5)
                        .foregroundColor(tierColor(healthScore.tier))
                }
            }
            .frame(width: 180, height: 180)

            // Tier indicator
            HStack(spacing: ENVISpacing.sm) {
                Image(systemName: healthScore.tier.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(tierColor(healthScore.tier))

                Text(tierDescription(healthScore.tier))
                    .font(.interRegular(12))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(ENVISpacing.xl)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Factors Section

    private var factorsSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("FACTORS")
                .font(.spaceMono(13))
                .tracking(1)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            ForEach(healthScore.factors) { factor in
                factorRow(factor)
            }
        }
    }

    private func factorRow(_ factor: HealthScoreFactor) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack {
                Text(factor.name)
                    .font(.spaceMonoBold(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                Text("\(Int(factor.value * 100))%")
                    .font(.spaceMono(13))
                    .foregroundColor(factorValueColor(factor.value))
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ENVITheme.surfaceHigh(for: colorScheme))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(factorValueColor(factor.value))
                        .frame(width: geo.size.width * factor.value, height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text("Weight: \(Int(factor.weight * 100))%")
                    .font(.spaceMono(10))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Spacer()
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Recommendation Card

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack(spacing: ENVISpacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ENVITheme.warning)

                Text("RECOMMENDATION")
                    .font(.spaceMono(11))
                    .tracking(1)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Text(healthScore.recommendation)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Lifecycle Section

    private var lifecycleSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("LIFECYCLE STAGES")
                .font(.spaceMono(13))
                .tracking(1)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            HStack(spacing: ENVISpacing.sm) {
                ForEach(LifecycleStage.allCases) { stage in
                    VStack(spacing: ENVISpacing.xs) {
                        ZStack {
                            Circle()
                                .fill(stage == .active
                                    ? tierColor(.healthy).opacity(0.2)
                                    : ENVITheme.surfaceHigh(for: colorScheme))
                                .frame(width: 40, height: 40)

                            Image(systemName: stage.iconName)
                                .font(.system(size: 16))
                                .foregroundColor(stage == .active
                                    ? tierColor(.healthy)
                                    : ENVITheme.textSecondary(for: colorScheme))
                        }

                        Text(stage.displayName)
                            .font(.spaceMono(9))
                            .foregroundColor(stage == .active
                                ? ENVITheme.text(for: colorScheme)
                                : ENVITheme.textSecondary(for: colorScheme))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(ENVISpacing.md)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
            )
        }
    }

    // MARK: - Helpers

    private func tierColor(_ tier: HealthTier) -> Color {
        switch tier {
        case .healthy:  return ENVITheme.success
        case .neutral:  return ENVITheme.warning
        case .atRisk:   return ENVITheme.error
        case .critical: return ENVITheme.error
        }
    }

    private func tierDescription(_ tier: HealthTier) -> String {
        switch tier {
        case .healthy:  return "Your account is in great shape"
        case .neutral:  return "Room for improvement"
        case .atRisk:   return "Attention needed"
        case .critical: return "Immediate action required"
        }
    }

    private func factorValueColor(_ value: Double) -> Color {
        switch value {
        case 0.8...1.0: return ENVITheme.success
        case 0.6..<0.8: return ENVITheme.warning
        default:        return ENVITheme.error
        }
    }
}

#Preview {
    HealthScoreView()
        .preferredColorScheme(.dark)
}
