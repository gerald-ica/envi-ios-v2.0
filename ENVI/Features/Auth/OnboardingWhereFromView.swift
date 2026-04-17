import SwiftUI
import UIKit
import MapKit

/// Step 4: Where are you from — location permission + city autocomplete.
struct OnboardingWhereFromView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @ObservedObject private var locationManager = LocationPermissionManager.shared
    @StateObject private var citySearch = LocalCitySearchCompleter()
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            Text("WHERE ARE YOU FROM?")
                .font(.spaceMonoBold(32))
                .tracking(-2.0)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("We use your location to tailor content and recommendations to where you are.")
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            // City input with autocomplete
            VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                ENVIInput(
                    label: "City",
                    placeholder: "Start typing your city...",
                    text: $viewModel.location
                )
                .focused($isSearchFocused)
                .onChange(of: viewModel.location) { _, newValue in
                    citySearch.search(newValue)
                    // Clear selection if user edits after selecting
                    if viewModel.selectedLocation != newValue {
                        viewModel.selectedLocation = nil
                    }
                }

                // Autocomplete suggestions
                if isSearchFocused && !citySearch.suggestions.isEmpty && viewModel.selectedLocation == nil {
                    VStack(spacing: 0) {
                        ForEach(citySearch.suggestions.prefix(5), id: \.self) { suggestion in
                            Button {
                                let city = suggestion.title
                                let full = suggestion.subtitle.isEmpty
                                    ? city
                                    : "\(city), \(suggestion.subtitle)"
                                viewModel.location = full
                                viewModel.selectedLocation = full
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

            // Popular chips
            VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                Text("POPULAR")
                    .font(.spaceMono(11))
                    .tracking(0.88)
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))

                FlowLayout(spacing: ENVISpacing.sm) {
                    ForEach(viewModel.locationChips, id: \.self) { city in
                        ENVIChip(
                            title: city,
                            isSelected: viewModel.selectedLocation == city
                        ) {
                            viewModel.selectedLocation = city
                            viewModel.location = city
                            isSearchFocused = false
                        }
                    }
                }
            }

            // Location permission button (secondary)
            if !locationManager.authorizationStatus.isAuthorized {
                Button(action: requestLocation) {
                    HStack(spacing: ENVISpacing.sm) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                        Text("Use My Current Location")
                            .font(.interSemiBold(14))
                    }
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ENVISpacing.lg)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.lg)
                            .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else if let locationName = locationManager.currentLocationName, !locationName.isEmpty {
                Button {
                    viewModel.location = locationName
                    viewModel.selectedLocation = locationName
                } label: {
                    HStack(spacing: ENVISpacing.sm) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                        Text("Use: \(locationName)")
                            .font(.interSemiBold(14))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, ENVISpacing.lg)
                    .padding(.vertical, ENVISpacing.lg)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.lg)
                            .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .onAppear {
            if locationManager.authorizationStatus.isAuthorized {
                locationManager.requestCurrentLocation()
            }
        }
    }

    private func requestLocation() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestAuthorization()
        } else if locationManager.authorizationStatus == .denied {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }
}

private final class LocalCitySearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func search(_ query: String) {
        guard query.count >= 2 else {
            suggestions = []
            return
        }
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }
}

