import SwiftUI
import CoreLocation

/// Step 4: Current location selection via city search or device location for USM onboarding.
struct USMOnboardingCurrentLocationView: View {
    @Bindable var viewModel: USMOnboardingViewModel
    @State private var searchQuery: String = ""
    @State private var searchResults: [USMCity] = []
    @State private var isSearching: Bool = false
    @State private var searchError: String?
    @State private var locationManager: CLLocationManager?
    @State private var isLocating: Bool = false

    let citySearchClient: CitySearchClientProtocol

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            Text("WHERE ARE YOU NOW?")
                .font(.spaceMonoBold(32))
                .tracking(-2.0)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("We'll use this to personalize your cosmic insights.")
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            // Use Current Location Button
            Button(action: {
                Task {
                    await useCurrentLocation()
                }
            }) {
                HStack(spacing: ENVISpacing.md) {
                    Image(systemName: "location.fill")
                    Text("Use My Current Location")
                        .font(.interRegular(15))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ENVISpacing.md)
                .foregroundColor(colorScheme == .dark ? .black : .white)
                .background(ENVITheme.primary(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            }
            .disabled(isLocating)

            Text("or search below")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .center)

            // Search Field
            VStack(alignment: .leading, spacing: ENVISpacing.md) {
                Text("CURRENT LOCATION")
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

            // Selected Location Display
            if let selected = viewModel.currentLocation {
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
                            viewModel.currentLocation = city
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

            if isLocating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8, anchor: .center)
                    Text("Getting your location…")
                        .font(.interRegular(14))
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                }
            }

            Spacer()
        }
        .onAppear {
            initializeLocationManager()
        }
    }

    // MARK: - Location Services

    private func initializeLocationManager() {
        let manager = CLLocationManager()
        self.locationManager = manager
    }

    private func useCurrentLocation() async {
        guard let locationManager = locationManager else { return }

        isLocating = true

        let status = locationManager.authorizationStatus

        // Request permission if needed
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            // Wait for authorization callback
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        let finalStatus = locationManager.authorizationStatus
        guard finalStatus == .authorizedWhenInUse || finalStatus == .authorizedAlways else {
            isLocating = false
            searchError = "Location permission denied"
            return
        }

        // Get current location (locationManager is already unwrapped above)
        if let location = locationManager.location {
            do {
                let city = try await citySearchClient.reverseGeocode(
                    lat: location.coordinate.latitude,
                    lon: location.coordinate.longitude
                )
                if let city = city {
                    await MainActor.run {
                        viewModel.currentLocation = city
                        isLocating = false
                    }
                } else {
                    await MainActor.run {
                        searchError = "Could not find location name"
                        isLocating = false
                    }
                }
            } catch {
                await MainActor.run {
                    searchError = error.localizedDescription
                    isLocating = false
                }
            }
        } else {
            isLocating = false
            searchError = "Could not get device location"
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
