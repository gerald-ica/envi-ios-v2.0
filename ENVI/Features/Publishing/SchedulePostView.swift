import SwiftUI

/// Create or edit a scheduled post: caption, platforms, date/time, recurring, media, approval.
struct SchedulePostView: View {
    @ObservedObject var viewModel: SchedulingViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var editingPost: ScheduledPost?

    @State private var caption: String = ""
    @State private var selectedPlatforms: Set<SocialPlatform> = []
    @State private var scheduledAt: Date = Date().addingTimeInterval(3600)
    @State private var mediaAssetIDs: [String] = []
    @State private var isRecurring: Bool = false
    @State private var recurringFrequency: RecurringFrequency = .weekly
    @State private var recurringDayOfWeek: Int = 2
    @State private var recurringHour: Int = 10
    @State private var isSaving: Bool = false

    private var isEditing: Bool { editingPost != nil }

    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    init(viewModel: SchedulingViewModel, editingPost: ScheduledPost? = nil) {
        self.viewModel = viewModel
        self.editingPost = editingPost

        if let post = editingPost {
            _caption = State(initialValue: post.caption)
            _selectedPlatforms = State(initialValue: Set(post.platforms))
            _scheduledAt = State(initialValue: post.scheduledAt)
            _mediaAssetIDs = State(initialValue: post.mediaAssetIDs)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                    captionSection
                    platformSection
                    scheduleSection
                    recurringSection
                    mediaSection

                    if let post = editingPost {
                        approvalSection(post)
                    }
                }
                .padding(ENVISpacing.lg)
            }
            .background(ENVITheme.background(for: colorScheme))
            .navigationTitle(isEditing ? "EDIT POST" : "SCHEDULE POST")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Text("Cancel")
                            .font(.interMedium(14))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        Text(isEditing ? "Update" : "Schedule")
                            .font(.interSemiBold(14))
                            .foregroundColor(
                                canSave
                                    ? ENVITheme.text(for: colorScheme)
                                    : ENVITheme.textSecondary(for: colorScheme)
                            )
                    }
                    .disabled(!canSave || isSaving)
                }
            }
        }
    }

    // MARK: - Caption

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            sectionHeader("CAPTION")

            TextEditor(text: $caption)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100)
                .padding(ENVISpacing.md)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))

            HStack {
                Spacer()
                Text("\(caption.count) characters")
                    .font(.interRegular(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
        }
    }

    // MARK: - Platforms

    private var platformSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            sectionHeader("PLATFORMS")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: ENVISpacing.sm)], spacing: ENVISpacing.sm) {
                ForEach(SocialPlatform.allCases) { platform in
                    platformChip(platform)
                }
            }
        }
    }

    private func platformChip(_ platform: SocialPlatform) -> some View {
        let isSelected = selectedPlatforms.contains(platform)
        return Button {
            if isSelected {
                selectedPlatforms.remove(platform)
            } else {
                selectedPlatforms.insert(platform)
            }
        } label: {
            HStack(spacing: ENVISpacing.xs) {
                Image(systemName: platform.iconName)
                    .font(.system(size: 12))
                Text(platform.rawValue)
                    .font(.interMedium(12))
            }
            .foregroundColor(
                isSelected
                    ? (colorScheme == .dark ? .black : .white)
                    : ENVITheme.text(for: colorScheme)
            )
            .padding(.horizontal, ENVISpacing.md)
            .padding(.vertical, ENVISpacing.sm)
            .background(
                isSelected
                    ? ENVITheme.text(for: colorScheme)
                    : ENVITheme.surfaceLow(for: colorScheme)
            )
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
        }
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            sectionHeader("DATE & TIME")

            DatePicker(
                "Schedule for",
                selection: $scheduledAt,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(.interRegular(14))
            .foregroundColor(ENVITheme.text(for: colorScheme))
            .tint(ENVITheme.accent(for: colorScheme))
            .padding(ENVISpacing.md)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
        }
    }

    // MARK: - Recurring

    private var recurringSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            sectionHeader("RECURRING")

            Toggle(isOn: $isRecurring) {
                Text("Repeat this post")
                    .font(.interRegular(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
            }
            .tint(ENVITheme.accent(for: colorScheme))
            .padding(ENVISpacing.md)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))

            if isRecurring {
                VStack(spacing: ENVISpacing.md) {
                    // Frequency picker
                    HStack {
                        Text("Frequency")
                            .font(.interRegular(14))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                        Spacer()
                        Picker("Frequency", selection: $recurringFrequency) {
                            ForEach(RecurringFrequency.allCases, id: \.self) { freq in
                                Text(freq.displayName).tag(freq)
                            }
                        }
                        .tint(ENVITheme.text(for: colorScheme))
                    }

                    // Day of week
                    if recurringFrequency != .daily {
                        HStack {
                            Text("Day")
                                .font(.interRegular(14))
                                .foregroundColor(ENVITheme.text(for: colorScheme))
                            Spacer()
                            Picker("Day", selection: $recurringDayOfWeek) {
                                ForEach(0..<7, id: \.self) { day in
                                    Text(dayNames[day]).tag(day)
                                }
                            }
                            .tint(ENVITheme.text(for: colorScheme))
                        }
                    }

                    // Hour
                    HStack {
                        Text("Time")
                            .font(.interRegular(14))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                        Spacer()
                        Picker("Hour", selection: $recurringHour) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(hourLabel(hour)).tag(hour)
                            }
                        }
                        .tint(ENVITheme.text(for: colorScheme))
                    }
                }
                .padding(ENVISpacing.md)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
            }
        }
    }

    // MARK: - Media

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            sectionHeader("MEDIA")

            if mediaAssetIDs.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: ENVISpacing.sm) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 24))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                        Text("No media attached")
                            .font(.interRegular(13))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }
                    .padding(.vertical, ENVISpacing.xxl)
                    Spacer()
                }
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ENVISpacing.sm) {
                        ForEach(mediaAssetIDs, id: \.self) { assetID in
                            mediaThumbnail(assetID)
                        }
                    }
                }
            }
        }
    }

    private func mediaThumbnail(_ assetID: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: ENVIRadius.md)
                .fill(ENVITheme.surfaceHigh(for: colorScheme))

            Image(systemName: "photo")
                .font(.system(size: 20))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(width: 80, height: 80)
        .overlay(alignment: .topTrailing) {
            Button {
                mediaAssetIDs.removeAll { $0 == assetID }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
            .offset(x: 4, y: -4)
        }
    }

    // MARK: - Approval

    private func approvalSection(_ post: ScheduledPost) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            sectionHeader("APPROVAL")

            HStack {
                Circle()
                    .fill(approvalColor(post.approvalStatus))
                    .frame(width: 8, height: 8)

                Text(post.approvalStatus.displayName)
                    .font(.interMedium(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                if post.approvalStatus == .rejected {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 14))
                        .foregroundColor(ENVITheme.error)
                }
            }
            .padding(ENVISpacing.md)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
        }
    }

    // MARK: - Helpers

    private var canSave: Bool {
        !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !selectedPlatforms.isEmpty
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.spaceMono(11))
            .tracking(0.88)
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
    }

    private func hourLabel(_ hour: Int) -> String {
        let period = hour < 12 ? "AM" : "PM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour):00 \(period)"
    }

    private func approvalColor(_ status: ApprovalStatus) -> Color {
        switch status {
        case .notRequired: return ENVITheme.textSecondary(for: colorScheme)
        case .pending:     return ENVITheme.warning
        case .approved:    return ENVITheme.success
        case .rejected:    return ENVITheme.error
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        if var existing = editingPost {
            existing.caption = caption
            existing.platforms = Array(selectedPlatforms)
            existing.scheduledAt = scheduledAt
            existing.mediaAssetIDs = mediaAssetIDs
            await viewModel.updatePost(existing)
        } else {
            let post = ScheduledPost(
                caption: caption,
                platforms: Array(selectedPlatforms),
                scheduledAt: scheduledAt,
                mediaAssetIDs: mediaAssetIDs
            )
            await viewModel.createPost(post)
        }

        // Create recurring schedule if toggled
        if isRecurring {
            let schedule = RecurringSchedule(
                frequency: recurringFrequency,
                dayOfWeek: recurringDayOfWeek,
                hour: recurringHour,
                platforms: Array(selectedPlatforms)
            )
            await viewModel.createRecurring(schedule)
        }

        dismiss()
    }
}

#Preview {
    SchedulePostView(viewModel: SchedulingViewModel())
        .preferredColorScheme(.dark)
}
