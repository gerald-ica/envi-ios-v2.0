import SwiftUI

/// AI-powered caption generator with topic input, platform picker, tone selector, and results list.
struct CaptionGeneratorView: View {
    @ObservedObject var viewModel: AIWritingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                headerSection
                topicInputSection
                platformPickerSection
                tonePickerSection
                generateButton
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }
                resultsSection
            }
            .padding(ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .navigationTitle("Caption Generator")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text("AI CAPTION GENERATOR")
                .font(.spaceMonoBold(11))
                .tracking(2.5)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("Generate engaging captions tailored to your platform and voice.")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
    }

    // MARK: - Topic Input

    private var topicInputSection: some View {
        ENVIInput(
            label: "Topic or Prompt",
            placeholder: "e.g. Building a personal brand from scratch",
            text: $viewModel.captionPrompt
        )
    }

    // MARK: - Platform Picker

    private var platformPickerSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("Platform")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ENVISpacing.sm) {
                    ForEach(SocialPlatform.allCases) { platform in
                        ENVIChip(
                            title: platform.rawValue,
                            isSelected: viewModel.captionPlatform == platform
                        ) {
                            viewModel.captionPlatform = platform
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tone Picker

    private var tonePickerSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("Tone")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ENVISpacing.sm) {
                    ForEach(WritingTone.allCases) { tone in
                        ENVIChip(
                            title: tone.displayName,
                            isSelected: viewModel.captionTone == tone
                        ) {
                            viewModel.captionTone = tone
                        }
                    }
                }
            }
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button(action: {
            Task { await viewModel.generateCaption() }
        }) {
            HStack(spacing: ENVISpacing.sm) {
                if viewModel.isGeneratingCaption {
                    ProgressView()
                        .tint(colorScheme == .dark ? .black : .white)
                } else {
                    Image(systemName: "sparkles")
                }
                Text("GENERATE CAPTION")
                    .font(.spaceMonoBold(13))
                    .tracking(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ENVISpacing.lg)
            .foregroundColor(colorScheme == .dark ? .black : .white)
            .background(ENVITheme.text(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
        .disabled(viewModel.captionPrompt.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isGeneratingCaption)
        .opacity(viewModel.captionPrompt.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
    }

    // MARK: - Results

    private var resultsSection: some View {
        Group {
            if !viewModel.generatedCaptions.isEmpty {
                VStack(alignment: .leading, spacing: ENVISpacing.lg) {
                    sectionLabel("Generated Captions")

                    ForEach(viewModel.generatedCaptions) { caption in
                        captionCard(caption)
                    }
                }
            }
        }
    }

    private func captionCard(_ caption: CaptionDraft) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Platform + Tone badges
            HStack(spacing: ENVISpacing.sm) {
                badge(caption.platform.rawValue)
                badge(caption.tone.displayName)
                Spacer()
                characterCountBadge(caption.characterCount)
            }

            // Caption text
            Text(caption.text)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .lineSpacing(4)
                .textSelection(.enabled)

            // Hashtag suggestions
            if !caption.hashtagSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ENVISpacing.xs) {
                        ForEach(caption.hashtagSuggestions, id: \.self) { tag in
                            Text(tag)
                                .font(.spaceMono(11))
                                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                                .padding(.horizontal, ENVISpacing.sm)
                                .padding(.vertical, ENVISpacing.xs)
                                .background(ENVITheme.surfaceLow(for: colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                        }
                    }
                }
            }

            // Actions
            HStack(spacing: ENVISpacing.md) {
                actionButton(icon: "doc.on.doc", label: "Copy") {
                    UIPasteboard.general.string = caption.text
                }
                actionButton(icon: "arrow.clockwise", label: "Regenerate") {
                    Task { await viewModel.regenerateCaption(caption) }
                }
                actionButton(icon: "bookmark", label: "Save") {
                    viewModel.saveCaption(caption)
                }
                Spacer()
                actionButton(icon: "xmark", label: "Remove") {
                    viewModel.removeCaption(caption)
                }
            }
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Shared Components

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.spaceMonoBold(11))
            .tracking(2.5)
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
    }

    private func badge(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.spaceMono(10))
            .tracking(1)
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            .padding(.horizontal, ENVISpacing.sm)
            .padding(.vertical, ENVISpacing.xs)
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.sm)
                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
            )
    }

    private func characterCountBadge(_ count: Int) -> some View {
        Text("\(count) chars")
            .font(.spaceMono(10))
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: ENVISpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label.uppercased())
                    .font(.spaceMono(10))
                    .tracking(1)
            }
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .buttonStyle(.plain)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.interRegular(13))
            .foregroundColor(.red)
            .padding(ENVISpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }
}

#Preview {
    NavigationStack {
        CaptionGeneratorView(viewModel: AIWritingViewModel())
    }
    .preferredColorScheme(.dark)
}
