import SwiftUI
import UIKit

/// Step 4: Request the user's phone location.
struct OnboardingWhereFromView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @ObservedObject private var locationManager = LocationPermissionManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            Text("TURN ON YOUR LOCATION")
                .font(.spaceMonoBold(32))
                .tracking(-2.0)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("We use your phone location to tailor content and recommendations to where you are.")
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            VStack(alignment: .leading, spacing: ENVISpacing.lg) {
                statusCard

                ENVIButton(primaryActionTitle) {
                    handlePrimaryAction()
                }
            }

            Spacer()
        }
        .onAppear {
            if locationManager.authorizationStatus.isAuthorized {
                locationManager.requestCurrentLocation()
            }
        }
    }

    private var primaryActionTitle: String {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return "Allow Location"
        case .authorizedWhenInUse, .authorizedAlways:
            return "Refresh Location"
        case .denied:
            return "Open Settings"
        case .restricted:
            return "Location Restricted"
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("LOCATION")
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            Text(viewModel.locationStatusTitle)
                .font(.interSemiBold(17))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text(viewModel.locationStatusDetail)
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ENVISpacing.lg)
        .padding(.vertical, ENVISpacing.xl)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1.5)
        )
    }

    private func handlePrimaryAction() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestCurrentLocation()
        case .denied:
            openSettings()
        case .restricted:
            break
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
