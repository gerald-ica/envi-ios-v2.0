import SwiftUI
import PhotosUI

/// Main library screen with filter chips, template carousel, and masonry grid.
struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var showMediaPicker = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                    // Title
                    Text("LIBRARY")
                        .font(.spaceMonoBold(28))
                        .tracking(-1.5)
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .padding(.horizontal, ENVISpacing.xl)

                    // Filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: ENVISpacing.sm) {
                            ForEach(LibraryViewModel.FilterType.allCases, id: \.self) { filter in
                                ENVIChip(
                                    title: filter.rawValue,
                                    isSelected: viewModel.selectedFilter == filter
                                ) {
                                    viewModel.selectedFilter = filter
                                }
                            }
                        }
                        .padding(.horizontal, ENVISpacing.xl)
                    }

                    // Search
                    HStack(spacing: ENVISpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                        TextField("Search library", text: $viewModel.searchQuery)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                    }
                    .padding(.horizontal, ENVISpacing.md)
                    .padding(.vertical, ENVISpacing.sm)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                    .padding(.horizontal, ENVISpacing.xl)

                    // Templates
                    TemplateCarousel(
                        templates: viewModel.templates,
                        onApply: { template in
                            viewModel.applyTemplate(template)
                        },
                        onDuplicate: { template in
                            Task { await viewModel.duplicateTemplate(template) }
                        },
                        onDelete: { template in
                            Task { await viewModel.deleteTemplate(template) }
                        }
                    )

                    if viewModel.isApplyingTemplateOperation {
                        HStack {
                            ProgressView()
                            Text("Updating templates...")
                                .font(.interRegular(12))
                                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                        }
                        .padding(.horizontal, ENVISpacing.xl)
                    }

                    if let templateError = viewModel.templateOperationErrorMessage {
                        Text(templateError)
                            .font(.interRegular(12))
                            .foregroundColor(.red)
                            .padding(.horizontal, ENVISpacing.xl)
                    }

                    ContentPlanningSectionView(
                        items: $viewModel.contentPlan,
                        isLoading: viewModel.isLoadingPlan,
                        errorMessage: viewModel.planErrorMessage,
                        onRetry: {
                            Task { await viewModel.reloadContentPlan() }
                        },
                        onAdd: {
                            viewModel.isShowingPlanEditor = true
                        },
                        onEdit: { item in
                            viewModel.editingPlanItem = item
                        },
                        onDelete: { item in
                            Task { await viewModel.deletePlanItem(item) }
                        },
                        onStatusToggle: { item in
                            let next: ContentPlanItem.Status
                            switch item.status {
                            case .draft: next = .ready
                            case .ready: next = .scheduled
                            case .scheduled: next = .draft
                            }
                            Task { await viewModel.updatePlanItem(item, status: next) }
                        },
                        onMove: { source, destination in
                            viewModel.reorderPlanItems(from: source, to: destination)
                        }
                    )
                    .padding(.horizontal, ENVISpacing.xl)

                    if let planError = viewModel.planOperationErrorMessage {
                        Text(planError)
                            .font(.interRegular(12))
                            .foregroundColor(.red)
                            .padding(.horizontal, ENVISpacing.xl)
                    }

                    if viewModel.isLoading {
                        HStack {
                            ProgressView()
                            Text("Loading library...")
                                .font(.interRegular(13))
                                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                        }
                        .padding(.horizontal, ENVISpacing.xl)
                    }

                    if let error = viewModel.loadErrorMessage {
                        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                            Text(error)
                                .font(.interMedium(13))
                                .foregroundColor(.red)
                            Button("Retry") {
                                Task { await viewModel.reloadLibrary() }
                            }
                            .font(.interMedium(13))
                        }
                        .padding(.horizontal, ENVISpacing.xl)
                    }

                    // Masonry grid
                    MasonryGridView(items: viewModel.filteredItems)
                        .padding(.horizontal, ENVISpacing.xl)
                }
                .padding(.top, ENVISpacing.lg)
                .padding(.bottom, 100) // space for tab bar
            }

            // FAB
            Button(action: { showMediaPicker = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 56, height: 56)
                    .background(Color.white)
                    .clipShape(Circle())
                    .enviElevatedShadow()
            }
            .padding(.trailing, ENVISpacing.xl)
            .padding(.bottom, 90)
        }
        .background(ENVITheme.background(for: colorScheme))
        .sheet(item: $viewModel.templateToApply) { template in
            ExportSheetView(
                composer: ExportComposerFactory.make(template: template)
            )
        }
        .sheet(isPresented: $viewModel.isShowingPlanEditor) {
            PlanItemEditorSheet(existingItem: nil) { title, platform, scheduledAt in
                Task { await viewModel.createPlanItem(title: title, platform: platform, scheduledAt: scheduledAt) }
            }
        }
        .sheet(item: $viewModel.editingPlanItem) { item in
            PlanItemEditorSheet(existingItem: item) { title, platform, scheduledAt in
                Task { await viewModel.updatePlanItem(item, title: title, platform: platform, scheduledAt: scheduledAt) }
            }
        }
        .sheet(isPresented: $showMediaPicker) {
            MediaPickerView { assetIdentifiers in
                guard !assetIdentifiers.isEmpty else { return }
                ContentPieceAssembler.shared.enqueueForAssembly(mediaIDs: assetIdentifiers)
            }
        }
    }
}

// MARK: - PHPicker Wrapper

/// UIViewControllerRepresentable wrapping PHPickerViewController for importing media.
struct MediaPickerView: UIViewControllerRepresentable {
    let onPick: ([String]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 10
        config.filter = .any(of: [.images, .videos])
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: ([String]) -> Void

        init(onPick: @escaping ([String]) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            let identifiers = results.compactMap(\.assetIdentifier)
            onPick(identifiers)
        }
    }
}

#Preview {
    LibraryView()
        .preferredColorScheme(.dark)
}
