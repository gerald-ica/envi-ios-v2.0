import SwiftUI
import CryptoKit
import Foundation

/// Container view that manages the onboarding navigation flow.
struct OnboardingContainerView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var onComplete: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Bar
            HStack {
                // Back button
                if viewModel.currentStep.rawValue > 0 {
                    Button(action: { viewModel.goToPreviousStep() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                    }
                } else {
                    Spacer().frame(width: 24)
                }

                Spacer()

                // Progress bar
                ProgressBarView(
                    totalSteps: OnboardingViewModel.Step.allCases.count,
                    currentStep: viewModel.currentStep.rawValue
                )

                Spacer()

                // Skip
                if viewModel.canSkipCurrentStep {
                    Button("Skip for now") {
                        viewModel.skip()
                    }
                    .font(.spaceMonoBold(13))
                    .tracking(1.5)
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
                } else {
                    Spacer().frame(width: 88)
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
            .padding(.vertical, ENVISpacing.md)

            // MARK: - Step Content
            TabView(selection: $viewModel.currentStep) {
                OnboardingNameView(viewModel: viewModel)
                    .tag(OnboardingViewModel.Step.name)
                    .padding(.horizontal, ENVISpacing.xl)

                OnboardingDOBView(viewModel: viewModel)
                    .tag(OnboardingViewModel.Step.dateOfBirth)
                    .padding(.horizontal, ENVISpacing.xl)

                OnboardingBirthTimeView(viewModel: viewModel)
                    .tag(OnboardingViewModel.Step.birthTime)
                    .padding(.horizontal, ENVISpacing.xl)

                OnboardingWhereFromView(viewModel: viewModel)
                    .tag(OnboardingViewModel.Step.whereFrom)
                    .padding(.horizontal, ENVISpacing.xl)

                OnboardingPhotosAccessView(viewModel: viewModel)
                    .tag(OnboardingViewModel.Step.photosAccess)
                    .padding(.horizontal, ENVISpacing.xl)

                OnboardingWhereBornView(viewModel: viewModel)
                    .tag(OnboardingViewModel.Step.whereBorn)
                    .padding(.horizontal, ENVISpacing.xl)

                OnboardingSocialsView(viewModel: viewModel)
                    .tag(OnboardingViewModel.Step.socials)
                    .padding(.horizontal, ENVISpacing.xl)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: viewModel.currentStep)

            // MARK: - Continue Button
            ENVIButton(
                viewModel.currentStep == .socials ? "Get Started" : "Continue",
                isEnabled: viewModel.canContinue
            ) {
                viewModel.goToNextStep()
            }
            .padding(.horizontal, ENVISpacing.xl)
            .padding(.bottom, ENVISpacing.xxxl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .onChange(of: viewModel.isComplete) { _, isComplete in
            if isComplete { onComplete?() }
        }
        .task {
            // Seed an anonymous Firebase identity at the start of
            // onboarding so the socials step's OAuth broker calls have
            // a valid UID to bind connections to. Idempotent — returns
            // immediately if a user is already signed in (e.g. returning
            // from background, or onboarding re-entered after partial
            // sign-in).
            await AuthManager.shared.bootstrapAnonymousIfNeeded()
        }
    }
}

// MARK: - Progress Bar
private struct ProgressBarView: View {
    let totalSteps: Int
    let currentStep: Int

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(segmentColor(for: index))
                    .frame(height: 3)
            }
        }
        .frame(maxWidth: 180)
    }

    private func segmentColor(for index: Int) -> Color {
        if index < currentStep {
            return ENVITheme.primary(for: colorScheme)
        } else if index == currentStep {
            return ENVITheme.primary(for: colorScheme)
        } else {
            return ENVITheme.surfaceHigh(for: colorScheme)
        }
    }
}

/// UIKit coordinator that wraps the SwiftUI onboarding container.
final class OnboardingCoordinator {
    private weak var navigationController: UINavigationController?
    var onComplete: (() -> Void)?

    init(navigationController: UINavigationController?) {
        self.navigationController = navigationController
    }

    @MainActor
    func start() {
        let useUSM = USMOnboardingEntry.shouldUse
        let hostingController: UIHostingController<AnyView>

        if useUSM {
            let debugUserId = "1588858d-ae9f-4020-bff1-bd29e04a5a65"
            let staging = URL(string: "https://envious-brain-api-uxgej3n6ta-uc.a.run.app")!
            let recomputeClient = USMRecomputeClient(
                baseURL: staging,
                authTokenProvider: { Self.mintDebugJWT(userId: debugUserId) }
            )
            let citySearchClient = CitySearchClient(baseURL: staging)

            let usmView = USMOnboardingEntry.makeView(
                userId: debugUserId,
                recomputeClient: recomputeClient,
                citySearchClient: citySearchClient,
                onComplete: { [weak self] in self?.onComplete?() }
            )
            hostingController = UIHostingController(rootView: AnyView(usmView))
        } else {
            let onboardingView = OnboardingContainerView(onComplete: { [weak self] in
                self?.onComplete?()
            })
            hostingController = UIHostingController(rootView: AnyView(onboardingView))
        }

        hostingController.view.backgroundColor = ENVITheme.UIKit.backgroundDark
        navigationController?.setViewControllers([hostingController], animated: true)
    }

    /// TODO(gerald): remove before release. Debug-only HS256 JWT minter that
    /// signs with the same literal secret the staging brain service currently
    /// uses. This whole codepath should be replaced by a proper
    /// Firebase-token → backend-JWT exchange once the mapping endpoint exists.
    private static func mintDebugJWT(userId: String) -> String {
        let header = #"{"alg":"HS256","typ":"JWT"}"#
        let now = Int(Date().timeIntervalSince1970)
        let payload = #"{"sub":"\#(userId)","tier":"free","scopes":[],"iat":\#(now),"exp":\#(now + 3600),"token_type":"access"}"#
        let h = Data(header.utf8).base64URLEncodedString()
        let p = Data(payload.utf8).base64URLEncodedString()
        let signingInput = "\(h).\(p)"
        let key = SymmetricKey(data: Data("change-me-in-production".utf8))
        let sig = HMAC<SHA256>.authenticationCode(for: Data(signingInput.utf8), using: key)
        let s = Data(sig).base64URLEncodedString()
        return "\(h).\(p).\(s)"
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
