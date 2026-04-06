import Foundation

// MARK: - Protocol

protocol SupportRepository {
    // Tickets
    func fetchTickets() async throws -> [SupportTicket]
    func fetchTicket(id: UUID) async throws -> SupportTicket
    func createTicket(subject: String, description: String, priority: TicketPriority) async throws -> SupportTicket
    func replyToTicket(id: UUID, text: String) async throws -> TicketMessage

    // FAQ
    func fetchFAQs() async throws -> [FAQArticle]
    func markHelpful(articleID: UUID) async throws

    // Health Score
    func fetchHealthScore() async throws -> HealthScore
}

// MARK: - Mock Implementation

final class MockSupportRepository: SupportRepository {
    private var tickets: [SupportTicket] = SupportTicket.mockList
    private var faqs: [FAQArticle] = FAQArticle.mockList
    private var healthScore: HealthScore = .mock

    func fetchTickets() async throws -> [SupportTicket] {
        tickets
    }

    func fetchTicket(id: UUID) async throws -> SupportTicket {
        guard let ticket = tickets.first(where: { $0.id == id }) else {
            throw SupportError.notFound
        }
        return ticket
    }

    func createTicket(subject: String, description: String, priority: TicketPriority) async throws -> SupportTicket {
        let ticket = SupportTicket(
            subject: subject,
            description: description,
            priority: priority
        )
        tickets.insert(ticket, at: 0)
        return ticket
    }

    func replyToTicket(id: UUID, text: String) async throws -> TicketMessage {
        guard let index = tickets.firstIndex(where: { $0.id == id }) else {
            throw SupportError.notFound
        }
        let message = TicketMessage(senderName: "You", text: text)
        tickets[index].messages.append(message)
        return message
    }

    func fetchFAQs() async throws -> [FAQArticle] {
        faqs
    }

    func markHelpful(articleID: UUID) async throws {
        guard let index = faqs.firstIndex(where: { $0.id == articleID }) else {
            throw SupportError.notFound
        }
        faqs[index].helpfulness += 1
    }

    func fetchHealthScore() async throws -> HealthScore {
        healthScore
    }
}

// MARK: - API Implementation

final class APISupportRepository: SupportRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchTickets() async throws -> [SupportTicket] {
        try await apiClient.request(
            endpoint: "support/tickets",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchTicket(id: UUID) async throws -> SupportTicket {
        try await apiClient.request(
            endpoint: "support/tickets/\(id.uuidString)",
            method: .get,
            requiresAuth: true
        )
    }

    func createTicket(subject: String, description: String, priority: TicketPriority) async throws -> SupportTicket {
        try await apiClient.request(
            endpoint: "support/tickets",
            method: .post,
            body: CreateTicketBody(subject: subject, description: description, priority: priority),
            requiresAuth: true
        )
    }

    func replyToTicket(id: UUID, text: String) async throws -> TicketMessage {
        try await apiClient.request(
            endpoint: "support/tickets/\(id.uuidString)/messages",
            method: .post,
            body: ReplyTicketBody(text: text),
            requiresAuth: true
        )
    }

    func fetchFAQs() async throws -> [FAQArticle] {
        try await apiClient.request(
            endpoint: "support/faqs",
            method: .get,
            requiresAuth: true
        )
    }

    func markHelpful(articleID: UUID) async throws {
        try await apiClient.requestVoid(
            endpoint: "support/faqs/\(articleID.uuidString)/helpful",
            method: .post,
            body: EmptySupportBody(),
            requiresAuth: true
        )
    }

    func fetchHealthScore() async throws -> HealthScore {
        try await apiClient.request(
            endpoint: "support/health-score",
            method: .get,
            requiresAuth: true
        )
    }
}

// MARK: - Request Bodies

private struct CreateTicketBody: Encodable {
    let subject: String
    let description: String
    let priority: TicketPriority
}

private struct ReplyTicketBody: Encodable {
    let text: String
}

private typealias EmptySupportBody = EmptyBody

// MARK: - Provider

enum SupportRepositoryProvider {
    static var shared = RepositoryProvider<SupportRepository>(
        dev: MockSupportRepository(),
        api: APISupportRepository()
    )
}
