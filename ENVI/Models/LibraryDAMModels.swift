import Foundation

// MARK: - Content Folder

/// Represents a folder in the digital asset management system.
struct ContentFolder: Identifiable, Codable {
    let id: UUID
    var name: String
    var parentID: UUID?
    var color: String?
    var isPinned: Bool
    var itemCount: Int
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        parentID: UUID? = nil,
        color: String? = nil,
        isPinned: Bool = false,
        itemCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.parentID = parentID
        self.color = color
        self.isPinned = isPinned
        self.itemCount = itemCount
        self.createdAt = createdAt
    }
}

// MARK: - Smart Collection

/// A dynamic collection that auto-populates based on filter rules.
struct SmartCollection: Identifiable, Codable {
    let id: UUID
    var name: String
    var rules: [FilterRule]
    var itemCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        rules: [FilterRule] = [],
        itemCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.rules = rules
        self.itemCount = itemCount
    }
}

// MARK: - Filter Rule

/// A single predicate used to build smart collection queries.
struct FilterRule: Identifiable, Codable {
    let id: UUID

    enum Field: String, Codable, CaseIterable, Identifiable {
        case platform, status, dateRange, tag, type, performance
        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .platform: return "Platform"
            case .status: return "Status"
            case .dateRange: return "Date Range"
            case .tag: return "Tag"
            case .type: return "Type"
            case .performance: return "Performance"
            }
        }
    }

    enum Operator: String, Codable, CaseIterable, Identifiable {
        case equals, contains, greaterThan, lessThan, between
        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .equals: return "equals"
            case .contains: return "contains"
            case .greaterThan: return "greater than"
            case .lessThan: return "less than"
            case .between: return "between"
            }
        }
    }

    let field: Field
    let op: Operator
    let value: String

    init(id: UUID = UUID(), field: Field, op: Operator, value: String) {
        self.id = id
        self.field = field
        self.op = op
        self.value = value
    }
}

// MARK: - Asset Version

/// A single version entry in an asset's revision history.
struct AssetVersion: Identifiable, Codable {
    let id: UUID
    let assetID: UUID
    let versionNumber: Int
    let createdAt: Date
    let createdBy: String
    let changeDescription: String

    init(
        id: UUID = UUID(),
        assetID: UUID = UUID(),
        versionNumber: Int,
        createdAt: Date = Date(),
        createdBy: String,
        changeDescription: String
    ) {
        self.id = id
        self.assetID = assetID
        self.versionNumber = versionNumber
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.changeDescription = changeDescription
    }
}

// MARK: - Usage Rights

/// License and attribution metadata for an asset.
struct UsageRights: Codable {
    var license: String?
    var expiresAt: Date?
    var attribution: String?
    var restrictions: [String]

    init(
        license: String? = nil,
        expiresAt: Date? = nil,
        attribution: String? = nil,
        restrictions: [String] = []
    ) {
        self.license = license
        self.expiresAt = expiresAt
        self.attribution = attribution
        self.restrictions = restrictions
    }

    /// True when the license expiry date is in the past.
    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date()
    }
}

// MARK: - Storage Quota

/// Aggregate storage usage for the current account.
struct StorageQuota: Codable {
    let usedBytes: Int64
    let totalBytes: Int64
    let assetCount: Int
    var photoBytes: Int64
    var videoBytes: Int64
    var draftBytes: Int64

    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }

    var formattedUsed: String { Self.formatBytes(usedBytes) }
    var formattedTotal: String { Self.formatBytes(totalBytes) }
    var formattedPhotos: String { Self.formatBytes(photoBytes) }
    var formattedVideos: String { Self.formatBytes(videoBytes) }
    var formattedDrafts: String { Self.formatBytes(draftBytes) }

    init(
        usedBytes: Int64,
        totalBytes: Int64,
        assetCount: Int,
        photoBytes: Int64 = 0,
        videoBytes: Int64 = 0,
        draftBytes: Int64 = 0
    ) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.assetCount = assetCount
        self.photoBytes = photoBytes
        self.videoBytes = videoBytes
        self.draftBytes = draftBytes
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Platform Readiness

/// Readiness status for a specific platform based on asset specifications.
enum PlatformReadiness: String, Codable {
    case ready      // Meets all platform specs
    case warning    // Partially meets specs (e.g. suboptimal aspect ratio)
    case notReady   // Does not meet minimum requirements
}

