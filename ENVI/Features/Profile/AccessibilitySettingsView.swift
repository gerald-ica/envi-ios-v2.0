import SwiftUI

/// User-facing accessibility preferences: text scale, motion, contrast, VoiceOver hints (ENVI-0752..0753).
struct AccessibilitySettingsView: View {

    @Environment(\.colorScheme) private var colorScheme
    @State private var settings: AccessibilitySettings = .default
    @State private var selectedHaptic: HapticFeedback = .medium

    var body: some View {
        ScrollView {
            VStack(spacing: ENVISpacing.xxl) {
                header
                textScaleSection
                motionSection
                contrastSection
                voiceOverSection
                hapticSection
                resetButton
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: ENVISpacing.sm) {
            Text("ACCESSIBILITY")
                .font(.spaceMonoBold(22))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Customize display and interaction preferences")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Text Scale

    private var textScaleSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("TEXT SCALE")

            VStack(spacing: ENVISpacing.md) {
                HStack {
                    Text("Aa")
                        .font(.interRegular(12))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    Slider(value: $settings.textScale, in: 0.8...1.6, step: 0.1)
                        .tint(ENVITheme.text(for: colorScheme))

                    Text("Aa")
                        .font(.interRegular(20))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                Text("Preview text at \(Int(settings.textScale * 100))% scale")
                    .font(.interRegular(14 * settings.textScale))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.easeInOut(duration: 0.2), value: settings.textScale)
            }
            .padding(ENVISpacing.lg)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Reduce Motion

    private var motionSection: some View {
        toggleRow(
            icon: "figure.walk",
            title: "Reduce Motion",
            subtitle: "Minimise animations and parallax effects",
            isOn: $settings.reduceMotion
        )
    }

    // MARK: - High Contrast

    private var contrastSection: some View {
        toggleRow(
            icon: "circle.lefthalf.filled",
            title: "High Contrast",
            subtitle: "Increase contrast between text and backgrounds",
            isOn: $settings.highContrast
        )
    }

    // MARK: - VoiceOver

    private var voiceOverSection: some View {
        toggleRow(
            icon: "speaker.wave.3.fill",
            title: "VoiceOver Hints",
            subtitle: "Provide additional context for screen reader users",
            isOn: $settings.voiceOverHints
        )
    }

    // MARK: - Haptic Feedback

    private var hapticSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("HAPTIC FEEDBACK")

            VStack(spacing: 0) {
                ForEach(HapticFeedback.allCases) { haptic in
                    Button {
                        selectedHaptic = haptic
                        haptic.fire()
                    } label: {
                        HStack {
                            Text(haptic.displayName)
                                .font(.interRegular(14))
                                .foregroundColor(ENVITheme.text(for: colorScheme))

                            Spacer()

                            if selectedHaptic == haptic {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(ENVITheme.text(for: colorScheme))
                            }
                        }
                        .padding(.vertical, ENVISpacing.md)
                        .padding(.horizontal, ENVISpacing.lg)
                    }

                    if haptic != HapticFeedback.allCases.last {
                        Divider()
                            .overlay(ENVITheme.border(for: colorScheme))
                            .padding(.leading, ENVISpacing.lg)
                    }
                }
            }
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Reset

    private var resetButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                settings = .default
                selectedHaptic = .medium
            }
        } label: {
            Text("RESET TO DEFAULTS")
                .font(.spaceMono(13))
                .foregroundColor(ENVITheme.error)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ENVISpacing.md)
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.lg)
                        .stroke(ENVITheme.error.opacity(0.3), lineWidth: 1)
                )
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Reusable Toggle Row

    private func toggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: ENVISpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.interSemiBold(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text(subtitle)
                    .font(.interRegular(12))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(ENVITheme.success)
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.spaceMono(11))
            .tracking(1)
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            .padding(.horizontal, ENVISpacing.xl)
    }
}
