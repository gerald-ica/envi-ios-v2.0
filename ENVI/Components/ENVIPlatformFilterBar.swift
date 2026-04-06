import SwiftUI

/// Horizontal scrolling platform filter bar used across Calendar, BestTime, and other views.
/// Shows an "ALL" chip followed by one chip per `SocialPlatform`, each with a brand-color dot.
struct ENVIPlatformFilterBar: View {
    @Binding var selectedPlatform: SocialPlatform?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ENVISpacing.sm) {
                allChip
                ForEach(SocialPlatform.allCases) { platform in
                    platformChip(platform)
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    // MARK: - All Chip

    private var allChip: some View {
        Button {
            selectedPlatform = nil
        } label: {
            Text("ALL")
                .font(.spaceMonoBold(9))
                .tracking(1.0)
                .foregroundColor(chipForeground(isSelected: selectedPlatform == nil))
                .padding(.horizontal, ENVISpacing.md)
                .padding(.vertical, 4)
                .background(chipBackground(isSelected: selectedPlatform == nil))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.sm)
                        .strokeBorder(chipBorder(isSelected: selectedPlatform == nil), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Platform Chip

    private func platformChip(_ platform: SocialPlatform) -> some View {
        let isSelected = selectedPlatform == platform
        return Button {
            selectedPlatform = isSelected ? nil : platform
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(platform.brandColor)
                    .frame(width: 6, height: 6)
                Text(platform.rawValue.uppercased())
                    .font(.spaceMonoBold(9))
                    .tracking(1.0)
            }
            .foregroundColor(chipForeground(isSelected: isSelected))
            .padding(.horizontal, ENVISpacing.md)
            .padding(.vertical, 4)
            .background(chipBackground(isSelected: isSelected))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.sm)
                    .strokeBorder(chipBorder(isSelected: isSelected), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Styling

    private func chipForeground(isSelected: Bool) -> Color {
        if isSelected {
            return colorScheme == .dark ? .black : .white
        }
        return ENVITheme.textLight(for: colorScheme)
    }

    private func chipBackground(isSelected: Bool) -> Color {
        isSelected ? ENVITheme.text(for: colorScheme) : .clear
    }

    private func chipBorder(isSelected: Bool) -> Color {
        isSelected ? .clear : ENVITheme.border(for: colorScheme)
    }
}

#Preview {
    ENVIPlatformFilterBar(selectedPlatform: .constant(nil))
        .padding()
        .preferredColorScheme(.dark)
}
