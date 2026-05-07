import SwiftUI
import Combine

/// ViewModel for the Agency & Multi-Client Operations feature set (D25: ENVI-0601–ENVI-0625).
@MainActor
final class AgencyViewModel: ObservableObject {
    nonisolated(unsafe) let repository: AgencyRepository
    // MARK: - Dashboard
    @Published var dashboard: AgencyDashboard = AgencyDashboard()
    @Published var isLoadingDashboard = false

    // MARK: - Clients
    @Published var clients: [ClientAccount] = []
    @Published var selectedClient: ClientAccount?
    @Published var isLoadingClients = false
    @Published var clientSearchText = ""
    @Published var statusFilter: ClientStatus?

    // MARK: - Portal
    @Published var portal: ClientPortal?
    @Published var isLoadingPortal = false
    @Published var portalLinkCopied = false

    // MARK: - Reports
    @Published var generatedReport: WhiteLabelReport?
    @Published var isGeneratingReport = false
    @Published var reportStartDate: Date = Date().addingTimeInterval(-86400 * 30)
    @Published var reportEndDate: Date = Date()

    // MARK: - Error
    @Published var errorMessage: String?

    init(repository: AgencyRepository = AgencyRepositoryProvider.shared.repository) {
        self.repository = repository
        Task {
            await loadDashboard()
            await loadClients()
        }
    }

    // MARK: - Filtered Clients

    var filteredClients: [ClientAccount] {
        var result = clients
        if let filter = statusFilter {
            result = result.filter { $0.status == filter }
        }
        if !clientSearchText.isEmpty {
            let query = clientSearchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.industry.lowercased().contains(query) ||
                $0.contactName.lowercased().contains(query)
            }
        }
        return result
    }

    // MARK: - Revenue Per Client

    var revenueByClient: [(name: String, amount: Double)] {
        clients
            .filter { $0.status == .active }
            .sorted { $0.monthlyBudget > $1.monthlyBudget }
            .map { ($0.name, $0.monthlyBudget) }
    }

    // MARK: - Load Dashboard

    @MainActor
    func loadDashboard() async {
        isLoadingDashboard = true
        errorMessage = nil
        do {
            dashboard = try await repository.fetchDashboard()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingDashboard = false
    }

    // MARK: - Load Clients

    @MainActor
    func loadClients() async {
        isLoadingClients = true
        errorMessage = nil
        do {
            clients = try await repository.fetchClients()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingClients = false
    }

    // MARK: - Create Client

    @MainActor
    func createClient(
        name: String,
        industry: String,
        contactName: String,
        contactEmail: String,
        monthlyBudget: Double
    ) async {
        let client = ClientAccount(
            name: name,
            industry: industry,
            contactName: contactName,
            contactEmail: contactEmail,
            monthlyBudget: monthlyBudget
        )
        do {
            let created = try await repository.createClient(client)
            clients.insert(created, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Load Portal

    @MainActor
    func loadPortal(for clientID: UUID) async {
        isLoadingPortal = true
        errorMessage = nil
        do {
            portal = try await repository.fetchPortal(clientID: clientID)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingPortal = false
    }

    // MARK: - Update Portal Permissions

    @MainActor
    func togglePermission(_ permission: PortalPermission) {
        guard var current = portal else { return }
        if current.permissions.contains(permission) {
            current.permissions.removeAll { $0 == permission }
        } else {
            current.permissions.append(permission)
        }
        portal = current
    }

    @MainActor
    func savePortal() async {
        guard let current = portal else { return }
        do {
            portal = try await repository.updatePortal(current)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Copy Portal Link

    @MainActor
    func copyPortalLink() {
        guard let link = portal?.shareURL else { return }
        UIPasteboard.general.string = link
        portalLinkCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.portalLinkCopied = false
        }
    }

    // MARK: - Generate Report

    @MainActor
    func generateReport(for clientID: UUID) async {
        isGeneratingReport = true
        errorMessage = nil
        let range = DateRange(start: reportStartDate, end: reportEndDate)
        do {
            generatedReport = try await repository.generateReport(clientID: clientID, range: range)
        } catch {
            errorMessage = error.localizedDescription
        }
        isGeneratingReport = false
    }
}
