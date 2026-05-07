import SwiftUI
import Combine

/// ViewModel for the Support Center (tickets, FAQs, health score, new ticket flow).
///
/// Phase 17 — Plan 02. Replaces the prior pattern where `SupportCenterView`
/// held `SupportTicket.mockList` / `FAQArticle.mockList` in `@State`
/// defaults and never called `SupportRepository`. Now backed by
/// `SupportRepositoryProvider.shared.repository`.
@MainActor
final class SupportViewModel: ObservableObject {
    // MARK: - State
    @Published var tickets: [SupportTicket] = []
    @Published var faqs: [FAQArticle] = []
    @Published var healthScore: HealthScore?

    @Published var isLoading = false
    @Published var errorMessage: String?

    private nonisolated(unsafe) let repository: SupportRepository

    init(repository: SupportRepository = SupportRepositoryProvider.shared.repository) {
        self.repository = repository
    }

    // MARK: - Loading

    @MainActor
    func loadSupportCenter() async {
        isLoading = true
        errorMessage = nil

        do {
            async let ticketsTask = repository.fetchTickets()
            async let faqsTask = repository.fetchFAQs()
            async let healthTask = repository.fetchHealthScore()

            let (t, f, h) = try await (ticketsTask, faqsTask, healthTask)
            tickets = t
            faqs = f
            healthScore = h
        } catch {
            errorMessage = "Unable to load support center."
        }

        isLoading = false
    }

    // MARK: - Actions

    @MainActor
    func submitTicket(subject: String, description: String, priority: TicketPriority) async {
        guard !subject.isEmpty else { return }
        errorMessage = nil

        do {
            let ticket = try await repository.createTicket(
                subject: subject,
                description: description,
                priority: priority
            )
            tickets.insert(ticket, at: 0)
        } catch {
            errorMessage = "Unable to submit ticket."
        }
    }
}

// MARK: - Preview Helper

#if DEBUG
extension SupportViewModel {
    /// Hydrates a VM with mock data for SwiftUI previews. Never reaches
    /// production because it's wrapped in `#if DEBUG`.
    static func preview() -> SupportViewModel {
        let vm = SupportViewModel(repository: MockSupportRepository())
        vm.tickets = SupportTicket.mockList
        vm.faqs = FAQArticle.mockList
        vm.healthScore = .mock
        return vm
    }
}
#endif
