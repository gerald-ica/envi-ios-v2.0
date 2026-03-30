import SwiftUI

/// Month calendar view showing content activity with colored dots.
struct ContentCalendarView: View {
    let days: [AnalyticsData.CalendarDay]
    @Environment(\.colorScheme) private var colorScheme

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let dayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    /// Formatted month/year header derived from the calendar days.
    private var monthYearHeader: String {
        guard let firstDate = days.first?.date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: firstDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("CONTENT CALENDAR")
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            // Month/year header
            Text(monthYearHeader)
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            // Day of week headers
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(dayLabels, id: \.self) { day in
                    Text(day)
                        .font(.spaceMono(10))
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                }
            }

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(days) { day in
                    VStack(spacing: 2) {
                        let dayNum = Calendar.current.component(.day, from: day.date)
                        Text("\(dayNum)")
                            .font(.interRegular(13))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                            .frame(width: 32, height: 32)
                            .background(
                                day.hasContent
                                    ? ENVITheme.surfaceHigh(for: colorScheme)
                                    : .clear
                            )
                            .clipShape(Circle())

                        if day.hasContent, let platform = day.platform {
                            Circle()
                                .fill(platform.brandColor)
                                .frame(width: 5, height: 5)
                        } else {
                            Spacer().frame(height: 5)
                        }
                    }
                }
            }
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }
}
