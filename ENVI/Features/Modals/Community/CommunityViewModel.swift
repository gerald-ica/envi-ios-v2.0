import SwiftUI
import Combine

/// ViewModel for Community Inbox (D26) and Audience CRM (D27).
final class CommunityViewModel: ObservableObject {
    // MARK: - Inbox
    @Published var messages: [InboxMessage] = []
    @Published var isLoadingInbox = false
    @Published var inboxError: String?
    @Published var inboxFilter: InboxFilter = .all
    @Published var platformFilter: CommunityPlatform?
    @Published var selectedMessage: InboxMessage?
    @Published var replyText = ""
    @Published var isSendingReply = false

    // MARK: - Contacts
    @Published var contacts: [AudienceContact] = []
    @Published var isLoadingContacts = false
    @Published var contactsError: String?
    @Published var contactSearchText = ""
    @Published var selectedContact: AudienceContact?

    // MARK: - Segments
    @Published var segments: [AudienceSegment] = []
    @Published var isLoadingSegments = false
    @Published var segmentsError: String?

    // MARK: - Segment Builder
    @Published var newSegmentName = ""
    @Published var newSegmentRules: [SegmentRule] = []
    @Published var isSavingSegment = false

    // MARK: - Quick Replies
    @Published var quickReplies: [QuickReply] = QuickReply.defaults

    private let repository: CommunityRepository

    init(repository: CommunityRepository = CommunityRepositoryProvider.shared.repository) {
        self.repository = repository
        Task { await loadInbox() }
    }

    // MARK: - Filtered Messages

    var filteredMessages: [InboxMessage] {
        var result = messages
        if let platform = platformFilter {
            result = result.filter { $0.platform == platform }
        }
        return result
    }

    // MARK: - Filtered Contacts

    var filteredContacts: [AudienceContact] {
        guard !contactSearchText.isEmpty else { return contacts }
        let query = contactSearchText.lowercased()
        return contacts.filter {
            $0.name.lowercased().contains(query) ||
            ($0.email?.lowercased().contains(query) ?? false) ||
            $0.segments.contains(where: { $0.lowercased().contains(query) })
        }
    }

    // MARK: - Inbox

    @MainActor
    func loadInbox() async {
        isLoadingInbox = true
        inboxError = nil
        do {
            messages = try await repository.fetchInbox(filter: inboxFilter)
        } catch {
            inboxError = error.localizedDescription
        }
        isLoadingInbox = false
    }

    @MainActor
    func markMessageRead(_ message: InboxMessage) async {
        do {
            try await repository.markRead(messageID: message.id)
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index].isRead = true
            }
        } catch {
            inboxError = error.localizedDescription
        }
    }

    @MainActor
    func toggleMessageFlag(_ message: InboxMessage) async {
        do {
            try await repository.toggleFlag(messageID: message.id)
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index].isFlagged.toggle()
            }
        } catch {
            inboxError = error.localizedDescription
        }
    }

    @MainActor
    func sendReply(to message: InboxMessage) async {
        guard !replyText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSendingReply = true
        do {
            try await repository.sendReply(to: message.id, text: replyText)
            replyText = ""
            await markMessageRead(message)
        } catch {
            inboxError = error.localizedDescription
        }
        isSendingReply = false
    }

    func applyQuickReply(_ reply: QuickReply) {
        replyText = reply.text
    }

    // MARK: - Contacts

    @MainActor
    func loadContacts() async {
        isLoadingContacts = true
        contactsError = nil
        do {
            contacts = try await repository.fetchContacts()
        } catch {
            contactsError = error.localizedDescription
        }
        isLoadingContacts = false
    }

    // MARK: - Segments

    @MainActor
    func loadSegments() async {
        isLoadingSegments = true
        segmentsError = nil
        do {
            segments = try await repository.fetchSegments()
        } catch {
            segmentsError = error.localizedDescription
        }
        isLoadingSegments = false
    }

    @MainActor
    func saveNewSegment() async {
        guard !newSegmentName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSavingSegment = true
        let segment = AudienceSegment(name: newSegmentName, rules: newSegmentRules)
        do {
            let created = try await repository.createSegment(segment)
            segments.insert(created, at: 0)
            newSegmentName = ""
            newSegmentRules = []
        } catch {
            segmentsError = error.localizedDescription
        }
        isSavingSegment = false
    }

    @MainActor
    func deleteSegment(_ segment: AudienceSegment) async {
        do {
            try await repository.deleteSegment(id: segment.id)
            segments.removeAll { $0.id == segment.id }
        } catch {
            segmentsError = error.localizedDescription
        }
    }

    // MARK: - Segment Builder Helpers

    func addRule() {
        newSegmentRules.append(SegmentRule(field: "engagementScore", op: .greaterThan, value: ""))
    }

    func removeRule(_ rule: SegmentRule) {
        newSegmentRules.removeAll { $0.id == rule.id }
    }
}
