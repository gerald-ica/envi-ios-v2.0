import Foundation

// MARK: - Protocol

protocol CommunityRepository {
    // Inbox
    func fetchInbox(filter: InboxFilter) async throws -> [InboxMessage]
    func markRead(messageID: UUID) async throws
    func toggleFlag(messageID: UUID) async throws
    func sendReply(to messageID: UUID, text: String) async throws

    // Contacts
    func fetchContacts() async throws -> [AudienceContact]
    func fetchContact(id: UUID) async throws -> AudienceContact

    // Segments
    func fetchSegments() async throws -> [AudienceSegment]
    func createSegment(_ segment: AudienceSegment) async throws -> AudienceSegment
    func deleteSegment(id: UUID) async throws
}

// MARK: - Mock Implementation

final class MockCommunityRepository: CommunityRepository {
    private var messages: [InboxMessage] = InboxMessage.mockList
    private var contacts: [AudienceContact] = AudienceContact.mockList
    private var segments: [AudienceSegment] = AudienceSegment.mockList

    func fetchInbox(filter: InboxFilter) async throws -> [InboxMessage] {
        switch filter {
        case .all:      return messages
        case .unread:   return messages.filter { !$0.isRead }
        case .flagged:  return messages.filter { $0.isFlagged }
        case .platform: return messages // caller applies platform filter
        }
    }

    func markRead(messageID: UUID) async throws {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else {
            throw CommunityError.notFound
        }
        messages[index].isRead = true
    }

    func toggleFlag(messageID: UUID) async throws {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else {
            throw CommunityError.notFound
        }
        messages[index].isFlagged.toggle()
    }

    func sendReply(to messageID: UUID, text: String) async throws {
        guard messages.contains(where: { $0.id == messageID }) else {
            throw CommunityError.notFound
        }
        // Mock: no-op — reply sent
    }

    func fetchContacts() async throws -> [AudienceContact] {
        contacts
    }

    func fetchContact(id: UUID) async throws -> AudienceContact {
        guard let contact = contacts.first(where: { $0.id == id }) else {
            throw CommunityError.notFound
        }
        return contact
    }

    func fetchSegments() async throws -> [AudienceSegment] {
        segments
    }

    func createSegment(_ segment: AudienceSegment) async throws -> AudienceSegment {
        segments.insert(segment, at: 0)
        return segment
    }

    func deleteSegment(id: UUID) async throws {
        segments.removeAll { $0.id == id }
    }
}

// MARK: - API Implementation

final class APICommunityRepository: CommunityRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchInbox(filter: InboxFilter) async throws -> [InboxMessage] {
        try await apiClient.request(
            endpoint: "community/inbox?filter=\(filter.rawValue)",
            method: .get,
            requiresAuth: true
        )
    }

    func markRead(messageID: UUID) async throws {
        try await apiClient.requestVoid(
            endpoint: "community/inbox/\(messageID.uuidString)/read",
            method: .put,
            body: EmptyCommunityBody(),
            requiresAuth: true
        )
    }

    func toggleFlag(messageID: UUID) async throws {
        try await apiClient.requestVoid(
            endpoint: "community/inbox/\(messageID.uuidString)/flag",
            method: .put,
            body: EmptyCommunityBody(),
            requiresAuth: true
        )
    }

    func sendReply(to messageID: UUID, text: String) async throws {
        try await apiClient.requestVoid(
            endpoint: "community/inbox/\(messageID.uuidString)/reply",
            method: .post,
            body: ReplyBody(text: text),
            requiresAuth: true
        )
    }

    func fetchContacts() async throws -> [AudienceContact] {
        try await apiClient.request(
            endpoint: "community/contacts",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchContact(id: UUID) async throws -> AudienceContact {
        try await apiClient.request(
            endpoint: "community/contacts/\(id.uuidString)",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchSegments() async throws -> [AudienceSegment] {
        try await apiClient.request(
            endpoint: "community/segments",
            method: .get,
            requiresAuth: true
        )
    }

    func createSegment(_ segment: AudienceSegment) async throws -> AudienceSegment {
        try await apiClient.request(
            endpoint: "community/segments",
            method: .post,
            body: segment,
            requiresAuth: true
        )
    }

    func deleteSegment(id: UUID) async throws {
        try await apiClient.requestVoid(
            endpoint: "community/segments/\(id.uuidString)",
            method: .delete,
            body: EmptyCommunityBody(),
            requiresAuth: true
        )
    }
}

// MARK: - Request Bodies

private typealias EmptyCommunityBody = EmptyBody

private struct ReplyBody: Encodable {
    let text: String
}

// MARK: - Error

enum CommunityError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound: return "The requested community item was not found."
        }
    }
}

// MARK: - Provider

enum CommunityRepositoryProvider {
    static var shared = RepositoryProvider<CommunityRepository>(
        dev: MockCommunityRepository(),
        api: APICommunityRepository()
    )
}
