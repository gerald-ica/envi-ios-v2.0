import SwiftUI

/// A badge grid showing earned and locked achievement states.
struct AchievementsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var badges: [AchievementBadge] = AchievementBadge.mock
    @State private var selectedBadge: AchievementBadge?

    private let columns = [
        GridItem(.flexible(), spacing: ENVISpacing.md),
        GridItem(.flexible(), spacing: ENVISpacing.md),
        GridItem(.flexible(), spacing: ENVISpacing.md),
    ]

    private var earnedCount: Int { badges.filter { $0.isEarned }.count }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: ENVISpacing.lg) {
                header
                statsBar
                badgeGrid
            }
            .padding(ENVISpacing.lg)
        }
        .background(ENVITheme.background(for: colorScheme).ignoresSafeArea())
        .overlay {
            if let badge = selectedBadge {
                badgeDetail(badge)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("ACHIEVEMENTS")
                .font(.spaceMono(22))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Earn badges by completing milestones")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: ENVISpacing.lg) {
            statItem(value: "\(earnedCount)", label: "EARNED")
            statItem(value: "\(badges.count - earnedCount)", label: "LOCKED")
            statItem(value: "\(Int(Double(earnedCount) / Double(max(badges.count, 1)) * 100))%", label: "COMPLETE")
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.spaceMono(18))
                .tracking(-0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text(label)
                .font(.spaceMono(9))
                .tracking(1.5)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Badge Grid

    private var badgeGrid: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("ALL BADGES")
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            LazyVGrid(columns: columns, spacing: ENVISpacing.md) {
                ForEach(badges) { badge in
                    badgeCell(badge)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedBadge = badge
                            }
                        }
                }
            }
        }
    }

    private func badgeCell(_ badge: AchievementBadge) -> some View {
        VStack(spacing: ENVISpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .fill(badge.isEarned
                        ? ENVITheme.surfaceHigh(for: colorScheme)
                        : ENVITheme.surfaceLow(for: colorScheme)
                    )
                    .frame(height: 80)

                Image(systemName: badge.iconName)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(
                        badge.isEarned
                            ? ENVITheme.text(for: colorScheme)
                            : ENVITheme.textSecondary(for: colorScheme).opacity(0.3)
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if badge.isEarned {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ENVITheme.success)
                        .offset(x: 4, y: -4)
                }
            }

            Text(badge.name.uppercased())
                .font(.spaceMono(9))
                .tracking(1)
                .foregroundColor(
                    badge.isEarned
                        ? ENVITheme.text(for: colorScheme)
                        : ENVITheme.textSecondary(for: colorScheme)
                )
                .lineLimit(1)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Badge Detail Overlay

    private func badgeDetail(_ badge: AchievementBadge) -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { selectedBadge = nil }
                }

            VStack(spacing: ENVISpacing.lg) {
                Image(systemName: badge.iconName)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundColor(
                        badge.isEarned
                            ? ENVITheme.text(for: colorScheme)
                            : ENVITheme.textSecondary(for: colorScheme).opacity(0.4)
                    )

                VStack(spacing: ENVISpacing.xs) {
                    Text(badge.name.uppercased())
                        .font(.spaceMono(15))
                        .tracking(1)
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text(badge.description)
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        .multilineTextAlignment(.center)
                }

                if let earned = badge.earnedAt {
                    Text("EARNED \(earned.formatted(.dateTime.month().day().year()))")
                        .font(.spaceMono(10))
                        .tracking(1.5)
                        .foregroundColor(ENVITheme.success)
                } else {
                    Text("LOCKED")
                        .font(.spaceMono(10))
                        .tracking(1.5)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }
            .padding(ENVISpacing.xxl)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.xl)
                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
            )
            .padding(.horizontal, ENVISpacing.xxxl)
        }
    }
}

#Preview {
    AchievementsView()
        .preferredColorScheme(.dark)
}
