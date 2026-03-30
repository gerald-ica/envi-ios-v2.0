import SwiftUI

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
                    .accessibilityLabel("Go back")
                } else {
                    Spacer().frame(width: 24)
                }

                Spacer()

                // Progress bar
                ProgressBarView(
                    totalSteps: OnboardingViewModel.Step.allCases.count,
                    currentStep: viewModel.currentStep.rawValue
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Step \(viewModel.currentStep.rawValue + 1) of \(OnboardingViewModel.Step.allCases.count)")

                Spacer()

                // Skip
                if viewModel.canSkipCurrentStep {
                    Button("Skip for now") {
                        viewModel.skip()
                    }
                    .font(.spaceMonoBold(13))
                    .tracking(1.5)
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
                    .accessibilityHint("Skips this optional step")
                } else {
                    Spacer().frame(width: 88)
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
            .padding(.vertical, ENVISpacing.md)

            // MARK: - Step Content
            Group {
                switch viewModel.currentStep {
                case .name:
                    OnboardingNameView(viewModel: viewModel)
                case .dateOfBirth:
                    OnboardingDOBView(viewModel: viewModel)
                case .birthTime:
                    OnboardingBirthTimeView(viewModel: viewModel)
                case .whereFrom:
                    OnboardingWhereFromView(viewModel: viewModel)
                case .photosAccess:
                    OnboardingPhotosAccessView(viewModel: viewModel)
                case .whereBorn:
                    OnboardingWhereBornView(viewModel: viewModel)
                case .socials:
                    OnboardingSocialsView(viewModel: viewModel)
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            return ENVITheme.primary(for: colorScheme).opacity(0.4)
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

    func start() {
        let onboardingView = OnboardingContainerView(onComplete: { [weak self] in
            self?.onComplete?()
        })
        let hostingController = UIHostingController(rootView: onboardingView)
        hostingController.view.backgroundColor = ENVITheme.UIKit.background
        navigationController?.setViewControllers([hostingController], animated: true)
    }
}
