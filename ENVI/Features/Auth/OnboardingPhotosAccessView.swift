import SwiftUI
import UIKit

/// Request full photo library access during onboarding.
struct OnboardingPhotosAccessView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @ObservedObject private var photoLibraryManager = PhotoLibraryManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    /// Phase 5 — Task 4: after the user grants full access we present a
    /// full-screen progress cover that runs the onboarding scan batch.
    /// The cover's `onContinue` dismisses and advances onboarding via the
    /// existing `viewModel.goToNextStep()` path.
    @State private var showTemplateProgress: Bool = false
    @State private var hasPresentedProgress: Bool = false
    @State private var scanCoordinator: MediaScanCoordinator?

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
        .onChange(of: photoLibraryManager.authorizationStatus) { _, newStatus in
            maybePresentProgress(for: newStatus)
        }
        .fullScreenCover(isPresented: $showTemplateProgress) {
            if let scanCoordinator {
                TemplateOnboardingProgressView(scanner: scanCoordinator) {
                    showTemplateProgress = false
                    viewModel.goToNextStep()
                }
            }
        }
    }

    /// Presents the Template onboarding progress cover exactly once, the
    /// first time we observe a fully-authorized Photos status after the
    /// user taps through the permission flow. If the user is already
    /// authorized on appear (revisiting the step) we skip the cover —
    /// the background scan will still run via the Template tab's
    /// lazy rescan.
    private func maybePresentProgress(for status: PhotoLibraryManager.AuthorizationStatus) {
        guard status.isFullyAuthorized else { return }
        guard !hasPresentedProgress else { return }
        hasPresentedProgress = true

        let cache: ClassificationCache = {
            if let onDisk = try? ClassificationCache() { return onDisk }
            // swiftlint:disable:next force_try
            return try! ClassificationCache(inMemory: true)
        }()
        let scanner = MediaScanCoordinator(
            classifier: MediaClassifier.shared,
            cache: cache
        )
        scanCoordinator = scanner
        showTemplateProgress = true
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
