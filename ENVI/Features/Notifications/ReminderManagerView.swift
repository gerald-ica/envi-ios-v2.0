import SwiftUI

/// Reminder list with frequency / time / day pickers and toggle on/off.
struct ReminderManagerView: View {

    @ObservedObject var viewModel: NotificationViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var showingAddSheet = false
    @State private var newTitle: String = ""
    @State private var newFrequency: ReminderFrequency = .daily
    @State private var newTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var newDays: Set<Int> = []

    private let dayLabels: [(Int, String)] = [
        (1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"),
        (5, "Thu"), (6, "Fri"), (7, "Sat"),
    ]

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                header

                if viewModel.isLoadingReminders {
                    HStack {
                        ProgressView()
                        Text("Loading reminders...")
                            .font(.interRegular(13))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }
                    .padding(.horizontal, ENVISpacing.xl)
                } else if viewModel.reminders.isEmpty {
                    emptyState
                } else {
                    reminderList
                }
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .sheet(isPresented: $showingAddSheet) { addSheet }
        .task { await viewModel.loadReminders() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("REMINDERS")
                .font(.spaceMonoBold(18))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Spacer()

            Button {
                resetForm()
                showingAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .frame(width: 36, height: 36)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - List

    private var reminderList: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.reminders.enumerated()), id: \.element.id) { index, reminder in
                reminderRow(reminder)

                if index < viewModel.reminders.count - 1 {
                    Divider()
                        .background(ENVITheme.border(for: colorScheme))
                        .padding(.horizontal, ENVISpacing.md)
                }
            }
        }
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func reminderRow(_ reminder: ReminderSchedule) -> some View {
        HStack(spacing: ENVISpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.interMedium(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                HStack(spacing: ENVISpacing.xs) {
                    Text(reminder.frequency.displayName)
                        .font(.interRegular(12))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    Text("at \(timeFormatter.string(from: reminder.time))")
                        .font(.interRegular(12))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    if !reminder.daysOfWeek.isEmpty {
                        Text(daysSummary(reminder.daysOfWeek))
                            .font(.interRegular(11))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                            .padding(.horizontal, ENVISpacing.xs)
                            .padding(.vertical, 2)
                            .background(ENVITheme.surfaceHigh(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                    }
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { reminder.isEnabled },
                set: { _ in viewModel.toggleReminder(reminder) }
            ))
            .labelsHidden()
            .tint(ENVITheme.text(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.md)
        .padding(.vertical, ENVISpacing.md)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                viewModel.deleteReminder(reminder)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Add Sheet

    private var addSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                    // Title
                    fieldSection(title: "REMINDER TITLE") {
                        TextField("e.g. Plan weekly content", text: $newTitle)
                            .font(.interRegular(15))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                            .padding(ENVISpacing.md)
                            .background(ENVITheme.surfaceLow(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                    }

                    // Frequency
                    fieldSection(title: "FREQUENCY") {
                        VStack(spacing: ENVISpacing.sm) {
                            ForEach(ReminderFrequency.allCases) { freq in
                                Button {
                                    newFrequency = freq
                                } label: {
                                    HStack {
                                        Text(freq.displayName)
                                            .font(.interRegular(14))
                                            .foregroundColor(ENVITheme.text(for: colorScheme))
                                        Spacer()
                                        if newFrequency == freq {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(ENVITheme.text(for: colorScheme))
                                        }
                                    }
                                    .padding(ENVISpacing.md)
                                    .background(
                                        newFrequency == freq
                                            ? ENVITheme.surfaceHigh(for: colorScheme)
                                            : ENVITheme.surfaceLow(for: colorScheme)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                                }
                            }
                        }
                    }

                    // Time
                    fieldSection(title: "TIME") {
                        DatePicker(
                            "Reminder time",
                            selection: $newTime,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .datePickerStyle(.wheel)
                        .frame(maxHeight: 120)
                        .clipped()
                    }

                    // Days of week
                    fieldSection(title: "DAYS (OPTIONAL)") {
                        HStack(spacing: ENVISpacing.sm) {
                            ForEach(dayLabels, id: \.0) { day, label in
                                Button {
                                    if newDays.contains(day) {
                                        newDays.remove(day)
                                    } else {
                                        newDays.insert(day)
                                    }
                                } label: {
                                    Text(label)
                                        .font(.spaceMonoBold(11))
                                        .foregroundColor(
                                            newDays.contains(day)
                                                ? ENVITheme.background(for: colorScheme)
                                                : ENVITheme.text(for: colorScheme)
                                        )
                                        .frame(width: 38, height: 38)
                                        .background(
                                            newDays.contains(day)
                                                ? ENVITheme.text(for: colorScheme)
                                                : ENVITheme.surfaceLow(for: colorScheme)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, ENVISpacing.xl)
                .padding(.horizontal, ENVISpacing.xl)
            }
            .background(ENVITheme.background(for: colorScheme))
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAddSheet = false }
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveReminder() }
                        .font(.interSemiBold(15))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: ENVISpacing.md) {
            Image(systemName: "clock")
                .font(.system(size: 32))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("No reminders yet")
                .font(.interMedium(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Set up recurring reminders to stay on top of your content schedule.")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ENVISpacing.xxxxl)
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Helpers

    private func fieldSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text(title)
                .font(.spaceMonoBold(11))
                .tracking(1)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            content()
        }
    }

    private func resetForm() {
        newTitle = ""
        newFrequency = .daily
        newTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
        newDays = []
    }

    private func saveReminder() {
        let reminder = ReminderSchedule(
            title: newTitle.trimmingCharacters(in: .whitespaces),
            frequency: newFrequency,
            time: newTime,
            daysOfWeek: Array(newDays).sorted()
        )
        Task {
            await viewModel.createReminder(reminder)
            showingAddSheet = false
        }
    }

    private func daysSummary(_ days: [Int]) -> String {
        let map = [1: "Su", 2: "Mo", 3: "Tu", 4: "We", 5: "Th", 6: "Fr", 7: "Sa"]
        return days.compactMap { map[$0] }.joined(separator: ", ")
    }
}
