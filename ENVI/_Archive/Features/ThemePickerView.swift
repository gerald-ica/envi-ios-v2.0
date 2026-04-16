import SwiftUI

/// Theme selector with live preview cards for built-in and custom themes (ENVI-0751).
struct ThemePickerView: View {

    @Environment(\.colorScheme) private var colorScheme
    @State private var themes: [AppTheme] = AppTheme.builtIn
    @State private var selectedThemeId: String = AppTheme.builtIn.first?.id ?? ""

    private var selectedTheme: AppTheme? {
        themes.first { $0.id == selectedThemeId }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ENVISpacing.xxl) {
                header
                previewCard
                themeGrid
                detailSection
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: ENVISpacing.sm) {
            Text("THEMES")
                .font(.spaceMonoBold(22))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Choose a visual theme for your app")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Live Preview

    private var previewCard: some View {
        VStack(spacing: 0) {
            if let theme = selectedTheme {
                // Simulated screen preview
                VStack(spacing: ENVISpacing.md) {
                    HStack {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 32, height: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(theme.primary.opacity(0.9))
                                .frame(width: 100, height: 10)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(theme.primary.opacity(0.4))
                                .frame(width: 70, height: 8)
                        }

                        Spacer()

                        RoundedRectangle(cornerRadius: ENVIRadius.sm)
                            .fill(theme.accent)
                            .frame(width: 50, height: 24)
                    }

                    // Content skeleton
                    ForEach(0..<3, id: \.self) { i in
                        HStack(spacing: ENVISpacing.sm) {
                            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                                .fill(theme.primary.opacity(0.08))
                                .frame(width: 48, height: 48)

                            VStack(alignment: .leading, spacing: 4) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(theme.primary.opacity(0.6))
                                    .frame(height: 10)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(theme.primary.opacity(0.25))
                                    .frame(width: CGFloat(120 - i * 20), height: 8)
                            }

                            Spacer()
                        }
                    }
                }
                .padding(ENVISpacing.lg)
                .background(theme.isDark ? Color.black : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.lg)
                        .stroke(ENVITheme.border(for: colorScheme), lineWidth: 1)
                )

                Text(theme.name.uppercased())
                    .font(.spaceMono(12))
                    .tracking(1)
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .padding(.top, ENVISpacing.md)
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
        .animation(.easeInOut(duration: 0.25), value: selectedThemeId)
    }

    // MARK: - Theme Grid

    private var themeGrid: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("SELECT THEME")
                .font(.spaceMono(11))
                .tracking(1)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .padding(.horizontal, ENVISpacing.xl)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ENVISpacing.md) {
                    ForEach(themes) { theme in
                        themeChip(theme)
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }
        }
    }

    private func themeChip(_ theme: AppTheme) -> some View {
        let isSelected = theme.id == selectedThemeId

        return Button {
            selectedThemeId = theme.id
            HapticFeedback.selection.fire()
        } label: {
            VStack(spacing: ENVISpacing.sm) {
                ZStack {
                    Circle()
                        .fill(theme.isDark ? Color.black : Color.white)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(theme.accent, lineWidth: 2)
                        )

                    Circle()
                        .fill(theme.accent)
                        .frame(width: 20, height: 20)
                }
                .overlay(
                    isSelected
                        ? Circle()
                            .stroke(ENVITheme.text(for: colorScheme), lineWidth: 3)
                            .frame(width: 54, height: 54)
                        : nil
                )

                Text(theme.name)
                    .font(.interMedium(12))
                    .foregroundColor(
                        isSelected
                            ? ENVITheme.text(for: colorScheme)
                            : ENVITheme.textSecondary(for: colorScheme)
                    )
            }
        }
    }

    // MARK: - Detail

    private var detailSection: some View {
        Group {
            if let theme = selectedTheme {
                VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                    Text("THEME DETAILS")
                        .font(.spaceMono(11))
                        .tracking(1)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        .padding(.horizontal, ENVISpacing.xl)

                    VStack(spacing: 0) {
                        detailRow(label: "Name", value: theme.name)
                        Divider().overlay(ENVITheme.border(for: colorScheme))
                        detailRow(label: "Primary", value: theme.primaryColor, color: theme.primary)
                        Divider().overlay(ENVITheme.border(for: colorScheme))
                        detailRow(label: "Accent", value: theme.accentColor, color: theme.accent)
                        Divider().overlay(ENVITheme.border(for: colorScheme))
                        detailRow(label: "Mode", value: theme.isDark ? "Dark" : "Light")
                    }
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
                    .padding(.horizontal, ENVISpacing.xl)
                }
            }
        }
    }

    private func detailRow(label: String, value: String, color: Color? = nil) -> some View {
        HStack {
            Text(label)
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Spacer()

            if let color {
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
            }

            Text(value)
                .font(.spaceMono(13))
                .foregroundColor(ENVITheme.text(for: colorScheme))
        }
        .padding(.vertical, ENVISpacing.md)
        .padding(.horizontal, ENVISpacing.lg)
    }
}
