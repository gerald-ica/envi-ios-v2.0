import SwiftUI
import MapKit

/// Step 6: Where were you born? + city autocomplete + popular chips.
struct OnboardingWhereBornView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @StateObject private var citySearch = CitySearchCompleter()
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            Text("WHERE WERE YOU BORN?")
                .font(.spaceMonoBold(32))
                .tracking(-2.0)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Your roots shape your perspective.")
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                ENVIInput(
                    label: "City",
                    placeholder: "Enter your birthplace",
                    text: $viewModel.birthplace
                )
                .focused($isSearchFocused)
                .onChange(of: viewModel.birthplace) { _, newValue in
                    citySearch.search(newValue)
                    if viewModel.selectedBirthplace != newValue {
                        viewModel.selectedBirthplace = nil
                    }
                }

                if isSearchFocused
                    && !citySearch.suggestions.isEmpty
                    && viewModel.selectedBirthplace == nil {
                    VStack(spacing: 0) {
                        ForEach(citySearch.suggestions.prefix(5), id: \.self) { suggestion in
                            Button {
                                let city = suggestion.title
                                let full = suggestion.subtitle.isEmpty
                                    ? city
                                    : "\(city), \(suggestion.subtitle)"
                                viewModel.birthplace = full
                                viewModel.selectedBirthplace = full
                                isSearchFocused = false
                            } label: {
                                HStack(spacing: ENVISpacing.md) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(ENVITheme.textLight(for: colorScheme))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(suggestion.title)
                                            .font(.interSemiBold(15))
                                            .foregroundColor(ENVITheme.text(for: colorScheme))

                                        if !suggestion.subtitle.isEmpty {
                                            Text(suggestion.subtitle)
                                                .font(.interRegular(12))
                                                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, ENVISpacing.lg)
                                .padding(.vertical, ENVISpacing.md)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.lg)
                            .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                    )
                }
            }

            VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                Text("POPULAR")
                    .font(.spaceMono(11))
                    .tracking(0.88)
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))

                FlowLayout(spacing: ENVISpacing.sm) {
                    ForEach(viewModel.birthplaceChips, id: \.self) { city in
                        ENVIChip(
                            title: city,
                            isSelected: viewModel.selectedBirthplace == city
                        ) {
                            viewModel.selectedBirthplace = city
                            viewModel.birthplace = city
                            isSearchFocused = false
                        }
                    }
                }
            }

            Spacer()
        }
    }
}
