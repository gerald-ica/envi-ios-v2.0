import Foundation

// MARK: - Protocol

protocol CampaignRepository {
    func fetchCampaigns() async throws -> [Campaign]
    func createCampaign(_ campaign: Campaign) async throws -> Campaign
    func updateCampaign(_ campaign: Campaign) async throws

    func fetchBriefs(campaignID: UUID?) async throws -> [CreativeBrief]
    func createBrief(_ brief: CreativeBrief) async throws -> CreativeBrief

    func fetchRequests() async throws -> [ContentRequest]
    func updateRequest(_ request: ContentRequest) async throws

    func fetchSprintBoard() async throws -> [SprintItem]
    func updateSprintItem(_ item: SprintItem) async throws
}

// MARK: - Mock Implementation

final class MockCampaignRepository: CampaignRepository {
    private var campaigns: [Campaign] = Campaign.mockList
    private var briefs: [CreativeBrief] = CreativeBrief.mockList
    private var requests: [ContentRequest] = ContentRequest.mockList
    private var sprintItems: [SprintItem] = SprintItem.mockList

    func fetchCampaigns() async throws -> [Campaign] {
        campaigns
    }

    func createCampaign(_ campaign: Campaign) async throws -> Campaign {
        campaigns.insert(campaign, at: 0)
        return campaign
    }

    func updateCampaign(_ campaign: Campaign) async throws {
        guard let index = campaigns.firstIndex(where: { $0.id == campaign.id }) else {
            throw CampaignError.notFound
        }
        campaigns[index] = campaign
    }

    func fetchBriefs(campaignID: UUID?) async throws -> [CreativeBrief] {
        guard let campaignID else { return briefs }
        return briefs.filter { $0.campaignID == campaignID }
    }

    func createBrief(_ brief: CreativeBrief) async throws -> CreativeBrief {
        briefs.insert(brief, at: 0)
        return brief
    }

    func fetchRequests() async throws -> [ContentRequest] {
        requests
    }

    func updateRequest(_ request: ContentRequest) async throws {
        guard let index = requests.firstIndex(where: { $0.id == request.id }) else {
            throw CampaignError.notFound
        }
        requests[index] = request
    }

    func fetchSprintBoard() async throws -> [SprintItem] {
        sprintItems
    }

    func updateSprintItem(_ item: SprintItem) async throws {
        guard let index = sprintItems.firstIndex(where: { $0.id == item.id }) else {
            throw CampaignError.notFound
        }
        sprintItems[index] = item
    }
}

// MARK: - API Implementation

final class APICampaignRepository: CampaignRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchCampaigns() async throws -> [Campaign] {
        try await apiClient.request(
            endpoint: "campaigns",
            method: .get,
            requiresAuth: true
        )
    }

    func createCampaign(_ campaign: Campaign) async throws -> Campaign {
        try await apiClient.request(
            endpoint: "campaigns",
            method: .post,
            body: campaign,
            requiresAuth: true
        )
    }

    func updateCampaign(_ campaign: Campaign) async throws {
        try await apiClient.requestVoid(
            endpoint: "campaigns/\(campaign.id.uuidString)",
            method: .put,
            body: campaign,
            requiresAuth: true
        )
    }

    func fetchBriefs(campaignID: UUID?) async throws -> [CreativeBrief] {
        var endpoint = "campaigns/briefs"
        if let campaignID {
            endpoint += "?campaignID=\(campaignID.uuidString)"
        }
        return try await apiClient.request(
            endpoint: endpoint,
            method: .get,
            requiresAuth: true
        )
    }

    func createBrief(_ brief: CreativeBrief) async throws -> CreativeBrief {
        try await apiClient.request(
            endpoint: "campaigns/briefs",
            method: .post,
            body: brief,
            requiresAuth: true
        )
    }

    func fetchRequests() async throws -> [ContentRequest] {
        try await apiClient.request(
            endpoint: "campaigns/requests",
            method: .get,
            requiresAuth: true
        )
    }

    func updateRequest(_ request: ContentRequest) async throws {
        try await apiClient.requestVoid(
            endpoint: "campaigns/requests/\(request.id.uuidString)",
            method: .put,
            body: request,
            requiresAuth: true
        )
    }

    func fetchSprintBoard() async throws -> [SprintItem] {
        try await apiClient.request(
            endpoint: "campaigns/sprint",
            method: .get,
            requiresAuth: true
        )
    }

    func updateSprintItem(_ item: SprintItem) async throws {
        try await apiClient.requestVoid(
            endpoint: "campaigns/sprint/\(item.id.uuidString)",
            method: .put,
            body: item,
            requiresAuth: true
        )
    }
}

// MARK: - Error

enum CampaignError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound: return "The requested campaign item was not found."
        }
    }
}

// MARK: - Provider

enum CampaignRepositoryProvider {
    static var shared = RepositoryProvider<CampaignRepository>(
        dev: MockCampaignRepository(),
        api: APICampaignRepository()
    )
}
