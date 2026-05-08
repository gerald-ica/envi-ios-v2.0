import SwiftUI
import Combine

/// ViewModel for the full content calendar.
@MainActor
final class ContentCalendarViewModel: ObservableObject {

    // MARK: - Published State

    @Published var selectedViewMode: CalendarViewMode = .month
    @Published var selectedDate: Date = Date()
    @Published var calendarSlots: [CalendarSlot] = []
    @Published var bestTimes: [BestTimeSlot] = []
    @Published var contentGaps: [ContentGap] = []
    @Published var holidays: [HolidayEvent] = []
    @Published var postingStreak: PostingStreak = .empty
    @Published var selectedPlatformFilter: SocialPlatform? = nil

    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Private

    private nonisolated(unsafe) let repository: CalendarRepository
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(repository: CalendarRepository = CalendarRepositoryProvider.shared.repository) {
        self.repository = repository
        Task { await reload() }
    }

    // MARK: - Computed

    var visibleRange: DateInterval {
        let calendar = Calendar.current
        switch selectedViewMode {
        case .day:
            let start = calendar.startOfDay(for: selectedDate)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .week:
            let weekday = calendar.component(.weekday, from: selectedDate)
            let start = calendar.date(byAdding: .day, value: -(weekday - 1), to: calendar.startOfDay(for: selectedDate)) ?? selectedDate
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .month:
            guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate) else {
                return DateInterval(start: selectedDate, end: selectedDate)
            }
            return monthInterval
        case .quarter:
            let month = calendar.component(.month, from: selectedDate)
            let quarterStart = ((month - 1) / 3) * 3 + 1
            var comps = calendar.dateComponents([.year], from: selectedDate)
            comps.month = quarterStart
            comps.day = 1
            let start = calendar.date(from: comps) ?? selectedDate
            let end = calendar.date(byAdding: .month, value: 3, to: start) ?? start
            return DateInterval(start: start, end: end)
        }
    }

    var filteredSlots: [CalendarSlot] {
        let rangeSlots = calendarSlots.filter { visibleRange.contains($0.scheduledAt) }
        guard let platform = selectedPlatformFilter else { return rangeSlots }
        return rangeSlots.filter { $0.platform == platform }
    }

    /// Slots grouped by day for month/quarter views.
    func slots(for date: Date) -> [CalendarSlot] {
        let calendar = Calendar.current
        return filteredSlots.filter { calendar.isDate($0.scheduledAt, inSameDayAs: date) }
    }

    /// Holidays falling on a specific date.
    func holiday(for date: Date) -> HolidayEvent? {
        let calendar = Calendar.current
        return holidays.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    /// Content gaps for a specific date.
    func gaps(for date: Date) -> [ContentGap] {
        let calendar = Calendar.current
        return contentGaps.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    /// Whether a given hour on a given day is an optimal posting time.
    func isOptimalHour(_ hour: Int, dayOfWeek: Int, platform: SocialPlatform? = nil) -> Bool {
        bestTimes.contains { slot in
            slot.hour == hour &&
            slot.dayOfWeek == dayOfWeek &&
            (platform == nil || slot.platform == platform)
        }
    }

    // MARK: - Actions

    @MainActor
    func reload() async {
        isLoading = true
        errorMessage = nil

        // Use a wide range to pre-fetch surrounding data
        let calendar = Calendar.current
        let wideStart = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
        let wideEnd = calendar.date(byAdding: .month, value: 2, to: selectedDate) ?? selectedDate
        let wideRange = DateInterval(start: wideStart, end: wideEnd)

        do {
            async let slotsTask = repository.fetchCalendarSlots(range: wideRange)
            async let bestTimesTask = repository.fetchBestTimes()
            async let gapsTask = repository.fetchContentGaps(range: wideRange)
            async let holidaysTask = repository.fetchHolidays(range: wideRange)
            async let streakTask = repository.fetchPostingStreak()

            let (fetchedSlots, fetchedBest, fetchedGaps, fetchedHolidays, fetchedStreak) =
                try await (slotsTask, bestTimesTask, gapsTask, holidaysTask, streakTask)

            calendarSlots = fetchedSlots
            bestTimes = fetchedBest
            contentGaps = fetchedGaps
            holidays = fetchedHolidays
            postingStreak = fetchedStreak
        } catch {
            if AppEnvironment.current == .dev {
                calendarSlots = CalendarSlot.mockSlots
                bestTimes = BestTimeSlot.mock
                contentGaps = ContentGap.mock
                holidays = HolidayEvent.mock
                postingStreak = .mock
            } else {
                errorMessage = "Unable to load calendar data."
            }
        }

        isLoading = false
    }

    @MainActor
    func rescheduleSlot(_ slot: CalendarSlot, to newDate: Date) async {
        guard let index = calendarSlots.firstIndex(where: { $0.id == slot.id }) else { return }
        let snapshot = calendarSlots

        // Optimistic update
        calendarSlots[index].scheduledAt = newDate

        do {
            try await repository.rescheduleSlot(id: slot.id, to: newDate)
        } catch {
            calendarSlots = snapshot
            errorMessage = "Could not reschedule."
        }
    }

    @MainActor
    func navigateForward() {
        let calendar = Calendar.current
        switch selectedViewMode {
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
        case .quarter:
            selectedDate = calendar.date(byAdding: .month, value: 3, to: selectedDate) ?? selectedDate
        }
        Task { await reload() }
    }

    @MainActor
    func navigateBackward() {
        let calendar = Calendar.current
        switch selectedViewMode {
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
        case .quarter:
            selectedDate = calendar.date(byAdding: .month, value: -3, to: selectedDate) ?? selectedDate
        }
        Task { await reload() }
    }

    @MainActor
    func selectViewMode(_ mode: CalendarViewMode) {
        selectedViewMode = mode
    }
}
