import SwiftUI

/// Feature flag management with toggles and rollout targeting (ENVI-0936..0940).
struct FeatureFlagView: View {

    @State private var flags: [FeatureFlag] = []
    @State private var isLoading = true
    @Environment(\.colorScheme) private var colorScheme

    private let repository = AdminRepositoryProvider.shared.repository

    var body: some View {
        ScrollView {
            VStack(spacing: ENVISpacing.xxl) {
                header
                if isLoading {
                    ENVILoadingState()
                } else {
                    flagList
                }
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .task { await loadFlags() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: ENVISpacing.sm) {
            Text("FEATURE FLAGS")
                .font(.spaceMonoBold(22))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("\(flags.filter(\.isEnabled).count) of \(flags.count) enabled")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Flag List

    private var flagList: some View {
        VStack(spacing: ENVISpacing.md) {
            ForEach(Array(flags.enumerated()), id: \.element.id) { index, flag in
                flagRow(flag, index: index)
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func flagRow(_ flag: FeatureFlag, index: Int) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(flag.name)
                        .font(.spaceMonoBold(14))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text(flag.description)
                        .font(.interRegular(12))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { flag.isEnabled },
                    set: { newValue in
                        Task { await toggleFlag(index: index, isEnabled: newValue) }
                    }
                ))
                .labelsHidden()
                .tint(.green)
            }

            // Targeting bar
            HStack(spacing: ENVISpacing.sm) {
                Image(systemName: "person.2")
                    .font(.system(size: 11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Text("Targeting: \(Int(flag.targetPercentage))%")
                    .font(.interRegular(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ENVITheme.surfaceLow(for: colorScheme))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(flag.isEnabled ? Color.green : ENVITheme.textSecondary(for: colorScheme))
                            .frame(width: geo.size.width * flag.targetPercentage / 100, height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
    }

    // MARK: - Actions

    private func loadFlags() async {
        defer { isLoading = false }
        flags = (try? await repository.fetchFeatureFlags()) ?? []
    }

    private func toggleFlag(index: Int, isEnabled: Bool) async {
        guard index < flags.count else { return }
        let flag = flags[index]
        if let updated = try? await repository.toggleFlag(id: flag.id, isEnabled: isEnabled) {
            flags[index] = updated
        }
    }
}

#Preview {
    FeatureFlagView()
}
