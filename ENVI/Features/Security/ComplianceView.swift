import SwiftUI

/// Compliance checklist with regulation badges (GDPR, CCPA, SOC2) and status indicators.
struct ComplianceView: View {
    @ObservedObject var viewModel: SecurityViewModel
    @Environment(\.colorScheme) private var colorScheme

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                statusFilterBar
                complianceList
                policiesSection
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .refreshable {
            async let c: () = viewModel.loadCompliance()
            async let p: () = viewModel.loadPolicies()
            _ = await (c, p)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text("COMPLIANCE")
                .font(.spaceMonoBold(17))
                .tracking(-0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("\(viewModel.filteredCompliance.count) regulations tracked")
                .font(.spaceMono(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Status Filter

    private var statusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ENVISpacing.sm) {
                ENVIFilterChip(title: "All", isSelected: viewModel.complianceStatusFilter == nil) {
                    viewModel.complianceStatusFilter = nil
                }
                ForEach(ComplianceStatus.allCases) { status in
                    ENVIFilterChip(title: status.displayName, isSelected: viewModel.complianceStatusFilter == status) {
                        viewModel.complianceStatusFilter = status
                    }
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    // MARK: - Compliance List

    private var complianceList: some View {
        LazyVStack(spacing: ENVISpacing.sm) {
            if viewModel.isLoadingCompliance {
                ENVILoadingState()
            } else if viewModel.filteredCompliance.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.filteredCompliance) { check in
                    complianceCard(check)
                }
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private var emptyState: some View {
        ENVIEmptyState(
            icon: "shield.slash",
            title: "No compliance checks found"
        )
    }

    private func complianceCard(_ check: ComplianceCheck) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Top row: regulation badge + status
            HStack {
                regulationBadge(check.regulation)

                Spacer()

                statusBadge(check.status)
            }

            // Last audit date
            HStack(spacing: ENVISpacing.xs) {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                Text("Last audit: \(dateFormatter.string(from: check.lastAuditDate))")
                    .font(.spaceMono(10))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            // Findings
            if !check.findings.isEmpty {
                VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                    ForEach(check.findings, id: \.self) { finding in
                        HStack(alignment: .top, spacing: ENVISpacing.sm) {
                            Image(systemName: findingIcon(for: check.status))
                                .font(.system(size: 9))
                                .foregroundColor(statusColor(for: check.status))
                                .padding(.top, 2)

                            Text(finding)
                                .font(.interRegular(11))
                                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
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

    // MARK: - Badges

    private func regulationBadge(_ regulation: Regulation) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(regulation.displayName)
                .font(.spaceMonoBold(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text(regulation.description)
                .font(.interRegular(10))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .lineLimit(1)
        }
    }

    private func statusBadge(_ status: ComplianceStatus) -> some View {
        ENVIStatusBadge(text: status.displayName, color: statusColor(for: status))
    }

    private func statusColor(for status: ComplianceStatus) -> Color {
        switch status {
        case .passed:   return ENVITheme.success
        case .failed:   return ENVITheme.error
        case .pending:  return ENVITheme.warning
        case .inReview: return ENVITheme.info
        }
    }

    private func findingIcon(for status: ComplianceStatus) -> String {
        switch status {
        case .passed:   return "checkmark.circle.fill"
        case .failed:   return "exclamationmark.triangle.fill"
        case .pending:  return "clock.fill"
        case .inReview: return "magnifyingglass"
        }
    }

    // MARK: - Security Policies Section

    private var policiesSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("SECURITY POLICIES")
                .font(.spaceMonoBold(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .padding(.horizontal, ENVISpacing.xl)

            if viewModel.isLoadingPolicies {
                ENVILoadingState(minHeight: 80)
            } else {
                VStack(spacing: ENVISpacing.sm) {
                    ForEach(viewModel.policies) { policy in
                        policyCard(policy)
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }
        }
    }

    private func policyCard(_ policy: SecurityPolicy) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text(policy.name)
                    .font(.spaceMonoBold(12))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                Text("Enforced \(dateFormatter.string(from: policy.enforcedAt))")
                    .font(.spaceMono(9))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            ForEach(policy.rules, id: \.self) { rule in
                HStack(alignment: .top, spacing: ENVISpacing.sm) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(ENVITheme.success)
                        .padding(.top, 3)

                    Text(rule)
                        .font(.interRegular(11))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
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

// MARK: - Preview

#Preview {
    ComplianceView(viewModel: SecurityViewModel())
}
