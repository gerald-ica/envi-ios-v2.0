//
//  FirestoreBackedAnalyticsRepository.swift
//  ENVI — Phase 13 (analytics insights read-path).
//
//  Conforms to the existing `AnalyticsRepository` protocol (no protocol
//  changes). Reads per-user insight snapshots written by the nightly Cloud
//  Function sync (see `functions/src/insights/*`), aggregates them across
//  every connected provider, and emits `AnalyticsData` for the dashboard.
//
//  Caching model
//  -------------
//  15-minute in-memory TTL per `fetch*` method. The nightly Cloud Function
//  sync is the authoritative data path; this client-side cache exists only
//  to avoid repeated Firestore round-trips within a single user session
//  (e.g. when the user taps between KPI + chart tabs). Firestore SDK
//  offline persistence (enabled at FirebaseApp boot) already handles the
//  app-relaunch cache.
//
//  Firestore gating
//  ----------------
//  `FirebaseFirestore` is NOT currently a dependency in `Package.swift`.
//  To comply with the "no new iOS SPM deps" constraint in Phase 13, the
//  repository is gated behind `#if canImport(FirebaseFirestore)` and
//  falls back to returning `AnalyticsData.empty` when the SDK is not
//  linked. Adding the SPM product in a future phase will activate the
//  live path automatically without any call-site changes.
//
//  Provider mapping (PLAN.md §Provider Notes)
//  ------------------------------------------
//  - IG: the daily snapshot's `views` field feeds `AnalyticsData.KPI.reach`
//    (the Nov 2025 `impressions` deprecation is handled in the Cloud
//    Function — by the time we read Firestore everything is already
//    `views`).
//  - FB: `page_views_total` replaces deprecated `page_impressions`.
//  - X: when the token's tier can't return `impression_count`, the
//    snapshot's `dataQuality` is `partial`. `hasConnectedData` still
//    returns true — the KPI card will render with the "Limited data"
//    badge handled view-side in a future iteration.
//
import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
import FirebaseAuth
#endif

/// Firestore-backed implementation of the dashboard-level analytics
/// repository. Use `AnalyticsRepositoryProvider.shared.repository` — the
/// provider wires this in when `FeatureFlags.shared.connectorsInsightsLive`
/// is `true`, otherwise `MockAnalyticsRepository` / `APIAnalyticsRepository`
/// are returned per the existing env switch.
final class FirestoreBackedAnalyticsRepository: AnalyticsRepository {

    // MARK: - TTL cache

    /// In-memory TTL; 15 min matches the nightly-sync cadence which is
    /// once per day — we need only avoid redundant round-trips within the
    /// session, not long-lived staleness.
    private let ttl: TimeInterval = 15 * 60
    private var lastFetchedAt: [String: Date] = [:]
    private var cachedDashboard: AnalyticsData?
    private var cachedGrowth: CreatorGrowthSnapshot?
    private var cachedCohorts: [RetentionCohort]?
    private var cachedAttribution: [SourceAttribution]?

    // MARK: - Protocol

    func fetchDashboard() async throws -> AnalyticsData {
        if let cached = cachedDashboard, isFresh("dashboard") {
            return cached
        }
        let data = try await loadDashboard()
        cachedDashboard = data
        lastFetchedAt["dashboard"] = Date()
        return data
    }

    func fetchCreatorGrowth() async throws -> CreatorGrowthSnapshot {
        if let cached = cachedGrowth, isFresh("growth") {
            return cached
        }
        let snapshot = try await loadGrowth()
        cachedGrowth = snapshot
        lastFetchedAt["growth"] = Date()
        return snapshot
    }

    func fetchRetentionCohorts() async throws -> [RetentionCohort] {
        if let cached = cachedCohorts, isFresh("cohorts") {
            return cached
        }
        let cohorts = try await loadCohorts()
        cachedCohorts = cohorts
        lastFetchedAt["cohorts"] = Date()
        return cohorts
    }

