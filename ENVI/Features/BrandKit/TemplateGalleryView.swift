import SwiftUI

/// Filterable grid of content templates with category and platform filters.
struct TemplateGalleryView: View {
    @ObservedObject var viewModel: BrandKitViewModel
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.flexible(), spacing: ENVISpacing.md),
        GridItem(.flexible(), spacing: ENVISpacing.md),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                categoryFilters
                platformFilters
                templateGrid

                if let error = viewModel.templateError {
                    Text(error)
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.error)
                        .padding(.horizontal, ENVISpacing.xl)
                }
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .sheet(isPresented: $viewModel.isShowingTemplateEditor) {
            if let template = viewModel.editingTemplate {
                TemplateEditorView(
                    template: template,
                    brandKits: viewModel.brandKits,
                    onSave: { updated in
                        Task { await viewModel.saveTemplate(updated) }
                    },
                    onCancel: {
                        viewModel.isShowingTemplateEditor = false
                        viewModel.editingTemplate = nil
                    }
                )
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text("TEMPLATES")
                    .font(.spaceMonoBold(17))
                    .tracking(-0.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("\(viewModel.filteredTemplates.count) templates")
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()

            Button(action: { viewModel.startCreatingTemplate() }) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .frame(width: 36, height: 36)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.sm)
                            .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Category Filters

    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ENVISpacing.sm) {
                ENVIChip(
                    title: "All",
                    isSelected: viewModel.selectedCategory == nil
                ) {
                    viewModel.selectedCategory = nil
                }

                ForEach(TemplateCategory.allCases, id: \.self) { category in
                    ENVIChip(
                        title: category.displayName,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        viewModel.selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    // MARK: - Platform Filters

    private var platformFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ENVISpacing.sm) {
                ENVIChip(
                    title: "All Platforms",
                    isSelected: viewModel.selectedPlatformFilter == nil
                ) {
                    viewModel.selectedPlatformFilter = nil
                }

                ForEach(SocialPlatform.allCases) { platform in
                    ENVIChip(
                        title: platform.rawValue,
                        isSelected: viewModel.selectedPlatformFilter == platform
                    ) {
                        viewModel.selectedPlatformFilter = platform
                    }
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    // MARK: - Template Grid

    private var templateGrid: some View {
        Group {
            if viewModel.isLoadingTemplates {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if viewModel.filteredTemplates.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: ENVISpacing.md) {
                    ForEach(viewModel.filteredTemplates) { template in
                        TemplateGalleryCardView(template: template)
                            .onTapGesture { viewModel.startEditingTemplate(template) }
                            .contextMenu {
                                Button("Edit") { viewModel.startEditingTemplate(template) }
                                Button("Duplicate") {
                                    Task { await viewModel.duplicateTemplate(template) }
                                }
                                Button("Delete", role: .destructive) {
                                    Task { await viewModel.deleteTemplate(template) }
                                }
                            }
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: ENVISpacing.md) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 32))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("No templates found")
                .font(.interMedium(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Create a template to streamline your content workflow.")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)

            ENVIButton("Create Template", variant: .secondary, isFullWidth: false) {
                viewModel.startCreatingTemplate()
            }
        }
        .padding(ENVISpacing.xxxl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Template Gallery Card

private struct TemplateGalleryCardView: View {
    let template: ContentTemplate
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            // Category icon + aspect ratio badge
            HStack {
                Image(systemName: template.category.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .frame(width: 44, height: 44)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))

                Spacer()

                Text(template.aspectRatio)
                    .font(.spaceMono(10))
                    .tracking(0.5)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.sm)
                    .padding(.vertical, ENVISpacing.xs)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }

            // Name
            Text(template.name)
                .font(.interSemiBold(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .lineLimit(2)

            // Category label
            Text(template.category.displayName.uppercased())
                .font(.spaceMono(10))
                .tracking(1.0)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            // Platform pills
            HStack(spacing: ENVISpacing.xs) {
                ForEach(template.suggestedPlatforms.prefix(3)) { platform in
                    Image(systemName: platform.iconName)
                        .font(.system(size: 10))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                Spacer()

                // Usage count
                HStack(spacing: 2) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 9))
                    Text("\(template.usageCount)")
                        .font(.spaceMono(10))
                }
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }
}

#Preview {
    TemplateGalleryView(viewModel: BrandKitViewModel())
        .preferredColorScheme(.dark)
}
