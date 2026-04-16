import SwiftUI

/// Enterprise contract cards with renewal status, seat count, and value (ENVI-0981..0984).
struct ContractManagerView: View {

    @Environment(\.colorScheme) private var colorScheme
    @State private var contracts: [EnterpriseContract] = []
    @State private var certifications: [ComplianceCertification] = []
    @State private var isLoading = true

    private let repository: EnterpriseRepository = EnterpriseRepositoryProvider.shared.repository

    var body: some View {
        ScrollView {
            VStack(spacing: ENVISpacing.xxl) {
                header
                summaryRow
                contractList
                complianceSection
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .task { await loadData() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: ENVISpacing.sm) {
            Text("CONTRACTS")
                .font(.spaceMonoBold(22))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Manage client contracts and compliance")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Summary

    private var summaryRow: some View {
        HStack(spacing: ENVISpacing.md) {
            summaryPill(
                label: "TOTAL SEATS",
                value: "\(contracts.reduce(0) { $0 + $1.seats })",
                icon: "person.2.fill"
            )
            summaryPill(
                label: "ACTIVE",
                value: "\(contracts.filter { $0.renewalStatus == .active }.count)",
                icon: "checkmark.circle.fill"
            )
            summaryPill(
                label: "RENEWALS",
                value: "\(contracts.filter { $0.renewalStatus == .pendingRenewal }.count)",
                icon: "arrow.clockwise"
            )
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func summaryPill(label: String, value: String, icon: String) -> some View {
        VStack(spacing: ENVISpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            Text(value)
                .font(.spaceMonoBold(18))
                .foregroundColor(ENVITheme.text(for: colorScheme))
            Text(label)
                .font(.spaceMono(9))
                .tracking(0.5)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    // MARK: - Contract Cards

    private var contractList: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            sectionLabel("CLIENT CONTRACTS")

            ForEach(contracts) { contract in
                contractCard(contract)
            }
        }
    }

    private func contractCard(_ contract: EnterpriseContract) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(contract.clientName)
                        .font(.interSemiBold(16))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                    Text(contract.formattedValue)
                        .font(.spaceMonoBold(14))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }

                Spacer()

                renewalBadge(contract.renewalStatus)
            }

            HStack(spacing: ENVISpacing.lg) {
                detailLabel(icon: "person.2.fill", text: "\(contract.seats) seats")
                detailLabel(icon: "calendar", text: "\(contract.daysRemaining)d remaining")
            }

            // Progress bar
            GeometryReader { geo in
                let total = contract.endDate.timeIntervalSince(contract.startDate)
                let elapsed = Date().timeIntervalSince(contract.startDate)
                let progress = min(max(elapsed / total, 0), 1)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ENVITheme.surfaceHigh(for: colorScheme))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(contract.daysRemaining < 60
                              ? ENVITheme.warning
                              : ENVITheme.text(for: colorScheme))
                        .frame(width: geo.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func renewalBadge(_ status: RenewalStatus) -> some View {
        let color: Color = {
            switch status {
            case .active:           return ENVITheme.success
            case .pendingRenewal:   return ENVITheme.warning
            case .renewed:          return ENVITheme.info
            case .expired:          return ENVITheme.error
            case .cancelled:        return ENVITheme.error
            }
        }()

        return Text(status.displayName.uppercased())
            .font(.spaceMono(10))
            .tracking(0.5)
            .foregroundColor(color)
            .padding(.horizontal, ENVISpacing.sm)
            .padding(.vertical, ENVISpacing.xs)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    private func detailLabel(icon: String, text: String) -> some View {
        HStack(spacing: ENVISpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(text)
                .font(.interRegular(12))
        }
        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
    }

    // MARK: - Compliance

    private var complianceSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            sectionLabel("COMPLIANCE CERTIFICATIONS")

            ForEach(certifications) { cert in
                certificationRow(cert)
            }
        }
    }

    private func certificationRow(_ cert: ComplianceCertification) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(cert.standard)
                    .font(.interSemiBold(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("Expires \(cert.expiresAt, style: .date)")
                    .font(.interRegular(12))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()

            statusDot(cert.status)

            Text(cert.status.displayName.uppercased())
                .font(.spaceMono(10))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func statusDot(_ status: ComplianceStatus) -> some View {
        let color: Color = {
            switch status {
            case .valid:        return ENVITheme.success
            case .expiringSoon: return ENVITheme.warning
            case .expired:      return ENVITheme.error
            case .inProgress:   return ENVITheme.info
            }
        }()

        return Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .padding(.trailing, ENVISpacing.xs)
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.spaceMono(11))
            .tracking(1)
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            .padding(.horizontal, ENVISpacing.xl)
    }

    private func loadData() async {
        do {
            async let c = repository.fetchContracts()
            async let certs = repository.fetchCertifications()
            contracts = try await c
            certifications = try await certs
        } catch {}
        isLoading = false
    }
}
