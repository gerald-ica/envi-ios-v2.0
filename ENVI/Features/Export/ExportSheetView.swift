import SwiftUI

/// Export sheet presented from the editor.
struct ExportSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var caption = "Capturing the perfect moment ✨ #lifestyle #content"
    @State private var selectedRatio = "9:16"
    @State private var quality: Double = 0.8

    let ratios = ["9:16", "1:1", "16:9", "4:5"]
    let platforms: [SocialPlatform] = [.instagram, .tiktok, .youtube, .x, .threads, .linkedin]
    let hashtags = ["#lifestyle", "#content", "#creator", "#viral", "#trending"]

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
                            Button("Regenerate") {}
                                .font(.interMedium(12))
                                .foregroundColor(ENVITheme.primary(for: colorScheme))
                            Button("Copy") {}
                                .font(.interMedium(12))
                                .foregroundColor(ENVITheme.primary(for: colorScheme))
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
                                .foregroundColor(ENVITheme.primary(for: colorScheme))
                                .padding(.horizontal, ENVISpacing.md)
                                .padding(.vertical, ENVISpacing.xs)
                                .background(ENVITheme.surfaceLow(for: colorScheme))
                                .clipShape(Capsule())
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
                                VStack(spacing: 6) {
                                    Image(systemName: platform.iconName)
                                        .font(.system(size: 22))
                                        .foregroundColor(platform.brandColor)
                                    Text(platform.rawValue)
                                        .font(.spaceMono(9))
                                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, ENVISpacing.md)
                                .background(ENVITheme.surfaceLow(for: colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
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
                            .tint(ENVITheme.primary(for: colorScheme))
                    }

                    // Export button
                    ENVIButton("Export Video") {
                        dismiss()
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
                        .foregroundColor(ENVITheme.primary(for: colorScheme))
                }
            }
        }
    }
}

#Preview {
    ExportSheetView()
        .preferredColorScheme(.dark)
}
