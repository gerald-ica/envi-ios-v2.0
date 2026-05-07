import Foundation

// MARK: - Protocol

protocol CollaborationRepository {
    // Reviews
    func fetchReviewRequests() async throws -> [ReviewRequest]
    func createReviewRequest(_ request: ReviewRequest) async throws -> ReviewRequest

    // Comments
    func addComment(_ comment: ReviewComment, to reviewID: UUID) async throws -> ReviewComment
    func resolveComment(commentID: UUID, in reviewID: UUID) async throws

    // Status
    func updateReviewStatus(reviewID: UUID, status: ReviewStatus) async throws

    // Approval Workflows
    func fetchApprovalWorkflows() async throws -> [ApprovalWorkflow]

    // Share Links
    func createShareLink(contentID: UUID, permissions: SharePermission, expiresAt: Date?) async throws -> ShareLink
}

// MARK: - Mock Implementation

final class MockCollaborationRepository: CollaborationRepository {
    private var reviews: [ReviewRequest] = ReviewRequest.mockList
    private var workflows: [ApprovalWorkflow] = [ApprovalWorkflow.mock]

    func fetchReviewRequests() async throws -> [ReviewRequest] {
        reviews
    }

    func createReviewRequest(_ request: ReviewRequest) async throws -> ReviewRequest {
        reviews.insert(request, at: 0)
        return request
    }

    func addComment(_ comment: ReviewComment, to reviewID: UUID) async throws -> ReviewComment {
        guard let index = reviews.firstIndex(where: { $0.id == reviewID }) else {
            throw CollaborationError.notFound
        }
        reviews[index].comments.append(comment)
        return comment
    }

    func resolveComment(commentID: UUID, in reviewID: UUID) async throws {
        guard let rIndex = reviews.firstIndex(where: { $0.id == reviewID }) else {
            throw CollaborationError.notFound
        }
        guard let cIndex = reviews[rIndex].comments.firstIndex(where: { $0.id == commentID }) else {
            throw CollaborationError.notFound
        }
        reviews[rIndex].comments[cIndex].resolved = true
    }

    func updateReviewStatus(reviewID: UUID, status: ReviewStatus) async throws {
        guard let index = reviews.firstIndex(where: { $0.id == reviewID }) else {
            throw CollaborationError.notFound
        }
        reviews[index].status = status
    }

    func fetchApprovalWorkflows() async throws -> [ApprovalWorkflow] {
        workflows
    }

    func createShareLink(contentID: UUID, permissions: SharePermission, expiresAt: Date?) async throws -> ShareLink {
        ShareLink(
            contentID: contentID,
            url: "https://envi.app/share/\(UUID().uuidString.prefix(8))",
            expiresAt: expiresAt,
            permissions: permissions,
            viewCount: 0
        )
    }
}

// MARK: - API Implementation

final class APICollaborationRepository: CollaborationRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchReviewRequests() async throws -> [ReviewRequest] {
        try await apiClient.request(
            endpoint: "collaboration/reviews",
            method: .get,
            requiresAuth: true
        )
    }

    func createReviewRequest(_ request: ReviewRequest) async throws -> ReviewRequest {
        try await apiClient.request(
            endpoint: "collaboration/reviews",
            method: .post,
            body: request,
            requiresAuth: true
        )
    }

    func addComment(_ comment: ReviewComment, to reviewID: UUID) async throws -> ReviewComment {
        try await apiClient.request(
            endpoint: "collaboration/reviews/\(reviewID.uuidString)/comments",
            method: .post,
            body: comment,
            requiresAuth: true
        )
    }

    func resolveComment(commentID: UUID, in reviewID: UUID) async throws {
        try await apiClient.requestVoid(
            endpoint: "collaboration/comments/\(commentID.uuidString)/resolve",
            method: .put,
            body: EmptyCollaborationBody(),
            requiresAuth: true
        )
    }

    func updateReviewStatus(reviewID: UUID, status: ReviewStatus) async throws {
        try await apiClient.requestVoid(
            endpoint: "collaboration/reviews/\(reviewID.uuidString)/status",
            method: .put,
            body: StatusUpdateBody(status: status),
            requiresAuth: true
        )
    }

    func fetchApprovalWorkflows() async throws -> [ApprovalWorkflow] {
        try await apiClient.request(
            endpoint: "collaboration/approvals",
            method: .get,
            requiresAuth: true
        )
    }

    func createShareLink(contentID: UUID, permissions: SharePermission, expiresAt: Date?) async throws -> ShareLink {
        try await apiClient.request(
            endpoint: "collaboration/share-links",
            method: .post,
            body: ShareLinkCreateBody(contentID: contentID, permissions: permissions, expiresAt: expiresAt),
            requiresAuth: true
        )
    }
}

// MARK: - Request Bodies

private typealias EmptyCollaborationBody = EmptyBody

private struct StatusUpdateBody: Encodable {
    let status: ReviewStatus
}

private struct ShareLinkCreateBody: Encodable {
    let contentID: UUID
    let permissions: SharePermission
    let expiresAt: Date?
}

// MARK: - Error

enum CollaborationError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound: return "The requested collaboration item was not found."
        }
    }
}

// MARK: - Provider

@MainActor
enum CollaborationRepositoryProvider {
    static nonisolated(unsafe) var shared = RepositoryProvider<CollaborationRepository>(
        dev: MockCollaborationRepository(),
        api: APICollaborationRepository()
    )
}
