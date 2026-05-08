import Foundation

// MARK: - Protocol

protocol CalendarRepository {
    func fetchCalendarSlots(range: DateInterval) async throws -> [CalendarSlot]
    func rescheduleSlot(id: UUID, to newDate: Date) async throws
    func fetchBestTimes() async throws -> [BestTimeSlot]
    func fetchContentGaps(range: DateInterval) async throws -> [ContentGap]
    func fetchHolidays(range: DateInterval) async throws -> [HolidayEvent]
    func fetchPostingStreak() async throws -> PostingStreak
}

// MARK: - Mock

final class MockCalendarRepository: CalendarRepository {
    private var slots: [CalendarSlot] = CalendarSlot.mockSlots

    func fetchCalendarSlots(range: DateInterval) async throws -> [CalendarSlot] {
        slots.filter { range.contains($0.scheduledAt) }
    }

    func rescheduleSlot(id: UUID, to newDate: Date) async throws {
        guard let index = slots.firstIndex(where: { $0.id == id }) else {
            throw NSError(
                domain: "MockCalendarRepository",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Slot not found."]
            )
        }
        slots[index].scheduledAt = newDate
    }

    func fetchBestTimes() async throws -> [BestTimeSlot] {
        BestTimeSlot.mock
    }

    func fetchContentGaps(range: DateInterval) async throws -> [ContentGap] {
        ContentGap.mock.filter { range.contains($0.date) }
    }

    func fetchHolidays(range: DateInterval) async throws -> [HolidayEvent] {
        HolidayEvent.mock.filter { range.contains($0.date) }
    }

    func fetchPostingStreak() async throws -> PostingStreak {
        .mock
    }
}

// MARK: - API

final class APICalendarRepository: CalendarRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchCalendarSlots(range: DateInterval) async throws -> [CalendarSlot] {
        let iso = ISO8601DateFormatter()
        let response: [CalendarSlotResponse] = try await apiClient.request(
            endpoint: "planning/calendar?start=\(iso.string(from: range.start))&end=\(iso.string(from: range.end))",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }

    func rescheduleSlot(id: UUID, to newDate: Date) async throws {
        let body = RescheduleBody(scheduledAt: ISO8601DateFormatter().string(from: newDate))
        try await apiClient.requestVoid(
            endpoint: "planning/calendar/\(id.uuidString)/reschedule",
            method: .patch,
            body: body,
            requiresAuth: true
        )
    }

    func fetchBestTimes() async throws -> [BestTimeSlot] {
        try await apiClient.request(
            endpoint: "planning/best-times",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchContentGaps(range: DateInterval) async throws -> [ContentGap] {
        let iso = ISO8601DateFormatter()
        let response: [ContentGapResponse] = try await apiClient.request(
            endpoint: "planning/gaps?start=\(iso.string(from: range.start))&end=\(iso.string(from: range.end))",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }

    func fetchHolidays(range: DateInterval) async throws -> [HolidayEvent] {
        let iso = ISO8601DateFormatter()
        let response: [HolidayEventResponse] = try await apiClient.request(
            endpoint: "planning/holidays?start=\(iso.string(from: range.start))&end=\(iso.string(from: range.end))",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }

    func fetchPostingStreak() async throws -> PostingStreak {
        try await apiClient.request(
            endpoint: "planning/streak",
            method: .get,
            requiresAuth: true
        )
    }
}

// MARK: - Provider

@MainActor
enum CalendarRepositoryProvider {
    static nonisolated(unsafe) var shared = RepositoryProvider<CalendarRepository>(
        dev: MockCalendarRepository(),
        api: APICalendarRepository()
    )
}

// MARK: - API Response Models

private struct RescheduleBody: Encodable {
    let scheduledAt: String
}

private struct CalendarSlotResponse: Decodable {
    let id: String?
    let planItemID: String?
    let platform: String
    let scheduledAt: String
    let status: String
    let campaignColor: String?
    let isOptimalTime: Bool?
    let title: String?

    func toDomain() -> CalendarSlot {
        CalendarSlot(
            id: UUID(uuidString: id ?? "") ?? UUID(),
            planItemID: planItemID.flatMap { UUID(uuidString: $0) },
            platform: SocialPlatform(rawValue: platform) ?? .instagram,
            scheduledAt: ISO8601DateFormatter().date(from: scheduledAt) ?? Date(),
            status: ContentPlanItem.Status(rawValue: status) ?? .draft,
            campaignColor: campaignColor,
            isOptimalTime: isOptimalTime ?? false,
            title: title ?? ""
        )
    }
}

private struct ContentGapResponse: Decodable {
    let id: String?
    let date: String
    let platform: String
    let suggestion: String

    func toDomain() -> ContentGap {
        ContentGap(
            id: UUID(uuidString: id ?? "") ?? UUID(),
            date: ISO8601DateFormatter().date(from: date) ?? Date(),
            platform: SocialPlatform(rawValue: platform) ?? .instagram,
            suggestion: suggestion
        )
    }
}

private struct HolidayEventResponse: Decodable {
    let id: String?
    let name: String
    let date: String
    let relevanceScore: Double?

    func toDomain() -> HolidayEvent {
        HolidayEvent(
            id: UUID(uuidString: id ?? "") ?? UUID(),
            name: name,
            date: ISO8601DateFormatter().date(from: date) ?? Date(),
            relevanceScore: relevanceScore ?? 0.5
        )
    }
}
