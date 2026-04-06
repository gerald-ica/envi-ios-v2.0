import Foundation

// MARK: - Protocol

/// Repository contract for commerce, marketplace, and creator partnership operations.
protocol CommerceRepository {
    // Offers (ENVI-0676..0690)
    func fetchOffers() async throws -> [ProductOffer]
    func createOffer(_ offer: ProductOffer) async throws -> ProductOffer

    // Link-in-Bio (ENVI-0691..0695)
    func fetchLinkInBio() async throws -> LinkInBio
    func updateLinkInBio(_ bio: LinkInBio) async throws -> LinkInBio

    // Sponsorship Deals (ENVI-0696..0705)
    func fetchDeals() async throws -> [SponsorshipDeal]

    // Marketplace (ENVI-0706..0715)
    func fetchMarketplace(category: MarketplaceCategory?) async throws -> [MarketplaceListing]

    // UGC Requests (ENVI-0716..0725)
    func fetchUGCRequests() async throws -> [UGCRequest]
}

// MARK: - Mock Implementation (Dev)

final class MockCommerceRepository: CommerceRepository {

    func fetchOffers() async throws -> [ProductOffer] {
        try await Task.sleep(for: .milliseconds(400))
        return ProductOffer.mock
    }

    func createOffer(_ offer: ProductOffer) async throws -> ProductOffer {
        try await Task.sleep(for: .milliseconds(300))
        return offer
    }

    func fetchLinkInBio() async throws -> LinkInBio {
        try await Task.sleep(for: .milliseconds(350))
        return LinkInBio.mock
    }

    func updateLinkInBio(_ bio: LinkInBio) async throws -> LinkInBio {
        try await Task.sleep(for: .milliseconds(300))
        return bio
    }

    func fetchDeals() async throws -> [SponsorshipDeal] {
        try await Task.sleep(for: .milliseconds(400))
        return SponsorshipDeal.mock
    }

    func fetchMarketplace(category: MarketplaceCategory?) async throws -> [MarketplaceListing] {
        try await Task.sleep(for: .milliseconds(450))
        guard let category else { return MarketplaceListing.mock }
        return MarketplaceListing.mock.filter { $0.category == category }
    }

    func fetchUGCRequests() async throws -> [UGCRequest] {
        try await Task.sleep(for: .milliseconds(350))
        return UGCRequest.mock
    }
}

// MARK: - API Implementation (Staging / Prod)

final class APICommerceRepository: CommerceRepository {

    func fetchOffers() async throws -> [ProductOffer] {
        try await APIClient.shared.request(
            endpoint: "commerce/offers",
            method: .get,
            requiresAuth: true
        )
    }

    func createOffer(_ offer: ProductOffer) async throws -> ProductOffer {
        try await APIClient.shared.request(
            endpoint: "commerce/offers",
            method: .post,
            body: offer,
            requiresAuth: true
        )
    }

    func fetchLinkInBio() async throws -> LinkInBio {
        try await APIClient.shared.request(
            endpoint: "commerce/link-in-bio",
            method: .get,
            requiresAuth: true
        )
    }

    func updateLinkInBio(_ bio: LinkInBio) async throws -> LinkInBio {
        try await APIClient.shared.request(
            endpoint: "commerce/link-in-bio",
            method: .put,
            body: bio,
            requiresAuth: true
        )
    }

    func fetchDeals() async throws -> [SponsorshipDeal] {
        try await APIClient.shared.request(
            endpoint: "commerce/deals",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchMarketplace(category: MarketplaceCategory?) async throws -> [MarketplaceListing] {
        let endpoint = category.map { "marketplace/listings?category=\($0.rawValue)" }
            ?? "marketplace/listings"
        return try await APIClient.shared.request(
            endpoint: endpoint,
            method: .get,
            requiresAuth: true
        )
    }

    func fetchUGCRequests() async throws -> [UGCRequest] {
        try await APIClient.shared.request(
            endpoint: "marketplace/ugc",
            method: .get,
            requiresAuth: true
        )
    }
}

// MARK: - Factory

enum CommerceRepositoryProvider {
    static var shared = RepositoryProvider<CommerceRepository>(
        dev: MockCommerceRepository(),
        api: APICommerceRepository()
    )
}