    func fetchAttribution() async throws -> [SourceAttribution] {
        if let cached = cachedAttribution, isFresh("attribution") {
            return cached
        }
        let items = try await loadAttribution()
        cachedAttribution = items
        lastFetchedAt["attribution"] = Date()
        return items
    }

    // MARK: - Helpers

    private func isFresh(_ key: String) -> Bool {
        guard let last = lastFetchedAt[key] else { return false }
        return Date().timeIntervalSince(last) < ttl
    }

    // MARK: - Loaders (live path gated on FirebaseFirestore)

    #if canImport(FirebaseFirestore)

    /// Providers we look at when aggregating cross-platform KPIs. Keep in
    /// sync with the Cloud Function `SupportedProvider` union.
    private let providers: [SocialPlatform] = [
        .instagram, .facebook, .tiktok, .x, .threads, .linkedin,
    ]

    private func currentUid() -> String? {
        Auth.auth().currentUser?.uid
    }

    private func dateKey(_ date: Date) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d",
                      comps.year ?? 1970, comps.month ?? 1, comps.day ?? 1)
    }

    private func loadDashboard() async throws -> AnalyticsData {
        guard let uid = currentUid() else { return .empty }
        let db = Firestore.firestore()

        var totalViews: Int = 0
        var totalEngagement: Int = 0
        var dailyEngagement: [AnalyticsData.DailyMetric] = []
        var calendarDays: [AnalyticsData.CalendarDay] = []
        var anyData = false
        let now = Date()
        let calendar = Calendar.current

        // Build a 7-day engagement strip aggregated across providers.
        var dayBuckets: [String: Double] = [:]
        var dayLabels: [String] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            guard let d = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let key = dateKey(d)
            dayBuckets[key] = 0
            dayLabels.append(shortDayLabel(for: d))
        }

        for provider in providers {
            let snaps = try await recentDailies(db: db, uid: uid, provider: provider, days: 30)
            if snaps.isEmpty { continue }
            anyData = true
            for snap in snaps {
                totalViews += snap.views
                totalEngagement += snap.likes + snap.comments + snap.shares + (snap.saves ?? 0)
                if dayBuckets[snap.date] != nil {
                    dayBuckets[snap.date, default: 0] +=
                        Double(snap.likes + snap.comments + snap.shares + (snap.saves ?? 0))
                }
                if let postedDate = isoDate(snap.date) {
                    calendarDays.append(.init(date: postedDate, hasContent: !snap.posts.isEmpty, platform: provider))
                }
            }
        }

        if !anyData { return .empty }

        // Build DailyMetric series preserving day order.
        var orderedKeys: [String] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            if let d = calendar.date(byAdding: .day, value: -offset, to: now) {
                orderedKeys.append(dateKey(d))
            }
        }
        dailyEngagement = zip(orderedKeys, dayLabels).map { key, label in
            AnalyticsData.DailyMetric(day: label, value: dayBuckets[key] ?? 0)
        }

        // Engagement rate = engagement / views * 100.
        let rate = totalViews > 0 ? (Double(totalEngagement) / Double(totalViews)) * 100.0 : 0
        let reach = AnalyticsData.KPI(
            label: "Reach",
            value: formatCount(totalViews),
            change: "",
            isPositive: true
        )
        let engagement = AnalyticsData.KPI(
            label: "Engagement",
            value: formatCount(totalEngagement),
            change: "",
            isPositive: true
        )
        let engagementRate = AnalyticsData.KPI(
            label: "Rate",
            value: String(format: "%.1f%%", rate),
            change: "",
            isPositive: rate > 0
        )

        return AnalyticsData(
            reach: reach,
            engagement: engagement,
            engagementRate: engagementRate,
            dailyEngagement: dailyEngagement,
            calendarDays: calendarDays
        )
    }

    private func loadGrowth() async throws -> CreatorGrowthSnapshot {
        guard let uid = currentUid() else {
            return CreatorGrowthSnapshot(followerGrowthPercent: 0, netNewFollowers: 0,
                                         weeklyRetentionPercent: 0,
                                         topPerformingPlatform: .instagram,
                                         channels: [])
        }
        let db = Firestore.firestore()
        var channels: [ChannelGrowth] = []
        var totalNet = 0
        var topPlatform: SocialPlatform = .instagram
        var topViews = -1

        for provider in providers {
            let weekly = try await latestWeeklyRollup(db: db, uid: uid, provider: provider)
            guard let rollup = weekly else { continue }
            let channel = ChannelGrowth(
                platform: provider,
                netFollowers: rollup.followerGrowth,
                growthPercent: rollup.avgEngagementRate
            )
            channels.append(channel)
            totalNet += rollup.followerGrowth
            if rollup.totalViews > topViews {
                topViews = rollup.totalViews
                topPlatform = provider
            }
        }

        let pct = channels.isEmpty ? 0 : channels.map(\.growthPercent).reduce(0, +) / Double(channels.count)
        return CreatorGrowthSnapshot(
            followerGrowthPercent: pct,
            netNewFollowers: totalNet,
            weeklyRetentionPercent: 0,
            topPerformingPlatform: topPlatform,
            channels: channels
        )
    }

    private func loadCohorts() async throws -> [RetentionCohort] {
        guard let uid = currentUid() else { return [] }
        let db = Firestore.firestore()
        var cohorts: [RetentionCohort] = []
        for provider in providers {
            let rollups = try await recentMonthlyRollups(db: db, uid: uid, provider: provider, months: 6)
            for r in rollups {
                cohorts.append(RetentionCohort(
                    weekLabel: r.monthLabel,
                    cohortSize: r.totalViews,
                    retainedPercent: r.avgEngagementRate,
                    platform: provider
                ))
            }
        }
        return cohorts
    }

    private func loadAttribution() async throws -> [SourceAttribution] {
        guard let uid = currentUid() else { return [] }
        let db = Firestore.firestore()
        var out: [SourceAttribution] = []
        for provider in providers {
            guard let latest = try await latestDailySnapshot(db: db, uid: uid, provider: provider) else { continue }
            let engagement = latest.likes + latest.comments + latest.shares + (latest.saves ?? 0)
            let rate = latest.views > 0 ? Double(engagement) / Double(latest.views) * 100.0 : 0
            out.append(SourceAttribution(
                source: provider.rawValue,
                channel: nil,
                visitors: latest.views,
                conversions: engagement,
                conversionRate: rate
            ))
        }
        return out
    }

    // MARK: - Low-level Firestore reads

    private func recentDailies(
        db: Firestore,
        uid: String,
        provider: SocialPlatform,
        days: Int
    ) async throws -> [DailySnapshotDTO] {
        // Daily docs are written under
        //   users/{uid}/insights/{provider}/daily/{yyyy-mm-dd}
        // by `insightsSyncBase.ts`. We read one doc per date for the
        // trailing `days` window.
        let collection = db
            .collection("users")
            .document(uid)
            .collection("insights")
            .document(provider.apiSlug)
            .collection("daily")
        var out: [DailySnapshotDTO] = []
        let now = Date()
        let cal = Calendar.current
        for offset in 0..<days {
            guard let d = cal.date(byAdding: .day, value: -offset, to: now) else { continue }
            let key = dateKey(d)
            let doc = try await collection.document(key).getDocument()
            if doc.exists, let dto = try? doc.data(as: DailySnapshotDTO.self) {
                out.append(dto)
            }
        }
        return out
    }

    private func latestDailySnapshot(
        db: Firestore,
        uid: String,
        provider: SocialPlatform
    ) async throws -> DailySnapshotDTO? {
        let snaps = try await recentDailies(db: db, uid: uid, provider: provider, days: 3)
        return snaps.first
    }

    private func latestWeeklyRollup(
        db: Firestore,
        uid: String,
        provider: SocialPlatform
    ) async throws -> WeeklyRollupDTO? {
        let ref = db
            .collection("users").document(uid)
            .collection("insights").document(provider.apiSlug)
            .collection("rollups").document("weekly")
            .collection("entries")
        let snap = try await ref.order(by: "startDate", descending: true).limit(to: 1).getDocuments()
        return try snap.documents.first?.data(as: WeeklyRollupDTO.self)
    }

    private func recentMonthlyRollups(
        db: Firestore,
        uid: String,
        provider: SocialPlatform,
        months: Int
    ) async throws -> [MonthlyRollupDTO] {
        let ref = db
            .collection("users").document(uid)
            .collection("insights").document(provider.apiSlug)
            .collection("rollups").document("monthly")
            .collection("entries")
        let snap = try await ref.order(by: "startDate", descending: true).limit(to: months).getDocuments()
        return snap.documents.compactMap { try? $0.data(as: MonthlyRollupDTO.self) }
    }

    // MARK: - Small utils

    private func isoDate(_ key: String) -> Date? {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")
        return fmt.date(from: key)
    }

    private func shortDayLabel(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "EEE"
        return fmt.string(from: date)
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    #else

    // MARK: - Fallback when FirebaseFirestore is not linked

    private func loadDashboard() async throws -> AnalyticsData { .empty }
    private func loadGrowth() async throws -> CreatorGrowthSnapshot {
        CreatorGrowthSnapshot(followerGrowthPercent: 0, netNewFollowers: 0,
                              weeklyRetentionPercent: 0,
                              topPerformingPlatform: .instagram,
                              channels: [])
    }
    private func loadCohorts() async throws -> [RetentionCohort] { [] }
    private func loadAttribution() async throws -> [SourceAttribution] { [] }

    #endif
}

