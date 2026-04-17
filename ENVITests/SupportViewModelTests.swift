//
//  SupportViewModelTests.swift
//  ENVITests
//
//  Phase 17 — Plan 02. Pins the contract that SupportViewModel no longer
//  defaults to `SupportTicket.mockList` / `FAQArticle.mockList` and that
//  it surfaces an error rather than silently falling back to mocks.
//

import XCTest
@testable import ENVI

@MainActor
final class SupportViewModelTests: XCTestCase {

    // MARK: - Test Doubles

    final class StubRepository: SupportRepository {
        var tickets: [SupportTicket] = []
        var faqs: [FAQArticle] = []
        var health: HealthScore = .mock
        var shouldThrow: Bool = false

        struct BoomError: Error {}

        func fetchTickets() async throws -> [SupportTicket] {
            if shouldThrow { throw BoomError() }
            return tickets
        }

        func fetchTicket(id: UUID) async throws -> SupportTicket {
            if shouldThrow { throw BoomError() }
            guard let t = tickets.first(where: { $0.id == id }) else {
                throw SupportError.notFound
            }
            return t
        }

        func createTicket(subject: String, description: String, priority: TicketPriority) async throws -> SupportTicket {
            if shouldThrow { throw BoomError() }
            let t = SupportTicket(subject: subject, description: description, priority: priority)
            tickets.insert(t, at: 0)
            return t
        }

        func replyToTicket(id: UUID, text: String) async throws -> TicketMessage {
            if shouldThrow { throw BoomError() }
            return TicketMessage(senderName: "You", text: text)
        }

        func fetchFAQs() async throws -> [FAQArticle] {
            if shouldThrow { throw BoomError() }
            return faqs
        }

        func markHelpful(articleID: UUID) async throws {
            if shouldThrow { throw BoomError() }
        }

        func fetchHealthScore() async throws -> HealthScore {
            if shouldThrow { throw BoomError() }
            return health
        }
    }

    // MARK: - Tests

    func testDefaultStateIsEmpty() {
        let vm = SupportViewModel(repository: StubRepository())
        XCTAssertTrue(vm.tickets.isEmpty, "SupportViewModel should start with no tickets.")
        XCTAssertTrue(vm.faqs.isEmpty, "SupportViewModel should start with no FAQs.")
        XCTAssertNil(vm.healthScore, "SupportViewModel should start with nil health score.")
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    func testLoadSupportCenterPopulatesFromRepo() async {
        let repo = StubRepository()
        repo.tickets = SupportTicket.mockList
        repo.faqs = FAQArticle.mockList

        let vm = SupportViewModel(repository: repo)
        await vm.loadSupportCenter()

        XCTAssertEqual(vm.tickets.count, SupportTicket.mockList.count)
        XCTAssertEqual(vm.faqs.count, FAQArticle.mockList.count)
        XCTAssertNotNil(vm.healthScore)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    func testLoadSupportCenterErrorSetsErrorMessage() async {
        let repo = StubRepository()
        repo.shouldThrow = true

        let vm = SupportViewModel(repository: repo)
        await vm.loadSupportCenter()

        XCTAssertNotNil(vm.errorMessage, "Repo failure must surface as errorMessage.")
        XCTAssertFalse(vm.isLoading)
        XCTAssertTrue(vm.tickets.isEmpty, "Tickets must stay empty on error, not fall back to mocks.")
        XCTAssertTrue(vm.faqs.isEmpty)
        XCTAssertNil(vm.healthScore)
    }
}
