import SwiftUI

/// Step 3: Birth place selection via city search for USM onboarding.
struct USMOnboardingBirthPlaceView: View {
    @Bindable var viewModel: USMOnboardingViewModel
    @State private var searchQuery: String = ""
    @State private var searchResults: [USMCity] = []
    @State private var isSearching: Bool = false
    @State private var searchError: String?

    let citySearchClient: CitySearchClientProtocol

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            Text("WHERE WERE YOU BORN?")
                .font(.spaceMonoBold(32))
                .tracking(-2.0)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Search for your birth city or country.")
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            // Search Field
            VStack(alignment: .leading, spacing: ENVISpacing.md) {
                Text("BIRTH PLACE")
                    .font(.spaceMono(11))
                    .tracking(0.88)
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))

                    TextField("Search city or country", text: $searchQuery)
                        .font(.interRegular(16))
                        .autocorrectionDisabled()
                        .onChange(of: searchQuery) { _, newValue in
                            Task {
                                await performSearch(newValue)
                            }
                        }
                }
                .padding(.horizontal, ENVISpacing.md)
                .padding(.vertical, ENVISpacing.md)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.md)
                        .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1.5)
                )
            }

            // Selected City Display
            if let selected = viewModel.birthPlace {
                VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                            Text(selected.name)
                                .font(.interRegular(16))
                                .foregroundColor(ENVITheme.text(for: colorScheme))
                            Text(selected.country)
                                .font(.interRegular(13))
                                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ENVITheme.primary(for: colorScheme))
                    }
                    .padding(ENVISpacing.md)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                }
            }

            // Search Results
            if !searchResults.isEmpty {
                VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                    ForEach(searchResults, id: \.self) { city in
                        Button(action: {
                            viewModel.birthPlace = city
                            searchQuery = ""
                            searchResults = []
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                                    Text(city.name)
                                        .font(.interRegular(16))
                                        .foregroundColor(ENVITheme.text(for: colorScheme))
                                    Text(city.country)
                                        .font(.interRegular(13))
                                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                                }
                                Spacer()
                            }
                            .padding(ENVISpacing.md)
                            .background(ENVITheme.surfaceLow(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                        }
                    }
                }
            }

            // Loading Indicator
            if isSearching {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8, anchor: .center)
                    Text("Searching…")
                        .font(.interRegular(14))
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                }
            }

            Spacer()
        }
    }

    // MARK: - Search

    private func performSearch(_ query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        searchError = nil

        do {
            let results = try await citySearchClient.search(query)
            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        } catch {
            await MainActor.run {
                searchError = error.localizedDescription
                searchResults = []
                isSearching = false
            }
        }
    }
}
