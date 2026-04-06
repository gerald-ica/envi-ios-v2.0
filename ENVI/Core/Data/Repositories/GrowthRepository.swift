import Foundation

// MARK: - Protocol

protocol GrowthRepository {
    // Referral Program
    func fetchReferralProgram() async throws -> ReferralProgram
    func fetchInvites() async throws -> [ReferralInvite]
    func sendInvite(email: String) async throws -> ReferralInvite

    // Growth Metrics
    func fetchMetrics() async throws -> [GrowthMetric]
    func fetchViralLoops() async throws -> [ViralLoop]

    // Shareable Assets
    func fetchShareableAssets() async throws -> [ShareableAsset]
    func createShareableAsset(contentID: UUID, shareURL: String) async throws -> ShareableAsset
}

// MARK: - Mock Implementation

final class MockGrowthRepository: GrowthRepository {
    private var program: ReferralProgram = .mock
    private var invites: [ReferralInvite] = ReferralInvite.mockList
    private var metrics: [GrowthMetric] = GrowthMetric.mockList
    private var loops: [ViralLoop] = ViralLoop.mockList
    private var assets: [ShareableAsset] = ShareableAsset.mockList

    func fetchReferralProgram() async throws -> ReferralProgram {
        program
    }

    func fetchInvites() async throws -> [ReferralInvite] {
        invites
    }

    func sendInvite(email: String) async throws -> ReferralInvite {
        let invite = ReferralInvite(recipientEmail: email)
        invites.insert(invite, at: 0)
        program.referralCount += 1
        return invite
    }

    func fetchMetrics() async throws -> [GrowthMetric] {
        metrics
    }

    func fetchViralLoops() async throws -> [ViralLoop] {
        loops
    }

    func fetchShareableAssets() async throws -> [ShareableAsset] {
        assets
    }

    func createShareableAsset(contentID: UUID, shareURL: String) async throws -> ShareableAsset {
        let asset = ShareableAsset(contentID: contentID, shareURL: shareURL)
        assets.insert(asset, at: 0)
        return asset
    }
}

// MARK: - API Implementation

final class APIGrowthRepository: GrowthRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchReferralProgram() async throws -> ReferralProgram {
        try await apiClient.request(
            endpoint: "growth/referral",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchInvites() async throws -> [ReferralInvite] {
        try await apiClient.request(
            endpoint: "growth/referral/invites",
            method: .get,
            requiresAuth: true
        )
    }

    func sendInvite(email: String) async throws -> ReferralInvite {
        try await apiClient.request(
            endpoint: "growth/referral/invites",
            method: .post,
            body: InviteBody(email: email),
            requiresAuth: true
        )
    }

    func fetchMetrics() async throws -> [GrowthMetric] {
        try await apiClient.request(
            endpoint: "growth/metrics",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchViralLoops() async throws -> [ViralLoop] {
        try await apiClient.request(
            endpoint: "growth/viral-loops",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchShareableAssets() async throws -> [ShareableAsset] {
        try await apiClient.request(
            endpoint: "growth/shareable-assets",
            method: .get,
            requiresAuth: true
        )
    }

    func createShareableAsset(contentID: UUID, shareURL: String) async throws -> ShareableAsset {
        try await apiClient.request(
            endpoint: "growth/shareable-assets",
            method: .post,
            body: ShareableAssetBody(contentID: contentID, shareURL: shareURL),
            requiresAuth: true
        )
    }
}

// MARK: - Request Bodies

private struct InviteBody: Encodable {
    let email: String
}

private struct ShareableAssetBody: Encodable {
    let contentID: UUID
    let shareURL: String
}
