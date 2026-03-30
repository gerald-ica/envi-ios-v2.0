import SwiftUI
import Combine

/// Manages state for the onboarding flow.
final class OnboardingViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case name = 0
        case dateOfBirth
        case birthTime
        case whereFrom
        case photosAccess
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
    @Published var hasEditedDOB = false
    @Published var dateOfBirth = Date()

    // MARK: - Step 3: Birth Time
    @Published var hasEditedBirthTime = false
    @Published var birthTime = OnboardingViewModel.makeDate(year: 2000, month: 1, day: 1, hour: 12, minute: 0)

    // MARK: - Step 4: Where From
    @Published var location = ""
    @Published var selectedLocation: String?
    @Published var locationAuthorizationStatus: LocationPermissionManager.AuthorizationStatus = LocationPermissionManager.shared.authorizationStatus

    // MARK: - Step 5: Photos Access
    @Published var photoAuthorizationStatus: PhotoLibraryManager.AuthorizationStatus = PhotoLibraryManager.shared.authorizationStatus

    // MARK: - Step 6: Where Born
    @Published var birthplace = ""
    @Published var selectedBirthplace: String?

    // MARK: - Step 7: Socials
    @Published var instagramEnabled = false
    @Published var tiktokEnabled = false
    @Published var xEnabled = false
    @Published var threadsEnabled = false
    @Published var linkedinEnabled = false

    private var cancellables: Set<AnyCancellable> = []

    init() {
        LocationPermissionManager.shared.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.locationAuthorizationStatus = status
            }
            .store(in: &cancellables)

        LocationPermissionManager.shared.$currentLocationName
            .receive(on: DispatchQueue.main)
            .sink { [weak self] locationName in
                guard let self, let locationName else { return }
                self.location = locationName
                self.selectedLocation = locationName
            }
            .store(in: &cancellables)

        PhotoLibraryManager.shared.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.photoAuthorizationStatus = status
            }
            .store(in: &cancellables)
    }

    // MARK: - Validation
    var isNameValid: Bool {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespaces)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespaces)
        return !trimmedFirst.isEmpty && trimmedFirst.count <= 50 &&
               !trimmedLast.isEmpty && trimmedLast.count <= 50
    }

    var isDOBValid: Bool {
        hasEditedDOB && birthDateRange.contains(dateOfBirth)
    }

    var isBirthTimeValid: Bool {
        // Birth time is optional — always valid (user can skip this step)
        true
    }

    var isWhereFromValid: Bool {
        locationAuthorizationStatus.isAuthorized
    }

    var isPhotosAccessValid: Bool {
        photoAuthorizationStatus.isFullyAuthorized
    }

    var isWhereBornValid: Bool {
        !birthplace.trimmingCharacters(in: .whitespaces).isEmpty || selectedBirthplace != nil
    }

    var canContinue: Bool {
        switch currentStep {
        case .name: return isNameValid
        case .dateOfBirth: return isDOBValid
        case .birthTime: return isBirthTimeValid
        case .whereFrom: return isWhereFromValid
        case .photosAccess: return isPhotosAccessValid
        case .whereBorn: return isWhereBornValid
        case .socials: return true
        }
    }

    var canSkipCurrentStep: Bool {
        currentStep == .birthTime
    }

    var progress: Double {
        Double(currentStep.rawValue + 1) / Double(Step.allCases.count)
    }

    // MARK: - Chip Data
    let locationChips = ["Los Angeles", "New York", "Miami", "London", "Paris", "Tokyo"]
    let birthplaceChips = ["Los Angeles", "New York", "Miami", "London", "Chicago", "Houston"]

    var birthDateRange: ClosedRange<Date> {
        Self.makeDate(year: 1900, month: 1, day: 1)...Self.makeDate(year: 2010, month: 12, day: 31, hour: 23, minute: 59)
    }

    var formattedBirthDate: String {
        Self.dateFormatter.string(from: dateOfBirth)
    }

    var formattedBirthTime: String? {
        guard hasEditedBirthTime else { return nil }
        return Self.timeFormatter.string(from: birthTime)
    }

    var locationStatusTitle: String {
        switch locationAuthorizationStatus {
        case .notDetermined:
            return "Location access is off"
        case .authorizedWhenInUse, .authorizedAlways:
            return "Location access is on"
        case .denied:
            return "Location access was denied"
        case .restricted:
            return "Location access is restricted"
        }
    }

    var locationStatusDetail: String {
        switch locationAuthorizationStatus {
        case .notDetermined:
            return "Turn on location so ENVI can personalize content for where you are."
        case .authorizedWhenInUse, .authorizedAlways:
            return location.isEmpty ? "We have access to your location." : "Current location: \(location)"
        case .denied:
            return "Open Settings and allow location access to continue."
        case .restricted:
            return "Location access is restricted on this device."
        }
    }

    var photoStatusTitle: String {
        switch photoAuthorizationStatus {
        case .notDetermined:
            return "Photo access is off"
        case .authorized:
            return "Full photo access is on"
        case .limited:
            return "Only limited photo access is on"
        case .denied:
            return "Photo access was denied"
        case .restricted:
            return "Photo access is restricted"
        }
    }

    var photoStatusDetail: String {
        switch photoAuthorizationStatus {
        case .notDetermined:
            return "Allow full access so ENVI can work with your full library during setup."
        case .authorized:
            return "ENVI has full access to your photo library."
        case .limited:
            return "ENVI needs full access, not limited selection. Open Settings and change Photos to Full Access."
        case .denied:
            return "Open Settings and allow Full Access to Photos to continue."
        case .restricted:
            return "Photo access is restricted on this device."
        }
    }

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
        guard canSkipCurrentStep else { return }
        hasEditedBirthTime = false
        goToNextStep()
    }

    private func completeOnboarding() {
        let defaults = UserDefaultsManager.shared
        defaults.hasCompletedOnboarding = true
        defaults.userName = "\(firstName.trimmingCharacters(in: .whitespaces)) \(lastName.trimmingCharacters(in: .whitespaces))".trimmingCharacters(in: .whitespaces)
        defaults.userDOB = formattedBirthDate
        defaults.userBirthTime = formattedBirthTime
        defaults.userLocation = selectedLocation ?? location.trimmingCharacters(in: .whitespaces)
        defaults.userBirthplace = selectedBirthplace ?? birthplace.trimmingCharacters(in: .whitespaces)
        defaults.connectedPlatforms = connectedPlatforms
        isComplete = true
    }

    private var connectedPlatforms: [String] {
        [
            instagramEnabled ? "Instagram" : nil,
            tiktokEnabled ? "TikTok" : nil,
            xEnabled ? "X" : nil,
            threadsEnabled ? "Threads" : nil,
            linkedinEnabled ? "LinkedIn" : nil,
        ].compactMap { $0 }
    }

    private static func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date ?? Date()
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}
