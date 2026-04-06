import Foundation

// MARK: - ENVI-0008 Active Device Management

/// Represents an active session on a device.
struct DeviceSession: Identifiable, Codable {
    let id: String
    let deviceName: String
    let lastActive: Date
    let location: String
    let isCurrent: Bool

    static let mock: [DeviceSession] = [
        DeviceSession(
            id: "session-1",
            deviceName: "iPhone 16 Pro",
            lastActive: Date(),
            location: "Los Angeles, CA",
            isCurrent: true
        ),
        DeviceSession(
            id: "session-2",
            deviceName: "MacBook Pro",
            lastActive: Date().addingTimeInterval(-3600),
            location: "Los Angeles, CA",
            isCurrent: false
        ),
        DeviceSession(
            id: "session-3",
            deviceName: "iPad Air",
            lastActive: Date().addingTimeInterval(-86400),
            location: "San Francisco, CA",
            isCurrent: false
        ),
    ]
}

// MARK: - ENVI-0020 Login Activity History

/// Represents a single login event.
struct LoginActivity: Identifiable, Codable {
    let id: String
    let timestamp: Date
    let device: String
    let location: String
    let status: LoginStatus

    enum LoginStatus: String, Codable {
        case success
        case failed
        case blocked
    }

    static let mock: [LoginActivity] = [
        LoginActivity(id: "la-1", timestamp: Date(), device: "iPhone 16 Pro", location: "Los Angeles, CA", status: .success),
        LoginActivity(id: "la-2", timestamp: Date().addingTimeInterval(-7200), device: "MacBook Pro", location: "Los Angeles, CA", status: .success),
        LoginActivity(id: "la-3", timestamp: Date().addingTimeInterval(-14400), device: "Unknown Device", location: "New York, NY", status: .blocked),
        LoginActivity(id: "la-4", timestamp: Date().addingTimeInterval(-86400), device: "iPad Air", location: "San Francisco, CA", status: .success),
        LoginActivity(id: "la-5", timestamp: Date().addingTimeInterval(-172800), device: "iPhone 16 Pro", location: "Los Angeles, CA", status: .failed),
    ]
}

// MARK: - ENVI-0019 Consent Ledger

/// Represents a consent record.
struct ConsentRecord: Identifiable, Codable {
    let id: String
    let consentType: String
    let grantedAt: Date
    let version: String

    static let mock: [ConsentRecord] = [
        ConsentRecord(id: "c-1", consentType: "Terms of Service", grantedAt: Date().addingTimeInterval(-2_592_000), version: "2.1"),
        ConsentRecord(id: "c-2", consentType: "Privacy Policy", grantedAt: Date().addingTimeInterval(-2_592_000), version: "1.4"),
        ConsentRecord(id: "c-3", consentType: "Marketing Communications", grantedAt: Date().addingTimeInterval(-1_296_000), version: "1.0"),
        ConsentRecord(id: "c-4", consentType: "Analytics & Tracking", grantedAt: Date().addingTimeInterval(-2_592_000), version: "1.2"),
    ]
}

// MARK: - ENVI-0011 Profile Completion

/// Tracks how complete a user's profile is.
struct ProfileCompletion {
    let score: Int
    let missingFields: [String]

    static let mock = ProfileCompletion(
        score: 72,
        missingFields: ["Bio", "Timezone", "Profile Photo"]
    )
}

// MARK: - ENVI-0013, ENVI-0014 Creator Profile

/// Extended creator profile with localization and niche info.
struct CreatorProfile: Codable {
    var creatorType: String
    var niche: String
    var timezone: String
    var locale: String

    static let mock = CreatorProfile(
        creatorType: "Content Creator",
        niche: "Lifestyle & Fashion",
        timezone: "America/Los_Angeles",
        locale: "en-US"
    )
}

// MARK: - ENVI-0021 Data Export

/// Response from a data export request.
struct DataExportResponse: Codable {
    let requestId: String
    let status: String
    let estimatedReadyAt: Date?
}
