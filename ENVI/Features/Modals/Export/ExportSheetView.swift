import SwiftUI
import UIKit

/// Export sheet presented from the editor.
struct ExportSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let composer: ExportComposer
    @State private var caption: String
    @State private var selectedRatio: String
    @State private var quality: Double
    @State private var selectedPlatforms: Set<SocialPlatform>
    @State private var isExporting = false
    @State private var isPublishing = false
    @State private var showShareSheet = false
    @State private var copyFeedback = "Copy"
    @State private var captionOptionIndex = 0
    @State private var publishStatusMessage: String?
    @State private var publishMode: PublishMode = .now
    @State private var scheduledAt = Date().addingTimeInterval(60 * 60)

    private let ratios = ["9:16", "1:1", "16:9", "4:5"]

    init(composer: ExportComposer = .preview) {
        self.composer = composer
        _caption = State(initialValue: composer.initialCaption)
        _selectedRatio = State(initialValue: composer.initialRatio)
        _quality = State(initialValue: composer.initialQuality)
        _selectedPlatforms = State(initialValue: Set(composer.preferredPlatforms))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                    // AI Caption
                    VStack(alignment: .leading, spacing: ENVISpacing.md) {
                        HStack {
                            Text("AI CAPTION")
                                .font(.spaceMono(11))
                                .tracking(0.88)
                                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                            Spacer()
                            Button("Regenerate") {
                                regenerateCaption()
                            }
                                .font(.interMedium(12))
                                .foregroundColor(ENVITheme.text(for: colorScheme))
                            Button(copyFeedback) {
                                copyCaption()
                            }
                                .font(.interMedium(12))
                                .foregroundColor(ENVITheme.text(for: colorScheme))
                        }

                        TextEditor(text: $caption)
                            .font(.interRegular(14))
                            .frame(height: 80)
                            .padding(ENVISpacing.sm)
                            .background(ENVITheme.surfaceLow(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                    }

                    // Hashtags
                    FlowLayout(spacing: ENVISpacing.sm) {
                        ForEach(Array(hashtags.enumerated()), id: \.offset) { _, tag in
                            Text(tag)
                                .font(.interMedium(13))
                                .foregroundColor(ENVITheme.text(for: colorScheme))
                                .padding(.horizontal, ENVISpacing.md)
                                .padding(.vertical, ENVISpacing.xs)
                                .background(ENVITheme.surfaceLow(for: colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                        }
                    }

                    // Platforms
                    VStack(alignment: .leading, spacing: ENVISpacing.md) {
                        Text("SHARE TO")
                            .font(.spaceMono(11))
                            .tracking(0.88)
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: ENVISpacing.md) {
                            ForEach(composer.availablePlatforms) { platform in
                                Button {
                                    togglePlatform(platform)
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: platform.iconName)
                                            .font(.system(size: 22))
                                            .foregroundColor(selectedPlatforms.contains(platform) ? platform.brandColor : ENVITheme.textLight(for: colorScheme))
                                        Text(platform.rawValue)
                                            .font(.spaceMono(9))
                                            .foregroundColor(selectedPlatforms.contains(platform) ? ENVITheme.text(for: colorScheme) : ENVITheme.textLight(for: colorScheme))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, ENVISpacing.md)
                                    .background(selectedPlatforms.contains(platform) ? platform.brandColor.opacity(0.12) : ENVITheme.surfaceLow(for: colorScheme))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: ENVIRadius.md)
                                            .stroke(selectedPlatforms.contains(platform) ? platform.brandColor.opacity(0.8) : Color.clear, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Format
                    VStack(alignment: .leading, spacing: ENVISpacing.md) {
                        Text("FORMAT")
                            .font(.spaceMono(11))
                            .tracking(0.88)
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))

                        HStack(spacing: ENVISpacing.sm) {
                            ForEach(ratios, id: \.self) { ratio in
                                ENVIChip(title: ratio, isSelected: selectedRatio == ratio) {
                                    selectedRatio = ratio
                                }
                            }
                        }
                    }

                    // Quality
                    VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                        Text("QUALITY")
                            .font(.spaceMono(11))
                            .tracking(0.88)
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))

                        Slider(value: $quality, in: 0.1...1.0)
                            .tint(ENVITheme.text(for: colorScheme))
                    }

                    // Export button
                    ENVIButton(composer.exportButtonTitle) {
                        isExporting = true
                    }

                    ENVIButton(
                        isPublishing ? "Publishing..." : "Publish Selected",
                        isEnabled: !isPublishing && !selectedPlatforms.isEmpty
                    ) {
                        Task { await publishSelected() }
                    }

                    VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                        Text("PUBLISH MODE")
                            .font(.spaceMono(11))
                            .tracking(0.88)
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))

                        Picker("Publish mode", selection: $publishMode) {
                            ForEach(PublishMode.allCases, id: \.self) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        if publishMode == .scheduled {
                            DatePicker(
                                "Schedule time",
                                selection: $scheduledAt,
                                in: Date()...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .font(.interRegular(13))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                        }
                    }

                    if let publishStatusMessage {
                        Text(publishStatusMessage)
                            .font(.interRegular(13))
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                    }
                }
                .padding(ENVISpacing.xl)
            }
            .background(ENVITheme.background(for: colorScheme))
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }
            }
            .overlay {
                if isExporting {
                    ProgressOverlayView {
                        isExporting = false
                        showShareSheet = true
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityViewController(activityItems: [exportSummary])
            }
        }
    }

    private var hashtags: [String] {
        let matches = caption
            .split(separator: " ")
            .map(String.init)
            .filter { $0.hasPrefix("#") }
        return matches.isEmpty ? ["#envi", "#creator", "#readytopost"] : Array(matches.prefix(5))
    }

    private var captionOptions: [String] {
        composer.captionOptions(
            selectedPlatforms: Array(selectedPlatforms),
            ratio: selectedRatio,
            quality: quality
        )
    }

    private var exportSummary: String {
        let fallbackPlatforms = selectedPlatforms.isEmpty ? Set(composer.preferredPlatforms) : selectedPlatforms
        let platformList = fallbackPlatforms.map(\.rawValue).sorted().joined(separator: ", ")
        return """
        ENVI Export Ready

        Title:
        \(composer.context.title)

        Caption:
        \(caption)

        Platforms: \(platformList)
        Ratio: \(selectedRatio)
        Quality: \(Int(quality * 100))%
        """
    }

    private func regenerateCaption() {
        guard !captionOptions.isEmpty else { return }
        captionOptionIndex = (captionOptionIndex + 1) % captionOptions.count
        caption = captionOptions[captionOptionIndex]
    }

    private func copyCaption() {
        UIPasteboard.general.string = caption
        copyFeedback = "Copied"
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            copyFeedback = "Copy"
        }
    }

    private func togglePlatform(_ platform: SocialPlatform) {
        if selectedPlatforms.contains(platform) {
            selectedPlatforms.remove(platform)
        } else {
            selectedPlatforms.insert(platform)
        }
    }

    @MainActor
    private func publishSelected() async {
        guard !selectedPlatforms.isEmpty else { return }
        isPublishing = true
        publishStatusMessage = "Submitting publish request..."
        let scheduledAtDate = publishMode == .scheduled ? scheduledAt : nil

        do {
            // Phase 12 — `mediaRefs` are Cloud Storage object paths. ExportSheet
            // currently composes text-only posts; media fan-out will populate
            // this array once the editor's upload step is wired through.
            let ticket = try await PublishingManager.shared.startPublish(
                caption: caption,
                platforms: Array(selectedPlatforms),
                mediaRefs: [],
                scheduledAt: scheduledAtDate
            )

            if scheduledAtDate != nil {
                publishStatusMessage = "Scheduled (\(ticket.jobID)). Checking status..."
            } else {
                publishStatusMessage = "Queued (\(ticket.jobID)). Checking status..."
            }
            let finalStatus = try await PublishingManager.shared.waitForFinalStatus(jobID: ticket.jobID)

            switch finalStatus {
            case .posted:
                publishStatusMessage = "Published successfully."
            case .partial:
                publishStatusMessage = "Partially published. Some platforms failed."
            case .failed:
                publishStatusMessage = "Publish failed. Please retry."
            case .queued, .processing:
                publishStatusMessage = "Publish still processing."
            }
        } catch {
            publishStatusMessage = "Publish request failed."
        }

        isPublishing = false
    }
}

private enum PublishMode: CaseIterable {
    case now
    case scheduled

    var title: String {
        switch self {
        case .now:
            return "Now"
        case .scheduled:
            return "Schedule"
        }
    }
}

#Preview {
    ExportSheetView(composer: .preview)
        .preferredColorScheme(.dark)
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
