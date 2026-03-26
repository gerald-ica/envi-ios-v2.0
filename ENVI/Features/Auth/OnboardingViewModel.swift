import SwiftUI
import Combine

/// Manages state for the 5-step onboarding flow.
final class OnboardingViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case name = 0
        case dateOfBirth
        case whereFrom
        case whereBorn
        case socials
    }

    // MARK: - Navigation
    @Published var currentStep: Step = .name
    @Published var isComplete = false

    // MARK: - Step 1: Name
    @Published var firstName = ""
    @Published var lastName = ""

    // MARK: - Step 2: Date of Birth
    @Published var dobMonth = ""
    @Published var dobDay = ""
    @Published var dobYear = ""

    // MARK: - Step 3: Where From
    @Published var location = ""
    @Published var selectedLocation: String?

    // MARK: - Step 4: Where Born
    @Published var birthplace = ""
    @Published var selectedBirthplace: String?

    // MARK: - Step 5: Socials
    @Published var instagramEnabled = false
    @Published var tiktokEnabled = false
    @Published var xEnabled = false
    @Published var threadsEnabled = false
    @Published var linkedinEnabled = false

    // MARK: - Validation
    var isNameValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var isDOBValid: Bool {
        let m = Int(dobMonth) ?? 0
        let d = Int(dobDay) ?? 0
        let y = Int(dobYear) ?? 0
        return (1...12).contains(m) && (1...31).contains(d) && (1900...2010).contains(y)
    }

    var isWhereFromValid: Bool {
        !location.trimmingCharacters(in: .whitespaces).isEmpty || selectedLocation != nil
    }

    var isWhereBornValid: Bool {
        !birthplace.trimmingCharacters(in: .whitespaces).isEmpty || selectedBirthplace != nil
    }

    var canContinue: Bool {
        switch currentStep {
        case .name: return isNameValid
        case .dateOfBirth: return isDOBValid
        case .whereFrom: return isWhereFromValid
        case .whereBorn: return isWhereBornValid
        case .socials: return true
        }
    }

    var progress: Double {
        Double(currentStep.rawValue + 1) / Double(Step.allCases.count)
    }

    // MARK: - Chip Data
    let locationChips = ["Los Angeles", "New York", "Miami", "London", "Paris", "Tokyo"]
    let birthplaceChips = ["Los Angeles", "New York", "Miami", "London", "Chicago", "Houston"]

    // MARK: - Actions
    func goToNextStep() {
        guard let nextIndex = Step(rawValue: currentStep.rawValue + 1) else {
            completeOnboarding()
            return
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = nextIndex
        }
    }

    func goToPreviousStep() {
        guard let prevIndex = Step(rawValue: currentStep.rawValue - 1) else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = prevIndex
        }
    }

    func skip() {
        completeOnboarding()
    }

    private func completeOnboarding() {
        UserDefaultsManager.shared.hasCompletedOnboarding = true
        UserDefaultsManager.shared.userName = "\(firstName) \(lastName)"
        isComplete = true
    }
}
