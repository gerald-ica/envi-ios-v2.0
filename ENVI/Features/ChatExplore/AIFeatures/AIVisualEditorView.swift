import SwiftUI

/// AI-powered visual editor with edit type grid, source image preview, apply button, and before/after slider.
struct AIVisualEditorView: View {
    @ObservedObject var viewModel: AIVisualViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                headerSection
                editTypeGrid
                sourceImageSection
                if viewModel.currentEditResult != nil {
                    beforeAfterSection
                }
                applyButton
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }
                if !viewModel.editHistory.isEmpty {
                    historySection
                }
            }
            .padding(ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .navigationTitle("Visual Editor")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadEditHistory()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text("AI VISUAL EDITOR")
                .font(.spaceMonoBold(11))
                .tracking(2.5)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("Transform your images with AI-powered editing tools.")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
    }

    // MARK: - Edit Type Grid

    private var editTypeGrid: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("Edit Type")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: ENVISpacing.sm),
                    GridItem(.flexible(), spacing: ENVISpacing.sm),
                ],
                spacing: ENVISpacing.sm
            ) {
                ForEach(AIEditType.allCases) { editType in
                    editTypeCard(editType)
                }
            }
        }
    }

    private func editTypeCard(_ editType: AIEditType) -> some View {
        let isSelected = viewModel.selectedEditType == editType
        return Button {
            viewModel.selectedEditType = editType
        } label: {
            VStack(spacing: ENVISpacing.sm) {
                Image(systemName: editType.iconName)
                    .font(.system(size: 22))
                    .foregroundColor(
                        isSelected
                            ? (colorScheme == .dark ? .black : .white)
                            : ENVITheme.text(for: colorScheme)
                    )

                Text(editType.displayName)
                    .font(.spaceMonoBold(10))
                    .tracking(1)
                    .multilineTextAlignment(.center)
                    .foregroundColor(
                        isSelected
                            ? (colorScheme == .dark ? .black : .white)
                            : ENVITheme.text(for: colorScheme)
                    )

                Text(editType.subtitle)
                    .font(.interRegular(10))
                    .foregroundColor(
                        isSelected
                            ? (colorScheme == .dark ? .black.opacity(0.7) : .white.opacity(0.7))
                            : ENVITheme.textSecondary(for: colorScheme)
                    )
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ENVISpacing.lg)
            .padding(.horizontal, ENVISpacing.sm)
            .background(
                isSelected
                    ? ENVITheme.primary(for: colorScheme)
                    : ENVITheme.surfaceLow(for: colorScheme)
            )
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .strokeBorder(
                        isSelected ? .clear : ENVITheme.border(for: colorScheme),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Source Image

    private var sourceImageSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("Source Image")

            if let url = viewModel.sourceImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
                    case .failure:
                        imagePlaceholder
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    @unknown default:
                        imagePlaceholder
                    }
                }
            } else {
                imagePlaceholder
            }
        }
    }

    private var imagePlaceholder: some View {
        VStack(spacing: ENVISpacing.md) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 36))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("Tap to select an image")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), style: StrokeStyle(lineWidth: 1, dash: [6]))
        )
    }

    // MARK: - Before / After Slider

    private var beforeAfterSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("Before / After")

            GeometryReader { geometry in
                ZStack {
                    // Original (left side)
                    if let result = viewModel.currentEditResult {
                        AsyncImage(url: result.originalURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ENVITheme.surfaceLow(for: colorScheme)
                        }
                        .frame(width: geometry.size.width, height: 240)
                        .clipped()

                        // Edited (right side, clipped)
                        AsyncImage(url: result.editedURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ENVITheme.surfaceHigh(for: colorScheme)
                        }
                        .frame(width: geometry.size.width, height: 240)
                        .clipped()
                        .mask(
                            HStack(spacing: 0) {
                                Spacer()
                                    .frame(width: geometry.size.width * viewModel.beforeAfterPosition)
                                Rectangle()
                            }
                        )

                        // Divider line
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 2, height: 240)
                            .position(
                                x: geometry.size.width * viewModel.beforeAfterPosition,
                                y: 120
                            )
                            .shadow(radius: 2)

                        // Labels
                        HStack {
                            Text("BEFORE")
                                .font(.spaceMonoBold(9))
                                .tracking(1.5)
                                .foregroundColor(.white)
                                .padding(.horizontal, ENVISpacing.sm)
                                .padding(.vertical, ENVISpacing.xs)
                                .background(Color.black.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))

                            Spacer()

                            Text("AFTER")
                                .font(.spaceMonoBold(9))
                                .tracking(1.5)
                                .foregroundColor(.white)
                                .padding(.horizontal, ENVISpacing.sm)
                                .padding(.vertical, ENVISpacing.xs)
                                .background(Color.black.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                        }
                        .padding(.horizontal, ENVISpacing.sm)
                        .frame(height: 240, alignment: .bottom)
                        .padding(.bottom, ENVISpacing.sm)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            viewModel.beforeAfterPosition = min(max(value.location.x / geometry.size.width, 0), 1)
                        }
                )
            }
            .frame(height: 240)

            if let result = viewModel.currentEditResult {
                HStack {
                    Text(result.editType.displayName.uppercased())
                        .font(.spaceMonoBold(10))
                        .tracking(1.5)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    Spacer()

                    Text("Confidence: \(result.formattedConfidence)")
                        .font(.interRegular(12))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }
        }
    }

    // MARK: - Apply Button

    private var applyButton: some View {
        Button {
            Task { await viewModel.applyEdit() }
        } label: {
            HStack(spacing: ENVISpacing.sm) {
                if viewModel.isApplyingEdit {
                    ProgressView()
                        .tint(colorScheme == .dark ? .black : .white)
                } else {
                    Image(systemName: "wand.and.stars")
                }
                Text(viewModel.isApplyingEdit ? "APPLYING..." : "APPLY EDIT")
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

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("Recent Edits")

            ForEach(viewModel.editHistory.prefix(5)) { result in
                HStack(spacing: ENVISpacing.md) {
                    Image(systemName: result.editType.iconName)
                        .font(.system(size: 16))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .frame(width: 32, height: 32)
                        .background(ENVITheme.surfaceLow(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.editType.displayName)
                            .font(.interSemiBold(14))
                            .foregroundColor(ENVITheme.text(for: colorScheme))

                        Text("Confidence: \(result.formattedConfidence)")
                            .font(.interRegular(12))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
                .padding(ENVISpacing.md)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            }
        }
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
        AIVisualEditorView(viewModel: AIVisualViewModel())
    }
    .preferredColorScheme(.dark)
}
