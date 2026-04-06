import SwiftUI
import Combine

/// ViewModel for the Collaboration, Review, and Approvals feature set.
final class CollaborationViewModel: ObservableObject {
    // MARK: - Reviews
    @Published var reviewRequests: [ReviewRequest] = []
    @Published var selectedReview: ReviewRequest?
    @Published var isLoadingReviews = false
    @Published var reviewError: String?

    // MARK: - Filter
    @Published var statusFilter: ReviewStatus?

    // MARK: - Comments
    @Published var newCommentText = ""
    @Published var isSendingComment = false

    // MARK: - Approval Workflows
    @Published var workflows: [ApprovalWorkflow] = []

    // MARK: - Share Links
    @Published var generatedShareLink: ShareLink?
    @Published var sharePermission: SharePermission = .viewOnly
    @Published var shareExpiryDate: Date = Date().addingTimeInterval(86400 * 7)
    @Published var isGeneratingLink = false
    @Published var linkCopied = false

    // MARK: - Sheet State
    @Published var isShowingShareSheet = false

    private let repository: CollaborationRepository

    init(repository: CollaborationRepository = CollaborationRepositoryProvider.shared.repository) {
        self.repository = repository
        Task { await loadReviews() }
    }

    // MARK: - Filtered Reviews

    var filteredReviews: [ReviewRequest] {
        guard let filter = statusFilter else { return reviewRequests }
        return reviewRequests.filter { $0.status == filter }
    }

    // MARK: - Load Reviews

    @MainActor
    func loadReviews() async {
        isLoadingReviews = true
        reviewError = nil
        do {
            reviewRequests = try await repository.fetchReviewRequests()
        } catch {
            reviewError = error.localizedDescription
        }
        isLoadingReviews = false
    }

    // MARK: - Create Review Request

    @MainActor
    func createReviewRequest(contentTitle: String, reviewerName: String, deadline: Date?) async {
        let request = ReviewRequest(
            contentTitle: contentTitle,
            reviewerName: reviewerName,
            deadline: deadline
        )
        do {
            let created = try await repository.createReviewRequest(request)
            reviewRequests.insert(created, at: 0)
        } catch {
            reviewError = error.localizedDescription
        }
    }

    // MARK: - Update Review Status

    @MainActor
    func updateStatus(_ status: ReviewStatus, for review: ReviewRequest) async {
        do {
            try await repository.updateReviewStatus(reviewID: review.id, status: status)
            if let index = reviewRequests.firstIndex(where: { $0.id == review.id }) {
                reviewRequests[index].status = status
            }
            selectedReview?.status = status
        } catch {
            reviewError = error.localizedDescription
        }
    }

    // MARK: - Add Comment

    @MainActor
    func addComment(to review: ReviewRequest) async {
        let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSendingComment = true
        let comment = ReviewComment(authorName: "You", text: text)
        do {
            let added = try await repository.addComment(comment, to: review.id)
            if let index = reviewRequests.firstIndex(where: { $0.id == review.id }) {
                reviewRequests[index].comments.append(added)
            }
            selectedReview?.comments.append(added)
            newCommentText = ""
        } catch {
            reviewError = error.localizedDescription
        }
        isSendingComment = false
    }

    // MARK: - Resolve Comment

    @MainActor
    func resolveComment(_ comment: ReviewComment, in review: ReviewRequest) async {
        do {
            try await repository.resolveComment(commentID: comment.id, in: review.id)
            if let rIndex = reviewRequests.firstIndex(where: { $0.id == review.id }),
               let cIndex = reviewRequests[rIndex].comments.firstIndex(where: { $0.id == comment.id }) {
                reviewRequests[rIndex].comments[cIndex].resolved = true
            }
            if let cIndex = selectedReview?.comments.firstIndex(where: { $0.id == comment.id }) {
                selectedReview?.comments[cIndex].resolved = true
            }
        } catch {
            reviewError = error.localizedDescription
        }
    }

    // MARK: - Load Workflows

    @MainActor
    func loadWorkflows() async {
        do {
            workflows = try await repository.fetchApprovalWorkflows()
        } catch {
            reviewError = error.localizedDescription
        }
    }

    // MARK: - Generate Share Link

    @MainActor
    func generateShareLink(for contentID: UUID) async {
        isGeneratingLink = true
        do {
            generatedShareLink = try await repository.createShareLink(
                contentID: contentID,
                permissions: sharePermission,
                expiresAt: shareExpiryDate
            )
        } catch {
            reviewError = error.localizedDescription
        }
        isGeneratingLink = false
    }

    // MARK: - Copy Link

    @MainActor
    func copyLinkToClipboard() {
        guard let link = generatedShareLink else { return }
        UIPasteboard.general.string = link.url
        linkCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.linkCopied = false
        }
    }
}
