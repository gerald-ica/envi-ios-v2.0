import Foundation

// MARK: - Sync Status

/// Represents the current synchronization state of the app.
struct SyncStatus: Codable {
    let lastSync: Date?
    let pendingChanges: Int
    let conflicts: [SyncConflict]

    init(
        lastSync: Date? = nil,
        pendingChanges: Int = 0,
        conflicts: [SyncConflict] = []
    ) {
        self.lastSync = lastSync
        self.pendingChanges = pendingChanges
        self.conflicts = conflicts
    }

    var hasPendingChanges: Bool { pendingChanges > 0 }
    var hasConflicts: Bool { !conflicts.isEmpty }

    var state: State {
        if hasConflicts { return .conflict }
        if hasPendingChanges { return .syncing }
        if lastSync != nil { return .synced }
        return .idle
    }

    enum State: String, Codable {
        case idle
        case syncing
        case synced
        case conflict
        case error

        var displayName: String {
            switch self {
            case .idle:     return "Not Synced"
            case .syncing:  return "Syncing..."
            case .synced:   return "Up to Date"
            case .conflict: return "Conflicts Found"
            case .error:    return "Sync Error"
            }
        }

        var iconName: String {
            switch self {
            case .idle:     return "icloud.slash"
            case .syncing:  return "arrow.triangle.2.circlepath"
            case .synced:   return "checkmark.icloud"
            case .conflict: return "exclamationmark.icloud"
            case .error:    return "xmark.icloud"
            }
        }
    }
}

// MARK: - Sync Conflict

/// A conflict between local and remote versions of content.
struct SyncConflict: Identifiable, Codable {
    let id: UUID
    let contentID: String
    let localModifiedAt: Date
    let remoteModifiedAt: Date
    let fieldName: String
    var resolution: Resolution?

    init(
        id: UUID = UUID(),
        contentID: String,
        localModifiedAt: Date,
        remoteModifiedAt: Date,
        fieldName: String,
        resolution: Resolution? = nil
    ) {
        self.id = id
        self.contentID = contentID
        self.localModifiedAt = localModifiedAt
        self.remoteModifiedAt = remoteModifiedAt
        self.fieldName = fieldName
        self.resolution = resolution
    }

    var isResolved: Bool { resolution != nil }

    enum Resolution: String, Codable {
        case keepLocal
        case keepRemote
        case merged
    }
}

// MARK: - Offline Draft

/// A locally-stored draft that has not yet been synchronized.
struct OfflineDraft: Identifiable, Codable {
    let id: UUID
    let contentID: String
    let title: String
    let modifiedAt: Date
    var syncStatus: DraftSyncStatus

    init(
        id: UUID = UUID(),
        contentID: String,
        title: String,
        modifiedAt: Date = Date(),
        syncStatus: DraftSyncStatus = .pending
    ) {
        self.id = id
        self.contentID = contentID
        self.title = title
        self.modifiedAt = modifiedAt
        self.syncStatus = syncStatus
    }

    enum DraftSyncStatus: String, Codable {
        case pending
        case uploading
        case synced
        case failed

        var displayName: String {
            switch self {
            case .pending:   return "Pending"
            case .uploading: return "Uploading"
            case .synced:    return "Synced"
            case .failed:    return "Failed"
            }
        }

        var iconName: String {
            switch self {
            case .pending:   return "clock"
            case .uploading: return "arrow.up.circle"
            case .synced:    return "checkmark.circle"
            case .failed:    return "exclamationmark.triangle"
            }
        }
    }
}

// MARK: - Cache Policy

/// Configuration for local caching behavior.
struct CachePolicy: Codable {
    let maxAge: TimeInterval
    let maxSize: Int
    let evictionStrategy: EvictionStrategy

    init(
        maxAge: TimeInterval = 3600,
        maxSize: Int = 100_000_000,
        evictionStrategy: EvictionStrategy = .leastRecentlyUsed
    ) {
        self.maxAge = maxAge
        self.maxSize = maxSize
        self.evictionStrategy = evictionStrategy
    }

    var maxAgeDescription: String {
        let hours = Int(maxAge / 3600)
        if hours >= 24 { return "\(hours / 24)d" }
        if hours > 0 { return "\(hours)h" }
        return "\(Int(maxAge / 60))m"
    }

    var maxSizeDescription: String {
        let mb = maxSize / 1_000_000
        if mb >= 1000 { return "\(mb / 1000) GB" }
        return "\(mb) MB"
    }

    enum EvictionStrategy: String, Codable, CaseIterable {
        case leastRecentlyUsed
        case leastFrequentlyUsed
        case firstInFirstOut
        case timeToLive

        var displayName: String {
            switch self {
            case .leastRecentlyUsed:     return "Least Recently Used"
            case .leastFrequentlyUsed:   return "Least Frequently Used"
            case .firstInFirstOut:       return "First In First Out"
            case .timeToLive:            return "Time-To-Live"
            }
        }
    }
}

// MARK: - Performance Metric

/// A single performance measurement with threshold evaluation.
struct PerformanceMetric: Identifiable, Codable {
    let id: UUID
    let name: String
    let value: Double
    let threshold: Double
    let status: Status

    init(
        id: UUID = UUID(),
        name: String,
        value: Double,
        threshold: Double,
        status: Status? = nil
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.threshold = threshold
        self.status = status ?? (value <= threshold ? .healthy : .degraded)
    }

    enum Status: String, Codable {
        case healthy
        case degraded
        case critical

        var displayName: String {
            switch self {
            case .healthy:  return "Healthy"
            case .degraded: return "Degraded"
            case .critical: return "Critical"
            }
        }

        var iconName: String {
            switch self {
            case .healthy:  return "checkmark.circle.fill"
            case .degraded: return "exclamationmark.triangle.fill"
            case .critical: return "xmark.octagon.fill"
            }
        }
    }
}

// MARK: - Mock Data

extension SyncStatus {
    static let mock = SyncStatus(
        lastSync: Date().addingTimeInterval(-300),
        pendingChanges: 3,
        conflicts: [
            SyncConflict(
                contentID: "post-001",
                localModifiedAt: Date().addingTimeInterval(-60),
                remoteModifiedAt: Date().addingTimeInterval(-30),
                fieldName: "caption"
            ),
        ]
    )

    static let mockSynced = SyncStatus(
        lastSync: Date(),
        pendingChanges: 0,
        conflicts: []
    )
}

extension OfflineDraft {
    static let mock: [OfflineDraft] = [
        OfflineDraft(contentID: "draft-001", title: "Summer Campaign Post", modifiedAt: Date().addingTimeInterval(-3600), syncStatus: .pending),
        OfflineDraft(contentID: "draft-002", title: "Product Launch Teaser", modifiedAt: Date().addingTimeInterval(-7200), syncStatus: .failed),
        OfflineDraft(contentID: "draft-003", title: "Weekend Recap Reel", modifiedAt: Date().addingTimeInterval(-1800), syncStatus: .uploading),
        OfflineDraft(contentID: "draft-004", title: "Q2 Results Infographic", modifiedAt: Date().addingTimeInterval(-600), syncStatus: .synced),
    ]
}

extension PerformanceMetric {
    static let mock: [PerformanceMetric] = [
        PerformanceMetric(name: "API Latency", value: 120, threshold: 200, status: .healthy),
        PerformanceMetric(name: "Image Load", value: 850, threshold: 500, status: .degraded),
        PerformanceMetric(name: "Feed Render", value: 45, threshold: 60, status: .healthy),
        PerformanceMetric(name: "Sync Duration", value: 3200, threshold: 2000, status: .critical),
    ]
}
