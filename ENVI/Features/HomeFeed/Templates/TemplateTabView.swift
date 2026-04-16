//
//  TemplateTabView.swift
//  ENVI
//
//  Phase 5 — Task 1: Top-level SwiftUI shell for the Template tab.
//
//  Consumes Phase 3's `TemplateTabViewModel` (@MainActor @Observable).
//  Renders:
//    • Header "TEMPLATES" (SpaceMono bold) with a settings button
//    • Conditional scan progress banner ("Analyzing your N photos…")
//    • Horizontal category chip row (All / For You / per VideoTemplateCategory)
//    • "For You" 2-col LazyVGrid when no category is selected
//    • Per-category horizontal LazyHStack rows
//    • Loading / error / empty (Photos-denied) states
//
//  Placeholders (until Tasks 2 & 3 land):
//    • `TemplateCardPlaceholder` — replaced by Task 2's `TemplateCardView`
//    • `TemplatePreviewPlaceholder` — replaced by Task 3's `TemplatePreviewView`
//

import SwiftUI

struct TemplateTabView: View {

    // MARK: - Dependencies

    /// @Observable VM (iOS 26 / Swift 6.2 Observation macro). SwiftUI
    /// reads properties directly — no @ObservedObject / @StateObject.
    @State private var viewModel: TemplateTabViewModel

    /// Photos authorization observer. Drives the empty-state CTA when
    /// the user has denied access.
    @StateObject private var photos: PhotoLibraryManager = .shared

    @State private var selectedPreview: PopulatedTemplate?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    // MARK: - Init

    init(viewModel: TemplateTabViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ENVITheme.background(for: colorScheme).ignoresSafeArea()

                content
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedPreview) { populated in
                TemplatePreviewView(populated: populated, viewModel: viewModel)
            }
        }
        .task {
            await viewModel.refresh()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if !photos.authorizationStatus.isAuthorized && photos.authorizationStatus != .notDetermined {
            photosDeniedEmptyState
        } else if viewModel.isLoading && viewModel.populatedTemplates.isEmpty {
            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                ENVILoadingState()
                Spacer(minLength: 0)
            }
        } else {
            loadedContent
        }
    }

    private var loadedContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                header

                if let error = viewModel.error {
                    ENVIErrorBanner(message: errorMessage(from: error))
                }

                if shouldShowScanBanner {
                    scanProgressBanner
                        .padding(.horizontal, ENVISpacing.xl)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                categoryChipsRow

                if viewModel.selectedCategory == nil {
                    forYouSection
                }

                categorySections
            }
            .padding(.top, ENVISpacing.lg)
            .padding(.bottom, 100) // space for floating tab bar
            .animation(.easeInOut(duration: 0.2), value: shouldShowScanBanner)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("TEMPLATES")
                .font(.spaceMonoBold(17))
                .tracking(-0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Spacer()

            Button {
                // Settings hook — wire in a later task.
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Scan progress banner

    private var shouldShowScanBanner: Bool {
        switch viewModel.scanProgress.phase {
        case .onboarding, .background, .lazy, .incremental:
            return true
        case .idle, .completed, .paused:
            return false
        }
    }

    private var scanProgressBanner: some View {
        let progress = viewModel.scanProgress
        let fraction: Double = progress.total > 0
            ? Double(progress.completed) / Double(progress.total)
            : 0
        return VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("Analyzing your \(progress.total) photos…")
                .font(.interMedium(13))
                .foregroundColor(ENVITheme.text(for: colorScheme))
            ProgressView(value: fraction)
                .tint(ENVITheme.text(for: colorScheme))
        }
        .padding(ENVISpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    // MARK: - Category chips

    private var categoryChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ENVISpacing.sm) {
                ENVIChip(
                    title: "All",
                    isSelected: viewModel.selectedCategory == nil && !isForYouPinned
                ) {
                    viewModel.selectCategory(nil)
                    isForYouPinned = false
                }

                ENVIChip(
                    title: "For You",
                    isSelected: viewModel.selectedCategory == nil && isForYouPinned
                ) {
                    viewModel.selectCategory(nil)
                    isForYouPinned = true
                }

                ForEach(VideoTemplateCategory.allCases) { category in
                    ENVIChip(
                        title: category.displayName,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        viewModel.selectCategory(category)
                    }
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    // "For You" is just the All view scrolled to top — track a light
    // UI-only flag so the chip highlights correctly.
    @State private var isForYouPinned: Bool = false

    // MARK: - For You section

    @ViewBuilder
    private var forYouSection: some View {
        let top = Array(viewModel.populatedTemplates.prefix(10))
        if !top.isEmpty {
            VStack(alignment: .leading, spacing: ENVISpacing.md) {
                sectionLabel("For You")
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: ENVISpacing.md),
                        GridItem(.flexible(), spacing: ENVISpacing.md)
                    ],
                    spacing: ENVISpacing.md
                ) {
                    ForEach(top) { populated in
                        Button {
                            selectedPreview = populated
                            viewModel.select(populated)
                        } label: {
                            TemplateCardView(
                                populated: populated,
                                onTap: {
                                    selectedPreview = populated
                                    viewModel.select(populated)
                                },
                                onDuplicate: { /* TODO: Find similar content */ },
                                onHide: { /* TODO: Hide template */ }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }
        } else if !viewModel.isLoading {
            ENVIEmptyState(
                icon: "square.grid.2x2",
                title: "No templates yet",
                subtitle: "We'll populate this as we analyze your photos."
            )
        }
    }

    // MARK: - Category sections

    @ViewBuilder
    private var categorySections: some View {
        if let selected = viewModel.selectedCategory {
            let items = viewModel.byCategory[selected] ?? []
            categoryRow(title: selected.displayName, items: items)
        } else {
            ForEach(VideoTemplateCategory.allCases) { category in
                if let items = viewModel.byCategory[category], !items.isEmpty {
                    categoryRow(title: category.displayName, items: items)
                }
            }
        }
    }

    private func categoryRow(title: String, items: [PopulatedTemplate]) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel(title)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: ENVISpacing.md) {
                    ForEach(items) { populated in
                        Button {
                            selectedPreview = populated
                            viewModel.select(populated)
                        } label: {
                            TemplateCardView(
                                populated: populated,
                                onTap: {
                                    selectedPreview = populated
                                    viewModel.select(populated)
                                },
                                onDuplicate: { /* TODO: Find similar content */ },
                                onHide: { /* TODO: Hide template */ }
                            )
                            .frame(width: 180)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.spaceMono(11))
            .tracking(1.5)
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Empty state (Photos denied)

    private var photosDeniedEmptyState: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 0)
            VStack(spacing: ENVISpacing.lg) {
                ENVIEmptyState(
                    icon: "photo.on.rectangle.angled",
                    title: "Photos access required",
                    subtitle: "Grant access so ENVI can find templates that fit your real content."
                )

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Text("GRANT PHOTOS ACCESS")
                        .font(.spaceMonoBold(11))
                        .tracking(1.5)
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ENVISpacing.md)
                        .background(ENVITheme.text(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, ENVISpacing.xl)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Helpers

    private func errorMessage(from error: Error) -> String {
        let localized = error.localizedDescription
        return localized.isEmpty ? "Something went wrong loading templates." : localized
    }
}

// Placeholder structs removed — TemplateCardView (Task 2) and TemplatePreviewView (Task 3) are now wired up directly above.
