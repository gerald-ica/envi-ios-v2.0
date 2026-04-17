import SwiftUI

/// List of saved searches with alert toggles and swipe-to-delete.
struct SavedSearchesView: View {
    @ObservedObject var viewModel: SearchViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingSaved {
                    ProgressView()
                        .tint(ENVITheme.primary(for: colorScheme))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.savedSearches.isEmpty {
                    emptyState
                } else {
                    searchList
                }
            }
            .background(ENVITheme.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Saved Searches")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.spaceMonoBold(14))
                        .foregroundColor(ENVITheme.primary(for: colorScheme))
                }
            }
        }
    }

    // MARK: - Search List

    private var searchList: some View {
        List {
            ForEach(viewModel.savedSearches) { search in
                savedSearchRow(search)
                    .listRowBackground(ENVITheme.background(for: colorScheme))
                    .listRowSeparatorTint(ENVITheme.border(for: colorScheme))
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let search = viewModel.savedSearches[index]
                    viewModel.deleteSavedSearch(search)
                }
            }
        }
        .listStyle(.plain)
    }

    private func savedSearchRow(_ search: SavedSearch) -> some View {
        Button {
            viewModel.applySavedSearch(search)
            dismiss()
        } label: {
            HStack(spacing: ENVISpacing.md) {
                VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                    Text(search.name)
                        .font(.spaceMonoBold(14))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    if !search.query.text.isEmpty {
                        Text(search.query.text)
                            .font(.spaceMono(11))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                            .lineLimit(1)
                    }

                    if !search.query.filters.isEmpty {
                        Text("\(search.query.filters.count) filter\(search.query.filters.count == 1 ? "" : "s")")
                            .font(.spaceMono(10))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }
                }

                Spacer()

                // Alert toggle
                VStack(spacing: ENVISpacing.xs) {
                    Button {
                        viewModel.toggleAlert(for: search)
                    } label: {
                        Image(systemName: search.alertEnabled ? "bell.fill" : "bell.slash")
                            .font(.system(size: 16))
                            .foregroundColor(
                                search.alertEnabled
                                    ? ENVITheme.primary(for: colorScheme)
                                    : ENVITheme.textSecondary(for: colorScheme)
                            )
                    }
                    .buttonStyle(.plain)

                    Text(search.alertEnabled ? "ON" : "OFF")
                        .font(.spaceMono(8))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }
            .padding(.vertical, ENVISpacing.sm)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: ENVISpacing.lg) {
            Image(systemName: "bookmark")
                .font(.system(size: 36))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("No Saved Searches")
                .font(.spaceMonoBold(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Save a search from the search bar to quickly run it again later.")
                .font(.spaceMono(12))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, ENVISpacing.xxxl)
        }
    }
}
