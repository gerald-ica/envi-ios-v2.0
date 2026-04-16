import SwiftUI

/// Sheet for creating or editing a content plan item.
struct PlanItemEditorSheet: View {
    let existingItem: ContentPlanItem?
    let onSave: (String, SocialPlatform, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var title: String = ""
    @State private var selectedPlatform: SocialPlatform = .instagram
    @State private var scheduledAt: Date = Date()

    private var isEditing: Bool { existingItem != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                    // Title
                    VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                        Text("TITLE")
                            .font(.spaceMono(11))
                            .tracking(0.88)
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))

                        TextField("Enter title", text: $title)
                            .font(.interMedium(13))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                            .padding(.horizontal, ENVISpacing.md)
                            .padding(.vertical, ENVISpacing.sm)
                            .background(ENVITheme.surfaceLow(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                    }

                    // Platform picker
                    VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                        Text("PLATFORM")
                            .font(.spaceMono(11))
                            .tracking(0.88)
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: ENVISpacing.sm) {
                                ForEach(SocialPlatform.allCases) { platform in
                                    Button {
                                        selectedPlatform = platform
                                    } label: {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(platform.brandColor)
                                                .frame(width: 8, height: 8)
                                            Text(platform.rawValue.uppercased())
                                                .font(.spaceMonoBold(11))
                                                .tracking(1.5)
                                        }
                                        .foregroundColor(chipForeground(for: platform))
                                        .padding(.horizontal, ENVISpacing.lg)
                                        .padding(.vertical, ENVISpacing.sm)
                                        .background(chipBackground(for: platform))
                                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                                                .strokeBorder(chipBorder(for: platform), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Date picker
                    VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                        Text("SCHEDULED DATE")
                            .font(.spaceMono(11))
                            .tracking(0.88)
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))

                        DatePicker(
                            "",
                            selection: $scheduledAt,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .tint(ENVITheme.text(for: colorScheme))
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
                .padding(.top, ENVISpacing.lg)
            }
            .background(ENVITheme.background(for: colorScheme))
            .navigationTitle(isEditing ? "Edit Plan Item" : "New Plan Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.interMedium(13))
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title, selectedPlatform, scheduledAt)
                        dismiss()
                    }
                    .font(.interMedium(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            if let item = existingItem {
                title = item.title
                selectedPlatform = item.platform
                scheduledAt = item.scheduledAt
            }
        }
    }

    // MARK: - Chip Styling

    private func chipForeground(for platform: SocialPlatform) -> Color {
        if selectedPlatform == platform {
            return colorScheme == .dark ? .black : .white
        }
        return ENVITheme.textLight(for: colorScheme)
    }

    private func chipBackground(for platform: SocialPlatform) -> Color {
        if selectedPlatform == platform {
            return colorScheme == .dark ? .white : .black
        }
        return .clear
    }

    private func chipBorder(for platform: SocialPlatform) -> Color {
        if selectedPlatform == platform { return .clear }
        return ENVITheme.border(for: colorScheme)
    }
}

#Preview {
    PlanItemEditorSheet(existingItem: nil) { _, _, _ in }
        .preferredColorScheme(.dark)
}
