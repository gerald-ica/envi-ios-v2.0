import Foundation
import Observation

/// City data for birth place and current location selection.
public struct USMCity: Codable, Sendable, Hashable {
    public let name: String
    public let country: String
    public let timezone: String
    public let lat: Double
    public let lon: Double

    public init(name: String, country: String, timezone: String, lat: Double, lon: Double) {
        self.name = name
        self.country = country
        self.timezone = timezone
        self.lat = lat
        self.lon = lon
    }
}

/// Protocol for fetching cities from search client.
public protocol CitySearchClientProtocol: Sendable {
    func search(_ query: String) async throws -> [USMCity]
    func reverseGeocode(lat: Double, lon: Double) async throws -> USMCity?
}

/// Protocol for recomputing the USM on the server.
public protocol USMRecomputeClientProtocol: Sendable {
    func recompute(userId: String, request: USMRecomputeRequest) async throws -> USMRecomputeResponse
}

public struct USMRecomputeRequest: Encodable {
    public let firstName: String
    public let lastName: String?
    public let dateOfBirth: String
    public let timeOfBirth: String?
    public let birthPlace: USMCity
    public let currentLocation: USMCity

    public init(
        firstName: String,
        lastName: String?,
        dateOfBirth: String,
        timeOfBirth: String?,
        birthPlace: USMCity,
        currentLocation: USMCity
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.timeOfBirth = timeOfBirth
        self.birthPlace = birthPlace
        self.currentLocation = currentLocation
    }
}

public struct USMRecomputeResponse: Decodable {
    public let status: String
    public let modelVersion: Int
    public let recomputationStartedAt: String
    public let recomputationCompletedAt: String
}

/// Main view model for the 4-screen USM onboarding flow.
@MainActor
@Observable
public final class USMOnboardingViewModel {

    public enum Step: Int, CaseIterable {
        case name = 0
        case dateAndTime = 1
        case birthPlace = 2
        case currentLocation = 3
        case loading = 4
    }

    // MARK: - Input State

    public var firstName: String = ""
    public var lastName: String = ""
    public var dateOfBirth: Date = Date()
    public var hasKnownBirthTime: Bool = false
    public var timeOfBirth: Date = Date()
    public var birthPlace: USMCity?
    public var currentLocation: USMCity?

    // MARK: - Navigation State

    public var step: Step = .name
    public var isSubmitting: Bool = false
    public var submitError: String?

    // MARK: - Dependencies

    private let recomputeClient: USMRecomputeClientProtocol
    private let userId: String

    // MARK: - Init

    public init(userId: String, recomputeClient: USMRecomputeClientProtocol) {
        self.userId = userId
        self.recomputeClient = recomputeClient
    }

    // MARK: - Computed Properties

    public var canContinue: Bool {
        switch step {
        case .name:
            return !firstName.trimmingCharacters(in: .whitespaces).isEmpty
        case .dateAndTime:
            return !dateOfBirth.isSameDay(as: Date.distantFuture)
        case .birthPlace:
            return birthPlace != nil
        case .currentLocation:
            return currentLocation != nil
        case .loading:
            return false
        }
    }

    // MARK: - Navigation

    public func goToNextStep() {
        guard step != .currentLocation else { return }
        let nextRawValue = step.rawValue + 1
        if let nextStep = Step(rawValue: nextRawValue) {
            step = nextStep
        }
    }

    public func goToPreviousStep() {
        guard step != .name else { return }
        let prevRawValue = step.rawValue - 1
        if let prevStep = Step(rawValue: prevRawValue) {
            step = prevStep
        }
    }

    // MARK: - Submit

    public func submit() async throws {
        guard let birthPlace = birthPlace, let currentLocation = currentLocation else {
            submitError = "Missing required location data"
            return
        }

        isSubmitting = true
        step = .loading

        do {
            let request = USMRecomputeRequest(
                firstName: firstName,
                lastName: lastName.isEmpty ? nil : lastName,
                dateOfBirth: ISO8601DateFormatter().string(from: dateOfBirth),
                timeOfBirth: hasKnownBirthTime ? formatTimeOfBirth(timeOfBirth) : nil,
                birthPlace: birthPlace,
                currentLocation: currentLocation
            )

            _ = try await recomputeClient.recompute(userId: userId, request: request)
            // Success — step is already .loading, caller checks this
            isSubmitting = false
        } catch {
            // Revert step and set error
            step = .currentLocation
            submitError = error.localizedDescription
            isSubmitting = false
            throw error
        }
    }

    // MARK: - Private Helpers

    private func formatTimeOfBirth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Date Helper

extension Date {
    fileprivate func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}
