import SwiftUI
import Combine

/// ViewModel for Campaigns, Briefs, Content Requests, and Sprint Board.
final class CampaignViewModel: ObservableObject {
    // MARK: - Campaigns
    @Published var campaigns: [Campaign] = []
    @Published var selectedCampaign: Campaign?
    @Published var editingCampaign: Campaign?
    @Published var isLoadingCampaigns = false
    @Published var campaignError: String?

    // MARK: - Briefs
    @Published var briefs: [CreativeBrief] = []
    @Published var editingBrief: CreativeBrief?
    @Published var isLoadingBriefs = false

    // MARK: - Content Requests
    @Published var requests: [ContentRequest] = []
    @Published var isLoadingRequests = false

    // MARK: - Sprint Board
    @Published var sprintItems: [SprintItem] = []
    @Published var isLoadingSprint = false

    // MARK: - Filters
    @Published var statusFilter: CampaignStatus?

    // MARK: - Sheet State
    @Published var isShowingCampaignEditor = false
    @Published var isShowingBriefEditor = false
    @Published var isShowingSprintBoard = false

    private nonisolated(unsafe) let repository: CampaignRepository

    @MainActor
    init(repository: CampaignRepository = CampaignRepositoryProvider.shared.repository) {
        self.repository = repository
        Task {
            await loadCampaigns()
            await loadRequests()
            await loadSprintBoard()
        }
    }

    // MARK: - Filtered Campaigns

    var filteredCampaigns: [Campaign] {
        guard let filter = statusFilter else { return campaigns }
        return campaigns.filter { $0.status == filter }
    }

    // MARK: - Sprint Helpers

    func sprintItems(for column: SprintColumn) -> [SprintItem] {
        sprintItems.filter { $0.column == column }
    }

    var sprintProgress: Double {
        guard !sprintItems.isEmpty else { return 0 }
        let done = Double(sprintItems.filter { $0.column == .done }.count)
        return done / Double(sprintItems.count)
    }

    // MARK: - Campaign CRUD

    @MainActor
    func loadCampaigns() async {
        isLoadingCampaigns = true
        campaignError = nil

        do {
            campaigns = try await repository.fetchCampaigns()
        } catch {
            if AppEnvironment.current == .dev {
                campaigns = Campaign.mockList
            } else {
                campaignError = "Unable to load campaigns."
            }
        }

        isLoadingCampaigns = false
    }

    @MainActor
    func createCampaign(_ campaign: Campaign) async {
        campaignError = nil
        campaigns.insert(campaign, at: 0)

        do {
            _ = try await repository.createCampaign(campaign)
        } catch {
            campaigns.removeAll { $0.id == campaign.id }
            campaignError = "Could not create campaign."
        }
    }

    @MainActor
    func updateCampaign(_ campaign: Campaign) async {
        campaignError = nil
        guard let index = campaigns.firstIndex(where: { $0.id == campaign.id }) else { return }
        let snapshot = campaigns[index]
        campaigns[index] = campaign

        do {
            try await repository.updateCampaign(campaign)
        } catch {
            campaigns[index] = snapshot
            campaignError = "Could not update campaign."
        }
    }

    @MainActor
    func saveCampaign(_ campaign: Campaign) async {
        if campaigns.contains(where: { $0.id == campaign.id }) {
            await updateCampaign(campaign)
        } else {
            await createCampaign(campaign)
        }
        isShowingCampaignEditor = false
        editingCampaign = nil
    }

    // MARK: - Brief CRUD

    @MainActor
    func loadBriefs(for campaignID: UUID? = nil) async {
        isLoadingBriefs = true

        do {
            briefs = try await repository.fetchBriefs(campaignID: campaignID)
        } catch {
            if AppEnvironment.current == .dev {
                briefs = CreativeBrief.mockList
            }
        }

        isLoadingBriefs = false
    }

    @MainActor
    func createBrief(_ brief: CreativeBrief) async {
        do {
            let created = try await repository.createBrief(brief)
            briefs.insert(created, at: 0)
        } catch {
            campaignError = "Could not create brief."
        }
    }

    @MainActor
    func saveBrief(_ brief: CreativeBrief) async {
        if briefs.contains(where: { $0.id == brief.id }) {
            if let index = briefs.firstIndex(where: { $0.id == brief.id }) {
                briefs[index] = brief
            }
        } else {
            await createBrief(brief)
        }
        isShowingBriefEditor = false
        editingBrief = nil
    }

    // MARK: - Content Requests

    @MainActor
    func loadRequests() async {
        isLoadingRequests = true

        do {
            requests = try await repository.fetchRequests()
        } catch {
            if AppEnvironment.current == .dev {
                requests = ContentRequest.mockList
            }
        }

        isLoadingRequests = false
    }

    @MainActor
    func updateRequest(_ request: ContentRequest) async {
        guard let index = requests.firstIndex(where: { $0.id == request.id }) else { return }
        let snapshot = requests[index]
        requests[index] = request

        do {
            try await repository.updateRequest(request)
        } catch {
            requests[index] = snapshot
            campaignError = "Could not update request."
        }
    }

    // MARK: - Sprint Board

    @MainActor
    func loadSprintBoard() async {
        isLoadingSprint = true

        do {
            sprintItems = try await repository.fetchSprintBoard()
        } catch {
            if AppEnvironment.current == .dev {
                sprintItems = SprintItem.mockList
            }
        }

        isLoadingSprint = false
    }

    @MainActor
    func moveSprintItem(_ item: SprintItem, to column: SprintColumn) async {
        guard let index = sprintItems.firstIndex(where: { $0.id == item.id }) else { return }
        let snapshot = sprintItems[index]
        var updated = item
        updated.column = column
        sprintItems[index] = updated

        do {
            try await repository.updateSprintItem(updated)
        } catch {
            sprintItems[index] = snapshot
            campaignError = "Could not move sprint item."
        }
    }

    // MARK: - Editor Helpers

    func startCreatingCampaign() {
        editingCampaign = Campaign(name: "")
        isShowingCampaignEditor = true
    }

    func startEditingCampaign(_ campaign: Campaign) {
        editingCampaign = campaign
        isShowingCampaignEditor = true
    }

    func startCreatingBrief(for campaignID: UUID) {
        editingBrief = CreativeBrief(campaignID: campaignID)
        isShowingBriefEditor = true
    }

    func startEditingBrief(_ brief: CreativeBrief) {
        editingBrief = brief
        isShowingBriefEditor = true
    }
}
