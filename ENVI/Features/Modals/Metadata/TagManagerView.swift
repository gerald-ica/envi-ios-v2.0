@preconcurrency import SwiftUI

/// Tag cloud manager with color-coded categories, search, create/edit/delete, and usage counts.
struct TagManagerView: View {
    @ObservedObject var viewModel: MetadataViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                searchBar
                categoryFilter
                tagCloud

                if let error = viewModel.tagError {
                    Text(error)
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.error)
                        .padding(.horizontal, ENVISpacing.xl)
                }
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .sheet(isPresented: $viewModel.isShowingTagEditor) {
            if let tag = viewModel.editingTag {
                TagEditorSheet(
                    tag: tag,
                    onSave: { updated in Task { await viewModel.saveTag(updated) } },
                    onCancel: {
                        viewModel.isShowingTagEditor = false
                        viewModel.editingTag = nil
                    }
                )
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text("TAG MANAGER")
                    .font(.spaceMonoBold(17))
                    .tracking(-0.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("\(viewModel.tags.count) tags")
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()

            Button {
                viewModel.startCreatingTag()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .frame(width: 36, height: 36)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .cornerRadius(ENVIRadius.sm)
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: ENVISpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            TextField("Search tags...", text: $viewModel.searchText)
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .cornerRadius(ENVIRadius.md)
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ENVISpacing.sm) {
                categoryChip(title: "All", isSelected: viewModel.selectedCategory == nil) {
                    viewModel.selectedCategory = nil
                }

                ForEach(TagCategory.allCases) { category in
                    categoryChip(
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

    private func categoryChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        ENVIFilterChip(title: title, isSelected: isSelected, action: action)
    }

    // MARK: - Tag Cloud

    private var tagCloud: some View {
        Group {
            if viewModel.isLoadingTags {
                ENVILoadingState()
            } else if viewModel.filteredTags.isEmpty {
                emptyState
            } else {
                WrappingHStack(items: viewModel.filteredTags) { tag in
                    tagChip(tag)
                }
                .padding(.horizontal, ENVISpacing.xl)
            }
        }
    }

    private func tagChip(_ tag: Tag) -> some View {
        Button {
            viewModel.startEditingTag(tag)
        } label: {
            HStack(spacing: ENVISpacing.xs) {
                Circle()
                    .fill(Color(hex: tag.color))
                    .frame(width: 8, height: 8)

                Text(tag.name)
                    .font(.interSemiBold(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("\(tag.usageCount)")
                    .font(.interRegular(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .cornerRadius(4)
            }
            .padding(.horizontal, ENVISpacing.md)
            .padding(.vertical, ENVISpacing.sm)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .cornerRadius(ENVIRadius.sm)
        }
        .contextMenu {
            Button {
                viewModel.startEditingTag(tag)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                Task { await viewModel.deleteTag(tag) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        ENVIEmptyState(
            icon: "tag",
            title: "No tags yet",
            subtitle: "Create your first tag to start organizing content."
        )
    }
}

// MARK: - Wrapping HStack

/// Tracks mutable layout state for alignment guides during a single synchronous layout pass.
private final class LayoutState: @unchecked Sendable {
    private var width: CGFloat = .zero
    private var height: CGFloat = .zero

    func leadingOffset(width itemWidth: CGFloat, height itemHeight: CGFloat, gWidth: CGFloat, isLast: Bool) -> CGFloat {
        if abs(width - itemWidth) > gWidth {
            width = 0
            height -= itemHeight + ENVISpacing.sm
        }
        let result = width
        if isLast {
            width = 0
        } else {
            width -= itemWidth + ENVISpacing.sm
        }
        return result
    }

    func topOffset(isLast: Bool) -> CGFloat {
        let result = height
        if isLast {
            height = 0
        }
        return result
    }
}

/// Simple flow layout for tag chips.
private struct WrappingHStack<Item: Identifiable & Sendable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { geometry in
            generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        let layout = LayoutState()
        let gWidth = geometry.size.width
        let lastIndex = items.indices.last

        return ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                content(item)
                    .padding(.trailing, ENVISpacing.sm)
                    .padding(.bottom, ENVISpacing.sm)
                    .alignmentGuide(.leading) { d in
                        layout.leadingOffset(width: d.width, height: d.height, gWidth: gWidth, isLast: index == lastIndex)
                    }
                    .alignmentGuide(.top) { _ in
                        layout.topOffset(isLast: index == lastIndex)
                    }
            }
        }
        .background(viewHeightReader($totalHeight))
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geometry -> Color in
            DispatchQueue.main.async {
                binding.wrappedValue = geometry.size.height
            }
            return Color.clear
        }
    }
}

// MARK: - Tag Editor Sheet

private struct TagEditorSheet: View {
    @State var tag: Tag
    let onSave: (Tag) -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Tag name", text: $tag.name)
                        .font(.interRegular(15))
                }

                Section("Category") {
                    Picker("Category", selection: $tag.category) {
                        ForEach(TagCategory.allCases) { category in
                            HStack {
                                Circle()
                                    .fill(Color(hex: category.chipColorHex))
                                    .frame(width: 10, height: 10)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle(tag.name.isEmpty ? "New Tag" : "Edit Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = tag
                        updated.color = tag.category.chipColorHex
                        onSave(updated)
                    }
                    .disabled(tag.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    TagManagerView(
        viewModel: MetadataViewModel(repository: MockMetadataRepository())
    )
}
#endif
