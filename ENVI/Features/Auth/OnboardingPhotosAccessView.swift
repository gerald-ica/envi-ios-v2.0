import SwiftUI
import UIKit

/// Request full photo library access during onboarding.
struct OnboardingPhotosAccessView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @ObservedObject private var photoLibraryManager = PhotoLibraryManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            Text("TURN ON FULL PHOTO ACCESS")
                .font(.spaceMonoBold(32))
                .tracking(-2.0)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("We use your full photo library to help assemble and manage your content during onboarding.")
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            VStack(alignment: .leading, spacing: ENVISpacing.lg) {
                statusCard

                ENVIButton(primaryActionTitle) {
                    handlePrimaryAction()
                }

                if needsSettingsAction {
                    ENVIButton("Open Settings", variant: .secondary) {
                        openSettings()
                    }
                }
            }

            Spacer()
        }
        .onAppear {
            photoLibraryManager.refreshAuthorizationStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                photoLibraryManager.refreshAuthorizationStatus()
            }
        }
    }

    private var primaryActionTitle: String {
        switch photoLibraryManager.authorizationStatus {
        case .notDetermined:
            return "Allow Full Access"
        case .authorized:
            return "Refresh Photo Access"
        case .limited, .denied:
            return "Open Settings"
        case .restricted:
            return "Photos Restricted"
        }
    }

    private var needsSettingsAction: Bool {
        switch photoLibraryManager.authorizationStatus {
        case .limited, .denied:
            return true
        case .notDetermined, .authorized, .restricted:
            return false
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("PHOTOS")
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            Text(viewModel.photoStatusTitle)
                .font(.interSemiBold(17))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text(viewModel.photoStatusDetail)
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
        switch photoLibraryManager.authorizationStatus {
        case .notDetermined:
            Task {
                _ = await PhotoLibraryManager.requestAuthorization()
            }
        case .authorized:
            photoLibraryManager.refreshAuthorizationStatus()
        case .limited, .denied:
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
