import SwiftUI

/// Full-screen content calendar with day/week/month/quarter modes.
struct ContentCalendarFullView: View {
    @StateObject private var viewModel = ContentCalendarViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var dragTargetSlotID: UUID?
    @State private var showBestTimes = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Streak banner
                streakBanner

                // View mode chips
                viewModeSwitcher

                // Navigation header
                dateNavigationHeader

                // Platform filter
                platformFilter

                Divider()
                    .background(ENVITheme.border(for: colorScheme))

                // Calendar content
                if viewModel.isLoading {
                    ENVILoadingState()
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else {
                    calendarContent
                }
            }
            .background(ENVITheme.background(for: colorScheme))
            .navigationTitle("CALENDAR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showBestTimes = true } label: {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                    }
                }
            }
            .sheet(isPresented: $showBestTimes) {
                BestTimeView(
                    bestTimes: viewModel.bestTimes,
                    selectedPlatform: viewModel.selectedPlatformFilter
                )
            }
        }
    }

    // MARK: - Streak Banner

    private var streakBanner: some View {
        HStack(spacing: ENVISpacing.md) {
            Image(systemName: "flame.fill")
                .font(.system(size: 16))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.postingStreak.currentStreak)-DAY STREAK")
                    .font(.spaceMonoBold(12))
                    .tracking(0.88)
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                Text("Longest: \(viewModel.postingStreak.longestStreak) days")
                    .font(.interRegular(10))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
            }

            Spacer()

            Text("\(viewModel.postingStreak.targetPerWeek)/wk target")
                .font(.spaceMono(10))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
        .padding(.vertical, ENVISpacing.sm)
        .background(ENVITheme.surfaceLow(for: colorScheme))
    }

    // MARK: - View Mode Switcher

    private var viewModeSwitcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ENVISpacing.sm) {
                ForEach(CalendarViewMode.allCases) { mode in
                    ENVIChip(
                        title: mode.displayName,
                        isSelected: viewModel.selectedViewMode == mode
                    ) {
                        viewModel.selectViewMode(mode)
                    }
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
        .padding(.vertical, ENVISpacing.sm)
    }

    // MARK: - Date Navigation

    private var dateNavigationHeader: some View {
        HStack {
            Button { viewModel.navigateBackward() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
            }

            Spacer()

            Text(headerTitle)
                .font(.spaceMonoBold(14))
                .tracking(0.88)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Spacer()

            Button { viewModel.navigateForward() } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
        .padding(.vertical, ENVISpacing.sm)
    }

    private var headerTitle: String {
        let formatter = DateFormatter()
        switch viewModel.selectedViewMode {
        case .day:
            formatter.dateFormat = "EEEE, MMM d"
        case .week:
            formatter.dateFormat = "MMM d"
            let endDate = Calendar.current.date(byAdding: .day, value: 6, to: viewModel.visibleRange.start) ?? viewModel.selectedDate
            let endFormatter = DateFormatter()
            endFormatter.dateFormat = "MMM d, yyyy"
            return "\(formatter.string(from: viewModel.visibleRange.start)) - \(endFormatter.string(from: endDate))"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
        case .quarter:
            let month = Calendar.current.component(.month, from: viewModel.selectedDate)
            let quarter = ((month - 1) / 3) + 1
            let year = Calendar.current.component(.year, from: viewModel.selectedDate)
            return "Q\(quarter) \(year)"
        }
        return formatter.string(from: viewModel.selectedDate).uppercased()
    }

    // MARK: - Platform Filter

    private var platformFilter: some View {
        ENVIPlatformFilterBar(selectedPlatform: $viewModel.selectedPlatformFilter)
            .padding(.vertical, ENVISpacing.xs)
    }

    // MARK: - Calendar Content Router

    @ViewBuilder
    private var calendarContent: some View {
        switch viewModel.selectedViewMode {
        case .day:
            dayView
        case .week:
            weekView
        case .month:
            monthView
        case .quarter:
            quarterView
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: ENVISpacing.md) {
            Spacer()
            Text(message)
                .font(.interMedium(13))
                .foregroundColor(.red)
            Button("Retry") {
                Task { await viewModel.reload() }
            }
            .font(.interMedium(13))
            .foregroundColor(ENVITheme.text(for: colorScheme))
            Spacer()
        }
    }

    // MARK: - Day View

    private var dayView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<24, id: \.self) { hour in
                    dayHourRow(hour: hour)
                }
            }
            .padding(.bottom, ENVISpacing.xxxl)
        }
    }

    private func dayHourRow(hour: Int) -> some View {
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: viewModel.selectedDate)
        let slotsForHour = viewModel.filteredSlots.filter {
            calendar.component(.hour, from: $0.scheduledAt) == hour &&
            calendar.isDate($0.scheduledAt, inSameDayAs: viewModel.selectedDate)
        }
        let isOptimal = viewModel.isOptimalHour(hour, dayOfWeek: dayOfWeek, platform: viewModel.selectedPlatformFilter)

        return HStack(alignment: .top, spacing: ENVISpacing.sm) {
            // Hour label
            Text(hourLabel(hour))
                .font(.spaceMono(10))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                .frame(width: 50, alignment: .trailing)

            // Slot area
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                if slotsForHour.isEmpty {
                    // Empty slot
                    RoundedRectangle(cornerRadius: ENVIRadius.sm)
                        .fill(Color.clear)
                        .frame(height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                                .strokeBorder(
                                    isOptimal ? Color.orange.opacity(0.5) : ENVITheme.border(for: colorScheme),
                                    style: isOptimal ? StrokeStyle(lineWidth: 1, dash: [4, 3]) : StrokeStyle(lineWidth: 0.5)
                                )
                        )
                        .overlay(alignment: .topTrailing) {
                            if isOptimal {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.orange)
                                    .padding(4)
                            }
                        }
                        .onDrop(of: [.text], isTargeted: nil) { providers in
                            handleDrop(providers: providers, hour: hour)
                        }
                } else {
                    ForEach(slotsForHour) { slot in
                        slotCard(slot)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, ENVISpacing.xl)
        .padding(.vertical, ENVISpacing.xs)
        .background(holidayBackground(for: viewModel.selectedDate))
    }

    // MARK: - Week View

    private var weekView: some View {
        let calendar = Calendar.current
        let weekStart = viewModel.visibleRange.start
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }

        return ScrollView {
            VStack(spacing: 0) {
                // Day headers
                HStack(spacing: 0) {
                    // Hour column spacer
                    Color.clear.frame(width: 44)

                    ForEach(days, id: \.self) { day in
                        VStack(spacing: 2) {
                            Text(dayAbbreviation(day))
                                .font(.spaceMono(9))
                                .tracking(0.5)
                                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                            Text("\(calendar.component(.day, from: day))")
                                .font(.interMedium(12))
                                .foregroundColor(
                                    calendar.isDateInToday(day)
                                        ? ENVITheme.text(for: colorScheme)
                                        : ENVITheme.textLight(for: colorScheme)
                                )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ENVISpacing.xs)
                        .background(
                            calendar.isDateInToday(day)
                                ? ENVITheme.surfaceLow(for: colorScheme)
                                : Color.clear
                        )
                    }
                }
                .padding(.horizontal, ENVISpacing.sm)

                Divider().background(ENVITheme.border(for: colorScheme))

                // Time grid
                ForEach([6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22], id: \.self) { hour in
                    HStack(alignment: .top, spacing: 0) {
                        Text(hourLabel(hour))
                            .font(.spaceMono(8))
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                            .frame(width: 44, alignment: .trailing)
                            .padding(.trailing, 4)

                        ForEach(days, id: \.self) { day in
                            let slotsHere = viewModel.filteredSlots.filter {
                                calendar.isDate($0.scheduledAt, inSameDayAs: day) &&
                                calendar.component(.hour, from: $0.scheduledAt) == hour
                            }
                            let weekday = calendar.component(.weekday, from: day)
                            let isOptimal = viewModel.isOptimalHour(hour, dayOfWeek: weekday, platform: viewModel.selectedPlatformFilter)

                            VStack(spacing: 1) {
                                if slotsHere.isEmpty {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.clear)
                                        .frame(height: 28)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .strokeBorder(
                                                    isOptimal ? Color.orange.opacity(0.4) : ENVITheme.border(for: colorScheme).opacity(0.3),
                                                    style: isOptimal ? StrokeStyle(lineWidth: 1, dash: [3, 2]) : StrokeStyle(lineWidth: 0.5)
                                                )
                                        )
                                        .overlay {
                                            if isOptimal {
                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 6))
                                                    .foregroundColor(.orange.opacity(0.6))
                                            }
                                        }
                                } else {
                                    ForEach(slotsHere) { slot in
                                        weekSlotPill(slot)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 1)
                        }
                    }
                    .padding(.horizontal, ENVISpacing.sm)
                    .padding(.vertical, 1)
                }
            }
            .padding(.bottom, ENVISpacing.xxxl)
        }
    }

    private func weekSlotPill(_ slot: CalendarSlot) -> some View {
        HStack(spacing: 2) {
            Circle()
                .fill(slot.platform.brandColor)
                .frame(width: 4, height: 4)
            Text(slot.title.prefix(6))
                .font(.interRegular(7))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .lineLimit(1)
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(slot.platform.brandColor.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Month View

    private var monthView: some View {
        let monthDates = generateMonthDates()

        return ScrollView {
            VStack(spacing: ENVISpacing.xs) {
                // Weekday headers
                HStack(spacing: 0) {
                    ForEach(["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"], id: \.self) { day in
                        Text(day)
                            .font(.spaceMono(9))
                            .tracking(0.5)
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, ENVISpacing.md)

                // Month grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                    ForEach(monthDates, id: \.self) { date in
                        if let date = date {
                            monthDayCell(date)
                        } else {
                            Color.clear.frame(height: 72)
                        }
                    }
                }
                .padding(.horizontal, ENVISpacing.md)

                // Legend
                calendarLegend
                    .padding(.top, ENVISpacing.md)
            }
            .padding(.bottom, ENVISpacing.xxxl)
        }
    }

    private func monthDayCell(_ date: Date) -> some View {
        let calendar = Calendar.current
        let daySlots = viewModel.slots(for: date)
        let dayGaps = viewModel.gaps(for: date)
        let dayHoliday = viewModel.holiday(for: date)
        let isToday = calendar.isDateInToday(date)
        let isCurrentMonth = calendar.isDate(date, equalTo: viewModel.selectedDate, toGranularity: .month)

        return VStack(spacing: 2) {
            // Day number
            Text("\(calendar.component(.day, from: date))")
                .font(.interMedium(11))
                .foregroundColor(
                    isToday ? (colorScheme == .dark ? .black : .white) :
                    isCurrentMonth ? ENVITheme.text(for: colorScheme) :
                    ENVITheme.textLight(for: colorScheme).opacity(0.4)
                )
                .frame(width: 20, height: 20)
                .background(isToday ? ENVITheme.text(for: colorScheme) : Color.clear)
                .clipShape(Circle())

            // Platform dots
            if !daySlots.isEmpty {
                HStack(spacing: 2) {
                    ForEach(Array(Set(daySlots.map(\.platform))).prefix(3), id: \.self) { platform in
                        Circle()
                            .fill(platform.brandColor)
                            .frame(width: 5, height: 5)
                    }
                }
            }

            // Holiday label
            if let holiday = dayHoliday {
                Text(holiday.name.prefix(8))
                    .font(.interRegular(7))
                    .foregroundColor(.purple)
                    .lineLimit(1)
            }

            // Gap warning
            if !dayGaps.isEmpty && daySlots.isEmpty {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 8))
                    .foregroundColor(.orange)
            }

            Spacer(minLength: 0)
        }
        .frame(height: 72)
        .frame(maxWidth: .infinity)
        .background(
            dayHoliday != nil
                ? Color.purple.opacity(0.05)
                : Color.clear
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(
                    !dayGaps.isEmpty && daySlots.isEmpty
                        ? Color.orange.opacity(0.4)
                        : Color.clear,
                    style: StrokeStyle(lineWidth: 1, dash: [3, 2])
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Quarter View

    private var quarterView: some View {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: viewModel.selectedDate)
        let quarterStartMonth = ((month - 1) / 3) * 3 + 1
        var comps = calendar.dateComponents([.year], from: viewModel.selectedDate)

        return ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.lg) {
                ForEach(0..<3, id: \.self) { offset in
                    let monthNum = quarterStartMonth + offset
                    let _ = { comps.month = monthNum; comps.day = 1 }()

                    if let monthDate = calendar.date(from: DateComponents(year: comps.year, month: monthNum, day: 1)) {
                        quarterMonthSection(monthDate)
                    }
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
            .padding(.bottom, ENVISpacing.xxxl)
        }
    }

    private func quarterMonthSection(_ monthDate: Date) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else {
            return AnyView(EmptyView())
        }
        let slotsInMonth = viewModel.filteredSlots.filter { monthInterval.contains($0.scheduledAt) }
        let grouped = Dictionary(grouping: slotsInMonth) { slot in
            calendar.startOfDay(for: slot.scheduledAt)
        }

        return AnyView(
            VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                Text(formatter.string(from: monthDate).uppercased())
                    .font(.spaceMonoBold(11))
                    .tracking(0.88)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                if slotsInMonth.isEmpty {
                    Text("No content scheduled")
                        .font(.interRegular(11))
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                        .padding(.vertical, ENVISpacing.sm)
                } else {
                    ForEach(grouped.keys.sorted(), id: \.self) { day in
                        if let daySlots = grouped[day] {
                            HStack(spacing: ENVISpacing.sm) {
                                Text("\(calendar.component(.day, from: day))")
                                    .font(.spaceMono(10))
                                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
                                    .frame(width: 24)

                                ForEach(daySlots) { slot in
                                    HStack(spacing: 3) {
                                        Circle()
                                            .fill(slot.platform.brandColor)
                                            .frame(width: 5, height: 5)
                                        Text(slot.title.prefix(12))
                                            .font(.interRegular(10))
                                            .foregroundColor(ENVITheme.text(for: colorScheme))
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, ENVISpacing.sm)
                                    .padding(.vertical, 3)
                                    .background(slot.platform.brandColor.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                                }
                            }
                        }
                    }
                }

                Divider().background(ENVITheme.border(for: colorScheme))
            }
        )
    }

    // MARK: - Slot Card (Day View)

    private func slotCard(_ slot: CalendarSlot) -> some View {
        HStack(spacing: ENVISpacing.sm) {
            Circle()
                .fill(slot.platform.brandColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(slot.title)
                    .font(.interMedium(12))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .lineLimit(1)
                Text(slot.platform.rawValue)
                    .font(.interRegular(10))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
            }

            Spacer()

            if slot.isOptimalTime {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }

            statusBadge(slot.status)
        }
        .padding(ENVISpacing.sm)
        .background(
            campaignBackground(slot)
        )
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 0.5)
        )
        .onDrag {
            NSItemProvider(object: slot.id.uuidString as NSString)
        }
    }

    // MARK: - Helpers

    private func statusBadge(_ status: ContentPlanItem.Status) -> some View {
        ENVIStatusBadge(text: status.rawValue, color: statusColor(for: status))
    }

    private func statusColor(for status: ContentPlanItem.Status) -> Color {
        switch status {
        case .draft: return ENVITheme.textLight(for: colorScheme)
        case .ready: return ENVITheme.success
        case .scheduled: return ENVITheme.info
        }
    }

    private func campaignBackground(_ slot: CalendarSlot) -> Color {
        if let hex = slot.campaignColor {
            return Color(hex: hex).opacity(0.08)
        }
        return ENVITheme.surfaceLow(for: colorScheme)
    }

    private func holidayBackground(for date: Date) -> Color {
        viewModel.holiday(for: date) != nil
            ? Color.purple.opacity(0.04)
            : Color.clear
    }

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "AM" : "PM"
        return "\(h) \(suffix)"
    }

    private func dayAbbreviation(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private func generateMonthDates() -> [Date?] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: viewModel.selectedDate) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let daysInMonth = calendar.range(of: .day, in: .month, for: viewModel.selectedDate)?.count ?? 30

        var dates: [Date?] = []

        // Leading empty cells
        for _ in 0..<(firstWeekday - 1) {
            dates.append(nil)
        }

        // Day cells
        for day in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: monthInterval.start) {
                dates.append(date)
            }
        }

        return dates
    }

    private func handleDrop(providers: [NSItemProvider], hour: Int) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let idString = object as? String,
                  let slotID = UUID(uuidString: idString),
                  let slot = self.viewModel.calendarSlots.first(where: { $0.id == slotID }) else { return }

            let calendar = Calendar.current
            var comps = calendar.dateComponents([.year, .month, .day], from: self.viewModel.selectedDate)
            comps.hour = hour
            comps.minute = 0

            if let newDate = calendar.date(from: comps) {
                Task { @MainActor in
                    await self.viewModel.rescheduleSlot(slot, to: newDate)
                }
            }
        }
        return true
    }

    // MARK: - Legend

    private var calendarLegend: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text("LEGEND")
                .font(.spaceMono(9))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            HStack(spacing: ENVISpacing.lg) {
                legendItem(icon: "star.fill", color: .orange, label: "Best time")
                legendItem(icon: "exclamationmark.circle", color: .orange, label: "Content gap")
                legendItem(icon: "calendar", color: .purple, label: "Holiday")
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func legendItem(icon: String, color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color)
            Text(label)
                .font(.interRegular(10))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))
        }
    }
}

#Preview {
    ContentCalendarFullView()
        .preferredColorScheme(.dark)
}