// MARK: - Firestore DTOs

#if canImport(FirebaseFirestore)

/// Matches `DailySnapshot` from `functions/src/insights/_shared/snapshotSchema.ts`.
/// Fields the iOS layer doesn't read (rawResponseRef, syncedAt, ...) stay
/// off the struct — Firestore's Codable ignores unknown keys.
struct DailySnapshotDTO: Codable {
    let provider: String
    let date: String
    let accountId: String
    let followers: Int
    let followersGain: Int
    let views: Int
    let reach: Int
    let likes: Int
    let comments: Int
    let shares: Int
    let saves: Int?
    let linkClicks: Int?
    let posts: [PostMetricDTO]
    let postsByHour: [String: Int]?
    let audienceAge: [String: Int]?
    let audienceGender: [String: Int]?
    let audienceCountry: [String: Int]?
    let dataQuality: String
}

struct PostMetricDTO: Codable {
    let postId: String
    let platform: String
    let views: Int
    let likes: Int
    let comments: Int
    let shares: Int
    let saves: Int?
    let postedAt: String
}

struct WeeklyRollupDTO: Codable {
    let provider: String
    let weekLabel: String
    let startDate: String
    let endDate: String
    let totalViews: Int
    let totalReach: Int
    let totalLikes: Int
    let totalComments: Int
    let totalShares: Int
    let totalSaves: Int?
    let totalLinkClicks: Int?
    let avgEngagementRate: Double
    let followerGrowth: Int
    let topPostId: String?
    let dataQuality: String
}

struct MonthlyRollupDTO: Codable {
    let provider: String
    let monthLabel: String
    let startDate: String
    let endDate: String
    let totalViews: Int
    let totalReach: Int
    let totalLikes: Int
    let totalComments: Int
    let totalShares: Int
    let totalSaves: Int?
    let totalLinkClicks: Int?
    let avgEngagementRate: Double
    let followerGrowth: Int
    let bestPostId: String?
    let audienceAge: [String: Int]?
    let audienceGender: [String: Int]?
    let audienceCountry: [String: Int]?
    let dataQuality: String
}

#endif