/// Asset readiness check result for a single platform.
struct PlatformReadinessResult: Identifiable {
    let id: UUID = UUID()
    let platform: SocialPlatform
    let status: PlatformReadiness
    let notes: String
}

// MARK: - Bulk Action

/// Actions available for bulk operations on assets.
enum BulkAssetAction: String, Codable {
    case archive
    case delete
    case move
    case tag
}

// MARK: - Mock Data

extension ContentFolder {
    static let mockFolders: [ContentFolder] = [
        ContentFolder(name: "Campaign Q2", color: "#3B82F6", isPinned: true, itemCount: 24),
        ContentFolder(name: "Brand Assets", color: "#22C55E", isPinned: true, itemCount: 156),
        ContentFolder(name: "User Generated", color: "#F59E0B", isPinned: false, itemCount: 47),
        ContentFolder(name: "B-Roll", color: "#EF4444", isPinned: false, itemCount: 89),
        ContentFolder(name: "Archived", color: nil, isPinned: false, itemCount: 312),
    ]
}

extension SmartCollection {
    static let mockCollections: [SmartCollection] = [
        SmartCollection(
            name: "High Performers",
            rules: [FilterRule(field: .performance, op: .greaterThan, value: "80")],
            itemCount: 18
        ),
        SmartCollection(
            name: "Instagram Ready",
            rules: [FilterRule(field: .platform, op: .equals, value: "Instagram")],
            itemCount: 42
        ),
        SmartCollection(
            name: "Recent Videos",
            rules: [
                FilterRule(field: .type, op: .equals, value: "video"),
                FilterRule(field: .dateRange, op: .greaterThan, value: "2026-03-01"),
            ],
            itemCount: 11
        ),
        SmartCollection(
            name: "Drafts Pending Review",
            rules: [FilterRule(field: .status, op: .equals, value: "draft")],
            itemCount: 7
        ),
    ]
}

extension AssetVersion {
    static func mockVersions(for assetID: UUID = UUID()) -> [AssetVersion] {
        let now = Date()
        return [
            AssetVersion(
                assetID: assetID,
                versionNumber: 3,
                createdAt: now,
                createdBy: "Sarah Chen",
                changeDescription: "Color graded and cropped for Instagram"
            ),
            AssetVersion(
                assetID: assetID,
                versionNumber: 2,
                createdAt: now.addingTimeInterval(-86400),
                createdBy: "Marcus Cole",
                changeDescription: "Added watermark and adjusted exposure"
            ),
            AssetVersion(
                assetID: assetID,
                versionNumber: 1,
                createdAt: now.addingTimeInterval(-172800),
                createdBy: "Sarah Chen",
                changeDescription: "Original upload"
            ),
        ]
    }
}

extension UsageRights {
    static let mockRights = UsageRights(
        license: "Creative Commons BY 4.0",
        expiresAt: Calendar.current.date(byAdding: .month, value: 6, to: Date()),
        attribution: "Photo by Sarah Chen",
        restrictions: ["No commercial use without permission", "Attribution required"]
    )
}

extension StorageQuota {
    static let mockQuota = StorageQuota(
        usedBytes: 2_147_483_648,    // 2 GB
        totalBytes: 5_368_709_120,   // 5 GB
        assetCount: 347,
        photoBytes: 1_073_741_824,   // 1 GB
        videoBytes: 858_993_459,     // ~800 MB
        draftBytes: 214_748_365      // ~200 MB
    )
}

extension PlatformReadinessResult {
    static let mockReadiness: [PlatformReadinessResult] = [
        PlatformReadinessResult(platform: .instagram, status: .ready, notes: "1080x1080 — optimal"),
        PlatformReadinessResult(platform: .tiktok, status: .warning, notes: "9:16 preferred, current is 1:1"),
        PlatformReadinessResult(platform: .x, status: .ready, notes: "Meets image spec"),
        PlatformReadinessResult(platform: .youtube, status: .notReady, notes: "Resolution too low for thumbnail"),
        PlatformReadinessResult(platform: .linkedin, status: .ready, notes: "1200x627 — optimal"),
        PlatformReadinessResult(platform: .threads, status: .ready, notes: "Meets image spec"),
    ]
}
