import SwiftUI

/// USM-specific 4-screen onboarding coordinator.
/// Manages the flow: name → DOB+time → birth place → current location.
struct USMOnboardingCoordinator: View {
    @State private var viewModel: USMOnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    let onComplete: () -> Void
    let citySearchClient: CitySearchClientProtocol

    init(
        userId: String,
        recomputeClient: USMRecomputeClientProtocol,
        citySearchClient: CitySearchClientProtocol,
        onComplete: @escaping () -> Void
    ) {
        self.citySearchClient = citySearchClient
        self.onComplete = onComplete
        self._viewModel = State(initialValue: USMOnboardingViewModel(
            userId: userId,
            recomputeClient: recomputeClient
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Bar (hidden on loading)
            if viewModel.step != .loading {
                HStack {
                    // Back button
                    if viewModel.step.rawValue > 0 {
                        Button(action: { viewModel.goToPreviousStep() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(ENVITheme.text(for: colorScheme))
                        }
                    } else {
                        Spacer().frame(width: 24)
                    }

                    Spacer()

                    // Progress bar (4 steps)
                    HStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(progressSegmentColor(for: index))
                                .frame(height: 3)
                        }
                    }
                    .frame(maxWidth: 180)

                    Spacer()
                    Spacer().frame(width: 24)
                }
                .padding(.horizontal, ENVISpacing.xl)
                .padding(.vertical, ENVISpacing.md)
            }

            // MARK: - Step Content
            if viewModel.step == .loading {
                loadingView
            } else {
                TabView(selection: $viewModel.step) {
                    USMOnboardingNameView(viewModel: viewModel)
                        .tag(USMOnboardingViewModel.Step.name)
                        .padding(.horizontal, ENVISpacing.xl)

                    USMOnboardingDOBView(viewModel: viewModel)
                        .tag(USMOnboardingViewModel.Step.dateAndTime)
                        .padding(.horizontal, ENVISpacing.xl)

                    USMOnboardingBirthPlaceView(
                        viewModel: viewModel,
                        citySearchClient: citySearchClient
                    )
                    .tag(USMOnboardingViewModel.Step.birthPlace)
                    .padding(.horizontal, ENVISpacing.xl)

                    USMOnboardingCurrentLocationView(
                        viewModel: viewModel,
                        citySearchClient: citySearchClient
                    )
                    .tag(USMOnboardingViewModel.Step.currentLocation)
                    .padding(.horizontal, ENVISpacing.xl)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: viewModel.step)
            }

            // MARK: - Continue Button (hidden on loading)
            if viewModel.step != .loading {
                ENVIButton(
                    viewModel.step == .currentLocation ? "Get Started" : "Continue",
                    isEnabled: viewModel.canContinue
                ) {
                    if viewModel.step == .currentLocation {
                        Task {
                            do {
                                try await viewModel.submit()
                                // Wait briefly for loading state, then call onComplete
                                try await Task.sleep(nanoseconds: 500_000_000)
                                onComplete()
                            } catch {
                                // Error is set in viewModel
                            }
                        }
                    } else {
                        viewModel.goToNextStep()
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
                .padding(.bottom, ENVISpacing.xxxl)
            }
        }
        .background(ENVITheme.background(for: colorScheme))
    }

    // MARK: - Loading View

    private var loadingView: some View {
        USMOnboardingLoadingView()
    }

    // MARK: - Helpers

    private func progressSegmentColor(for index: Int) -> Color {
        if index < viewModel.step.rawValue {
            return ENVITheme.primary(for: colorScheme)
        } else if index == viewModel.step.rawValue {
            return ENVITheme.primary(for: colorScheme)
        } else {
            return ENVITheme.surfaceHigh(for: colorScheme)
        }
    }
}
