import SwiftUI
import Combine

/// ViewModel powering the Commerce & Marketplace feature set (ENVI-0676..0725).
@MainActor
final class CommerceViewModel: ObservableObject {

    // MARK: - Published State

    @Published var offers: [ProductOffer] = []
    @Published var linkInBio: LinkInBio?
    @Published var deals: [SponsorshipDeal] = []
    @Published var marketplaceListings: [MarketplaceListing] = []
    @Published var ugcRequests: [UGCRequest] = []

    @Published var selectedMarketplaceCategory: MarketplaceCategory?
    @Published var marketplaceSearchText = ""
    @Published var selectedDealFilter: DealStatus?

    @Published var isLoadingOffers = false
    @Published var isLoadingBio = false
    @Published var isLoadingDeals = false
    @Published var isLoadingMarketplace = false
    @Published var isLoadingUGC = false
    @Published var isSavingBio = false

    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let repository: CommerceRepository

    // MARK: - Init

    init(repository: CommerceRepository = CommerceRepositoryFactory.make()) {
        self.repository = repository
    }

    // MARK: - Computed

    /// Total revenue across all offers.
    var totalRevenue: Decimal {
        offers.reduce(Decimal.zero) { $0 + ($1.price * Decimal($1.salesCount)) }
    }

    /// Formatted total revenue string.
    var formattedTotalRevenue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: totalRevenue as NSDecimalNumber) ?? "$0"
    }

    /// Total sales count across all offers.
    var totalSales: Int {
        offers.reduce(0) { $0 + $1.salesCount }
    }

    /// Deals filtered by the currently selected status.
    var filteredDeals: [SponsorshipDeal] {
        guard let filter = selectedDealFilter else {
            return deals.sorted { $0.status.sortOrder < $1.status.sortOrder }
        }
        return deals.filter { $0.status == filter }
    }

    /// Active deal pipeline value (non-completed, non-declined).
    var pipelineValue: Decimal {
        deals
            .filter { $0.status != .completed && $0.status != .declined }
            .reduce(Decimal.zero) { $0 + $1.budget }
    }

    /// Marketplace listings filtered by category and search text.
    var filteredMarketplace: [MarketplaceListing] {
        var results = marketplaceListings
        if let cat = selectedMarketplaceCategory {
            results = results.filter { $0.category == cat }
        }
        if !marketplaceSearchText.isEmpty {
            results = results.filter {
                $0.title.localizedCaseInsensitiveContains(marketplaceSearchText) ||
                $0.creatorName.localizedCaseInsensitiveContains(marketplaceSearchText)
            }
        }
        return results
    }

    /// Total clicks across all bio links.
    var totalBioClicks: Int {
        linkInBio?.links.reduce(0) { $0 + $1.clicks } ?? 0
    }

    // MARK: - Data Loading

    /// Load all commerce data in parallel.
    func loadAll() async {
        async let o: () = loadOffers()
        async let b: () = loadLinkInBio()
        async let d: () = loadDeals()
        async let m: () = loadMarketplace()
        async let u: () = loadUGCRequests()
        _ = await (o, b, d, m, u)
    }

    func loadOffers() async {
        isLoadingOffers = true
        defer { isLoadingOffers = false }
        do {
            offers = try await repository.fetchOffers()
        } catch {
            errorMessage = "Failed to load offers: \(error.localizedDescription)"
        }
    }

    func loadLinkInBio() async {
        isLoadingBio = true
        defer { isLoadingBio = false }
        do {
            linkInBio = try await repository.fetchLinkInBio()
        } catch {
            errorMessage = "Failed to load Link-in-Bio: \(error.localizedDescription)"
        }
    }

    func loadDeals() async {
        isLoadingDeals = true
        defer { isLoadingDeals = false }
        do {
            deals = try await repository.fetchDeals()
        } catch {
            errorMessage = "Failed to load deals: \(error.localizedDescription)"
        }
    }

    func loadMarketplace() async {
        isLoadingMarketplace = true
        defer { isLoadingMarketplace = false }
        do {
            marketplaceListings = try await repository.fetchMarketplace(category: selectedMarketplaceCategory)
        } catch {
            errorMessage = "Failed to load marketplace: \(error.localizedDescription)"
        }
    }

    func loadUGCRequests() async {
        isLoadingUGC = true
        defer { isLoadingUGC = false }
        do {
            ugcRequests = try await repository.fetchUGCRequests()
        } catch {
            errorMessage = "Failed to load UGC requests: \(error.localizedDescription)"
        }
    }

    // MARK: - Mutations

    func saveLinkInBio() async {
        guard var bio = linkInBio else { return }
        isSavingBio = true
        defer { isSavingBio = false }
        do {
            bio = try await repository.updateLinkInBio(bio)
            linkInBio = bio
        } catch {
            errorMessage = "Failed to save Link-in-Bio: \(error.localizedDescription)"
        }
    }

    func moveBioLink(from source: IndexSet, to destination: Int) {
        linkInBio?.links.move(fromOffsets: source, toOffset: destination)
    }

    func toggleBioLink(_ link: BioLink) {
        guard let idx = linkInBio?.links.firstIndex(where: { $0.id == link.id }) else { return }
        linkInBio?.links[idx].isActive.toggle()
    }

    func deleteBioLink(at offsets: IndexSet) {
        linkInBio?.links.remove(atOffsets: offsets)
    }

    func addBioLink(title: String, url: String) {
        let link = BioLink(id: UUID().uuidString, title: title, url: url, clicks: 0, isActive: true)
        linkInBio?.links.append(link)
    }

    func selectTheme(_ theme: LinkInBioThemeName) {
        linkInBio?.theme = theme
    }
}
