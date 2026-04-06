import SwiftUI

/// AI image generator with text prompt input, dimensions picker, generate button, and results gallery.
struct ImageGeneratorView: View {
    @ObservedObject var viewModel: AIVisualViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                headerSection
                promptInputSection
                dimensionsPicker
                generateButton
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }
                if !viewModel.generatedImages.isEmpty {
                    resultsGallery
                }
            }
            .padding(ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .navigationTitle("Image Generator")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel.generatedImages.isEmpty {
                await viewModel.loadGeneratedImages()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text("AI IMAGE GENERATOR")
                .font(.spaceMonoBold(11))
                .tracking(2.5)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("Create unique images from text descriptions.")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
    }

    // MARK: - Prompt Input

    private var promptInputSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("PROMPT")
                .font(.spaceMonoBold(11))
                .tracking(2.5)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            TextEditor(text: $viewModel.generationPrompt)
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100)
                .padding(ENVISpacing.md)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.md)
                        .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                )

            Text("\(viewModel.generationPrompt.count) characters")
                .font(.interRegular(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
    }

    // MARK: - Dimensions Picker

    private var dimensionsPicker: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("Dimensions")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ENVISpacing.sm) {
                    ForEach(ImageDimensions.allCases) { dim in
                        dimensionChip(dim)
                    }
                }
            }
        }
    }

    private func dimensionChip(_ dimensions: ImageDimensions) -> some View {
        let isSelected = viewModel.selectedDimensions == dimensions
        return Button {
            viewModel.selectedDimensions = dimensions
        } label: {
            VStack(spacing: ENVISpacing.xs) {
                Image(systemName: dimensions.iconName)
                    .font(.system(size: 16))

                Text(dimensions.displayName.uppercased())
                    .font(.spaceMonoBold(10))
                    .tracking(1)

                Text(dimensions.rawValue)
                    .font(.interRegular(9))
            }
            .foregroundColor(
                isSelected
                    ? (colorScheme == .dark ? .black : .white)
                    : ENVITheme.textSecondary(for: colorScheme)
            )
            .padding(.horizontal, ENVISpacing.lg)
            .padding(.vertical, ENVISpacing.md)
            .background(
                isSelected
                    ? ENVITheme.primary(for: colorScheme)
                    : .clear
            )
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.sm)
                    .strokeBorder(
                        isSelected ? .clear : ENVITheme.border(for: colorScheme),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            Task { await viewModel.generateImage() }
        } label: {
            HStack(spacing: ENVISpacing.sm) {
                if viewModel.isGeneratingImage {
                    ProgressView()
                        .tint(colorScheme == .dark ? .black : .white)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(viewModel.isGeneratingImage ? "GENERATING..." : "GENERATE IMAGE")
                    .font(.spaceMonoBold(13))
                    .tracking(2)
            }
            .foregroundColor(colorScheme == .dark ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, ENVISpacing.lg)
            .background(ENVITheme.primary(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isGeneratingImage || viewModel.generationPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(viewModel.isGeneratingImage ? 0.6 : 1)
    }

    // MARK: - Results Gallery

    private var resultsGallery: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("\(viewModel.generatedImages.count) Generated")

            ForEach(viewModel.generatedImages) { image in
                generatedImageCard(image)
            }
        }
    }

    private func generatedImageCard(_ image: GeneratedImage) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            AsyncImage(url: image.imageURL) { phase in
                switch phase {
                case .success(let loaded):
                    loaded
                        .resizable()
                        .aspectRatio(image.dimensions.aspectRatio, contentMode: .fit)
                case .failure:
                    generatedPlaceholder(image)
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 180)
                @unknown default:
                    generatedPlaceholder(image)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))

            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text(image.prompt)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .lineLimit(2)

                HStack(spacing: ENVISpacing.md) {
                    metadataTag(image.dimensions.displayName)
                    metadataTag(image.dimensions.rawValue)
                    metadataTag("Seed: \(image.seed)")

                    Spacer()

                    Button {
                        viewModel.removeGeneratedImage(image)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ENVISpacing.sm)
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    private func generatedPlaceholder(_ image: GeneratedImage) -> some View {
        VStack(spacing: ENVISpacing.md) {
            Image(systemName: "photo.artframe")
                .font(.system(size: 32))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text(image.dimensions.displayName)
                .font(.interRegular(12))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(ENVITheme.surfaceHigh(for: colorScheme))
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.spaceMonoBold(11))
            .tracking(2.5)
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
    }

    private func metadataTag(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.spaceMonoBold(9))
            .tracking(1)
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            .padding(.horizontal, ENVISpacing.sm)
            .padding(.vertical, ENVISpacing.xs)
            .background(ENVITheme.surfaceHigh(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: ENVISpacing.sm) {
            Image(systemName: "exclamationmark.triangle")
            Text(message)
                .font(.interRegular(13))
        }
        .foregroundColor(ENVITheme.error)
        .padding(ENVISpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ENVITheme.error.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
    }
}

#Preview {
    NavigationStack {
        ImageGeneratorView(viewModel: AIVisualViewModel())
    }
    .preferredColorScheme(.dark)
}
