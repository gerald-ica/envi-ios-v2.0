import SwiftUI

/// Container view that manages the 5-step onboarding navigation flow.
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
                Button("Skip") {
                    viewModel.skip()
                }
                .font(.interMedium(15))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))
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

                OnboardingWhereFromView(viewModel: viewModel)
                    .tag(OnboardingViewModel.Step.whereFrom)
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

    func start() {
        let onboardingView = OnboardingContainerView(onComplete: { [weak self] in
            self?.onComplete?()
        })
        let hostingController = UIHostingController(rootView: onboardingView)
        hostingController.view.backgroundColor = ENVITheme.UIKit.backgroundDark
        navigationController?.setViewControllers([hostingController], animated: true)
    }
}
