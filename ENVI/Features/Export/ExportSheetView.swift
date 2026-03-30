import SwiftUI
import UIKit

/// Export sheet presented from the editor.
struct ExportSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var caption: String
    @State private var selectedRatio = "9:16"
    @State private var quality: Double = 0.8
    @State private var selectedPlatforms: Set<SocialPlatform>
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var copyFeedback = "Copy"
    @State private var captionOptionIndex = 0

    let ratios = ["9:16", "1:1", "16:9", "4:5"]
    let platforms: [SocialPlatform] = [.instagram, .tiktok, .youtube, .x, .threads, .linkedin]
    let initialCaption: String
    let preferredPlatform: SocialPlatform?

    init(initialCaption: String = "Capturing the perfect moment ✨ #lifestyle #content", preferredPlatform: SocialPlatform? = .instagram) {
        self.initialCaption = initialCaption
        self.preferredPlatform = preferredPlatform
        _caption = State(initialValue: initialCaption)
        _selectedPlatforms = State(initialValue: preferredPlatform.map { [$0] } ?? [.instagram])
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
                        ForEach(hashtags, id: \.self) { tag in
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
                            ForEach(platforms) { platform in
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
                    ENVIButton("Export Video") {
                        isExporting = true
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
        let cleanedCaption = initialCaption.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseCaption = cleanedCaption.isEmpty ? "Fresh export from ENVI." : cleanedCaption
        let platformLine = selectedPlatforms.isEmpty ? "Built for your next post." : "Planned for \(selectedPlatforms.map(\.rawValue).sorted().joined(separator: ", "))."
        return [
            baseCaption,
            "\(baseCaption)\n\n\(platformLine)",
            "\(baseCaption)\n\nSave this one for the perfect window and post when the audience is hottest.",
            "\(baseCaption)\n\nExported in \(selectedRatio) at \(Int(quality * 100))% quality."
        ]
    }

    private var exportSummary: String {
        let platformList = selectedPlatforms.isEmpty ? "Instagram" : selectedPlatforms.map(\.rawValue).sorted().joined(separator: ", ")
        return """
        ENVI Export Ready

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
}

#Preview {
    ExportSheetView()
        .preferredColorScheme(.dark)
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
