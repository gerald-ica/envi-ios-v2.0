import SwiftUI

/// Style preset gallery with category filtering and preview cards for AI style transfer.
struct StyleTransferView: View {
    @ObservedObject var viewModel: AIVisualViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                headerSection
                categoryPicker
                if viewModel.isLoadingPresets {
                    loadingSection
                } else if viewModel.filteredPresets.isEmpty {
                    emptySection
                } else {
                    presetGallery
                }
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }
                if viewModel.selectedPreset != nil {
                    selectedPresetDetail
                }
            }
            .padding(ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .navigationTitle("Style Transfer")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel.stylePresets.isEmpty {
                await viewModel.loadStylePresets()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text("STYLE TRANSFER")
                .font(.spaceMonoBold(11))
                .tracking(2.5)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("Apply artistic styles to your images with AI.")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ENVISpacing.sm) {
                ENVIChip(
                    title: "All",
                    isSelected: viewModel.selectedCategory == nil
                ) {
                    viewModel.selectedCategory = nil
                }

                ForEach(StylePreset.StyleCategory.allCases) { category in
                    ENVIChip(
                        title: category.displayName,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        viewModel.selectedCategory = category
                    }
                }
            }
        }
    }

    // MARK: - Preset Gallery

    private var presetGallery: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("\(viewModel.filteredPresets.count) Styles")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: ENVISpacing.sm),
                    GridItem(.flexible(), spacing: ENVISpacing.sm),
                    GridItem(.flexible(), spacing: ENVISpacing.sm),
                ],
                spacing: ENVISpacing.sm
            ) {
                ForEach(viewModel.filteredPresets) { preset in
                    presetCard(preset)
                }
            }
        }
    }

    private func presetCard(_ preset: StylePreset) -> some View {
        let isSelected = viewModel.selectedPreset?.id == preset.id
        return Button {
            viewModel.selectPreset(preset)
        } label: {
            VStack(spacing: ENVISpacing.sm) {
                AsyncImage(url: preset.previewURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    case .failure:
                        presetPlaceholder(preset)
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                    @unknown default:
                        presetPlaceholder(preset)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.md)
                        .strokeBorder(
                            isSelected ? ENVITheme.primary(for: colorScheme) : .clear,
                            lineWidth: 2
                        )
                )

                Text(preset.name.uppercased())
                    .font(.spaceMonoBold(9))
                    .tracking(1)
                    .foregroundColor(
                        isSelected
                            ? ENVITheme.text(for: colorScheme)
                            : ENVITheme.textSecondary(for: colorScheme)
                    )
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private func presetPlaceholder(_ preset: StylePreset) -> some View {
        ZStack {
            ENVITheme.surfaceLow(for: colorScheme)
            VStack(spacing: ENVISpacing.xs) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 20))
                Text(preset.name)
                    .font(.interRegular(10))
                    .lineLimit(1)
            }
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Selected Preset Detail

    private var selectedPresetDetail: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("Selected Style")

            if let preset = viewModel.selectedPreset {
                HStack(spacing: ENVISpacing.lg) {
                    AsyncImage(url: preset.previewURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ENVITheme.surfaceLow(for: colorScheme)
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))

                    VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                        Text(preset.name)
                            .font(.interSemiBold(16))
                            .foregroundColor(ENVITheme.text(for: colorScheme))

                        Text(preset.category.displayName.uppercased())
                            .font(.spaceMonoBold(10))
                            .tracking(1.5)
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }

                    Spacer()
                }
                .padding(ENVISpacing.lg)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))

                Button {
                    Task { await viewModel.applyEdit() }
                } label: {
                    HStack(spacing: ENVISpacing.sm) {
                        if viewModel.isApplyingEdit {
                            ProgressView()
                                .tint(colorScheme == .dark ? .black : .white)
                        } else {
                            Image(systemName: "paintbrush")
                        }
                        Text(viewModel.isApplyingEdit ? "APPLYING..." : "APPLY STYLE")
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
                .disabled(viewModel.isApplyingEdit)
                .opacity(viewModel.isApplyingEdit ? 0.6 : 1)
            }
        }
    }

    // MARK: - Loading & Empty

    private var loadingSection: some View {
        VStack(spacing: ENVISpacing.md) {
            ProgressView()
            Text("Loading styles...")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ENVISpacing.xxxxl)
    }

    private var emptySection: some View {
        VStack(spacing: ENVISpacing.md) {
            Image(systemName: "paintpalette")
                .font(.system(size: 32))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("No styles found for this category.")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ENVISpacing.xxxxl)
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.spaceMonoBold(11))
            .tracking(2.5)
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
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
        StyleTransferView(viewModel: AIVisualViewModel())
    }
    .preferredColorScheme(.dark)
}
