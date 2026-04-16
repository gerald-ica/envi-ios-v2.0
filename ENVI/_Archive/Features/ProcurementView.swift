import SwiftUI

/// Procurement request list with approval workflow and new-request form (ENVI-0979..0980).
struct ProcurementView: View {

    @Environment(\.colorScheme) private var colorScheme
    @State private var requests: [ProcurementRequest] = []
    @State private var isLoading = true
    @State private var showNewRequest = false

    // New request form state
    @State private var newVendor = ""
    @State private var newAmount = ""
    @State private var newApprover = ""

    private let repository: EnterpriseRepository = EnterpriseRepositoryProvider.shared.repository

    var body: some View {
        ScrollView {
            VStack(spacing: ENVISpacing.xxl) {
                header
                statusFilter
                requestList
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .sheet(isPresented: $showNewRequest) { newRequestSheet }
        .task { await loadRequests() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("PROCUREMENT")
                    .font(.spaceMonoBold(22))
                    .tracking(-1)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("Vendor requests and approvals")
                    .font(.interRegular(14))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()

            Button { showNewRequest = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ENVITheme.background(for: colorScheme))
                    .frame(width: 32, height: 32)
                    .background(ENVITheme.text(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Status Filter

    private var statusFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ENVISpacing.sm) {
                ForEach(ProcurementStatus.allCases) { status in
                    let count = requests.filter { $0.status == status }.count
                    HStack(spacing: ENVISpacing.xs) {
                        Image(systemName: status.iconName)
                            .font(.system(size: 11))
                        Text("\(status.displayName) (\(count))")
                            .font(.interMedium(12))
                    }
                    .padding(.horizontal, ENVISpacing.md)
                    .padding(.vertical, ENVISpacing.sm)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    // MARK: - Request Cards

    private var requestList: some View {
        VStack(spacing: ENVISpacing.md) {
            ForEach(requests) { request in
                requestCard(request)
            }
        }
    }

    private func requestCard(_ request: ProcurementRequest) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.vendorName)
                        .font(.interSemiBold(16))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text(request.formattedAmount)
                        .font(.spaceMonoBold(14))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }

                Spacer()

                statusBadge(request.status)
            }

            Divider()
                .overlay(ENVITheme.border(for: colorScheme))

            HStack {
                Label {
                    Text(request.approverEmail)
                        .font(.interRegular(12))
                } icon: {
                    Image(systemName: "person.fill")
                        .font(.system(size: 11))
                }
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Spacer()

                Text(request.submittedAt, style: .date)
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            if request.status == .pendingApproval {
                HStack(spacing: ENVISpacing.sm) {
                    actionButton(label: "APPROVE", color: ENVITheme.success)
                    actionButton(label: "REJECT", color: ENVITheme.error)
                }
            }
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func statusBadge(_ status: ProcurementStatus) -> some View {
        let color: Color = {
            switch status {
            case .draft:            return ENVITheme.textSecondary(for: colorScheme)
            case .pendingApproval:  return ENVITheme.warning
            case .approved:         return ENVITheme.success
            case .rejected:         return ENVITheme.error
            case .completed:        return ENVITheme.info
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

    private func actionButton(label: String, color: Color) -> some View {
        Button {} label: {
            Text(label)
                .font(.spaceMonoBold(12))
                .frame(maxWidth: .infinity)
                .padding(.vertical, ENVISpacing.sm)
                .foregroundColor(color)
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.sm)
                        .stroke(color, lineWidth: 1)
                )
        }
    }

    // MARK: - New Request Sheet

    private var newRequestSheet: some View {
        NavigationStack {
            VStack(spacing: ENVISpacing.lg) {
                formField(title: "Vendor Name", text: $newVendor, placeholder: "e.g. Adobe Creative Cloud")
                formField(title: "Amount (USD)", text: $newAmount, placeholder: "e.g. 12500")
                formField(title: "Approver Email", text: $newApprover, placeholder: "e.g. cfo@company.com")

                Spacer()

                Button {
                    Task { await submitRequest() }
                } label: {
                    Text("SUBMIT REQUEST")
                        .font(.spaceMonoBold(14))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ENVISpacing.md)
                        .background(ENVITheme.text(for: colorScheme))
                        .foregroundColor(ENVITheme.background(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
                }
                .disabled(newVendor.isEmpty || newAmount.isEmpty)
            }
            .padding(ENVISpacing.xl)
            .background(ENVITheme.background(for: colorScheme))
            .navigationTitle("New Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showNewRequest = false }
                }
            }
        }
    }

    private func formField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text(title.uppercased())
                .font(.spaceMono(11))
                .tracking(1)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            TextField(placeholder, text: text)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .padding(ENVISpacing.md)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
        }
    }

    // MARK: - Data

    private func loadRequests() async {
        do { requests = try await repository.fetchProcurements() } catch {}
        isLoading = false
    }

    private func submitRequest() async {
        guard let amount = Decimal(string: newAmount) else { return }
        let request = ProcurementRequest(
            id: UUID().uuidString,
            vendorName: newVendor,
            amount: amount,
            status: .draft,
            approverEmail: newApprover,
            submittedAt: Date()
        )
        if let created = try? await repository.createProcurement(request) {
            requests.insert(created, at: 0)
        }
        showNewRequest = false
        newVendor = ""
        newAmount = ""
        newApprover = ""
    }
}
