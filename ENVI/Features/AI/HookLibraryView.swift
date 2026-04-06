import SwiftUI

/// Filterable grid of hook templates with performance scores, favorites, and "Use This" action.
struct HookLibraryView: View {
    @ObservedObject var viewModel: AIWritingViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var showFavoritesOnly = false
    @State private var copiedHookID: UUID?

    private var displayedHooks: [HookTemplate] {
        let hooks = viewModel.filteredHooks
        if showFavoritesOnly {
            return hooks.filter(\.isFavorite)
        }
        return hooks
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                headerSection
                searchAndFilterSection
                hookGrid
            }
            .padding(ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .navigationTitle("Hook Library")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel.hookTemplates.isEmpty {
                await viewModel.loadHooks()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text("HOOK TEMPLATES")
                .font(.spaceMonoBold(11))
                .tracking(2.5)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("Proven hook patterns ranked by performance. Tap to use.")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
    }

    // MARK: - Search & Filter

    private var searchAndFilterSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Search bar
            HStack(spacing: ENVISpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                TextField("Search hooks...", text: $viewModel.hookSearchQuery)
                    .font(.interRegular(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                if !viewModel.hookSearchQuery.isEmpty {
                    Button(action: { viewModel.hookSearchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ENVISpacing.lg)
            .padding(.vertical, ENVISpacing.md)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.md)
                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
            )

            // Filter chips
            HStack(spacing: ENVISpacing.sm) {
                ENVIChip(
                    title: "All",
                    isSelected: !showFavoritesOnly
                ) {
                    showFavoritesOnly = false
                }

                ENVIChip(
                    title: "Favorites",
                    isSelected: showFavoritesOnly
                ) {
                    showFavoritesOnly = true
                }

                Spacer()

                Text("\(displayedHooks.count) hooks")
                    .font(.spaceMono(10))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
        }
    }

    // MARK: - Hook Grid

    private var hookGrid: some View {
        Group {
            if viewModel.isLoadingHooks {
                loadingState
            } else if displayedHooks.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ENVISpacing.md) {
                    ForEach(displayedHooks) { hook in
                        hookCard(hook)
                    }
                }
            }
        }
    }

    private func hookCard(_ hook: HookTemplate) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Header row: name + score
            HStack {
                Text(hook.name.uppercased())
                    .font(.spaceMonoBold(10))
                    .tracking(1.5)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .lineLimit(1)

                Spacer()

                performanceBadge(hook.performanceScore)
            }

            // Pattern
            Text(hook.pattern)
                .font(.interRegular(12))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .lineLimit(2)

            // Example
            Text(hook.example)
                .font(.interMedium(13))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            // Actions
            HStack(spacing: ENVISpacing.sm) {
                Button(action: { useHook(hook) }) {
                    HStack(spacing: ENVISpacing.xs) {
                        Image(systemName: copiedHookID == hook.id ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                        Text(copiedHookID == hook.id ? "COPIED" : "USE THIS")
                            .font(.spaceMonoBold(9))
                            .tracking(1)
                    }
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                    .padding(.horizontal, ENVISpacing.md)
                    .padding(.vertical, ENVISpacing.sm)
                    .background(ENVITheme.text(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { viewModel.toggleHookFavorite(hook) }) {
                    Image(systemName: hook.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 14))
                        .foregroundColor(hook.isFavorite ? .red : ENVITheme.textSecondary(for: colorScheme))
                }
                .buttonStyle(.plain)
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

    // MARK: - Performance Badge

    private func performanceBadge(_ score: Double) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 9))
            Text("\(Int(score * 100))%")
                .font(.spaceMonoBold(10))
        }
        .foregroundColor(scoreColor(score))
        .padding(.horizontal, ENVISpacing.sm)
        .padding(.vertical, 3)
        .background(scoreColor(score).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 0.85 { return .green }
        if score >= 0.70 { return .orange }
        return ENVITheme.textSecondary(for: colorScheme)
    }

    // MARK: - Loading & Empty States

    private var loadingState: some View {
        VStack(spacing: ENVISpacing.lg) {
            ProgressView()
                .tint(ENVITheme.text(for: colorScheme))
            Text("Loading hooks...")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ENVISpacing.xxxxl)
    }

    private var emptyState: some View {
        VStack(spacing: ENVISpacing.lg) {
            Image(systemName: showFavoritesOnly ? "heart.slash" : "magnifyingglass")
                .font(.system(size: 28))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text(showFavoritesOnly ? "No favorite hooks yet" : "No hooks found")
                .font(.interMedium(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text(showFavoritesOnly
                 ? "Tap the heart icon on any hook to add it here."
                 : "Try a different search term.")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ENVISpacing.xxxxl)
    }

    // MARK: - Actions

    private func useHook(_ hook: HookTemplate) {
        UIPasteboard.general.string = hook.example
        copiedHookID = hook.id

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedHookID == hook.id {
                copiedHookID = nil
            }
        }
    }
}

#Preview {
    NavigationView {
        HookLibraryView(viewModel: {
            let vm = AIWritingViewModel()
            vm.hookTemplates = HookTemplate.mockList
            return vm
        }())
    }
    .preferredColorScheme(.dark)
}
