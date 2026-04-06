import Foundation

// MARK: - Protocol

protocol AdminRepository {
    func fetchFeatureFlags() async throws -> [FeatureFlag]
    func toggleFlag(id: UUID, isEnabled: Bool) async throws -> FeatureFlag
    func fetchModerationQueue() async throws -> [ModerationItem]
    func moderateItem(id: UUID, status: ModerationStatus) async throws -> ModerationItem
    func fetchSystemHealth() async throws -> [SystemHealthMetric]
}

// MARK: - Mock Implementation

final class MockAdminRepository: AdminRepository {
    func fetchFeatureFlags() async throws -> [FeatureFlag] {
        FeatureFlag.mock
    }

    func toggleFlag(id: UUID, isEnabled: Bool) async throws -> FeatureFlag {
        var flag = FeatureFlag.mock.first!
        flag = FeatureFlag(id: flag.id, name: flag.name, isEnabled: isEnabled, targetPercentage: flag.targetPercentage, description: flag.description)
        return flag
    }

    func fetchModerationQueue() async throws -> [ModerationItem] {
        ModerationItem.mock
    }

    func moderateItem(id: UUID, status: ModerationStatus) async throws -> ModerationItem {
        var item = ModerationItem.mock.first!
        item.status = status
        return item
    }

    func fetchSystemHealth() async throws -> [SystemHealthMetric] {
        SystemHealthMetric.mock
    }
}

// MARK: - API Implementation

final class APIAdminRepository: AdminRepository {
    func fetchFeatureFlags() async throws -> [FeatureFlag] {
        let response: [FeatureFlagResponse] = try await APIClient.shared.request(
            endpoint: "admin/feature-flags",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }

    func toggleFlag(id: UUID, isEnabled: Bool) async throws -> FeatureFlag {
        let body = ToggleFlagBody(isEnabled: isEnabled)
        let response: FeatureFlagResponse = try await APIClient.shared.request(
            endpoint: "admin/feature-flags/\(id.uuidString)",
            method: .patch,
            body: body,
            requiresAuth: true
        )
        return response.toDomain()
    }

    func fetchModerationQueue() async throws -> [ModerationItem] {
        let response: [ModerationItemResponse] = try await APIClient.shared.request(
            endpoint: "admin/moderation/queue",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }

    func moderateItem(id: UUID, status: ModerationStatus) async throws -> ModerationItem {
        let body = ModerateBody(status: status.rawValue)
        let response: ModerationItemResponse = try await APIClient.shared.request(
            endpoint: "admin/moderation/\(id.uuidString)",
            method: .patch,
            body: body,
            requiresAuth: true
        )
        return response.toDomain()
    }

    func fetchSystemHealth() async throws -> [SystemHealthMetric] {
        let response: [SystemHealthResponse] = try await APIClient.shared.request(
            endpoint: "admin/system/health",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }
}

// MARK: - Provider

enum AdminRepositoryProvider {
    static var shared = Shared(repository: defaultRepository())

    struct Shared {
        var repository: AdminRepository
    }

    private static func defaultRepository() -> AdminRepository {
        switch AppEnvironment.current {
        case .dev:
            return MockAdminRepository()
        case .staging, .prod:
            return APIAdminRepository()
        }
    }
}

// MARK: - API Request Bodies

private struct ToggleFlagBody: Encodable {
    let isEnabled: Bool
}

private struct ModerateBody: Encodable {
    let status: String
}

// MARK: - API Response DTOs

private struct FeatureFlagResponse: Decodable {
    let id: String
    let name: String
    let isEnabled: Bool
    let targetPercentage: Double
    let description: String

    func toDomain() -> FeatureFlag {
        FeatureFlag(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            isEnabled: isEnabled,
            targetPercentage: targetPercentage,
            description: description
        )
    }
}

private struct ModerationItemResponse: Decodable {
    let id: String
    let contentType: String
    let reportReason: String
    let status: String
    let reportedAt: String

    func toDomain() -> ModerationItem {
        let date = ISO8601DateFormatter().date(from: reportedAt) ?? Date()
        return ModerationItem(
            id: UUID(uuidString: id) ?? UUID(),
            contentType: contentType,
            reportReason: reportReason,
            status: ModerationStatus(rawValue: status) ?? .pending,
            reportedAt: date
        )
    }
}

private struct SystemHealthResponse: Decodable {
    let name: String
    let value: Double
    let status: String
    let threshold: Double

    func toDomain() -> SystemHealthMetric {
        SystemHealthMetric(
            name: name,
            value: value,
            status: HealthStatus(rawValue: status) ?? .healthy,
            threshold: threshold
        )
    }
}
