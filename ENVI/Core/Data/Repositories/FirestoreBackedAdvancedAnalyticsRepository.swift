//
//  FirestoreBackedAdvancedAnalyticsRepository.swift
//  ENVI — Phase 13 (analytics insights read-path).
//
//  Conforms to `AdvancedAnalyticsRepository`. Reads from the same
//  `users/{uid}/insights/{provider}/{yyyy-mm-dd}` collection as the
//  dashboard repo, plus the weekly/monthly rollups for longer-range
//  queries.
//
//  Composite index note
//  --------------------
//  `fetchContentPerformance` needs a collection-group query over daily
//  snapshots filtered by provider + sorted by a metric field. The index
//  is declared in `firestore.indexes.json` (see Phase 13-06).
//
//  See `FirestoreBackedAnalyticsRepository.swift` for the 15-min TTL +
//  FirebaseFirestore-gating rationale; the same pattern is reused here.
//
import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
import FirebaseAuth
#endif

final class FirestoreBackedAdvancedAnalyticsRepository: AdvancedAnalyticsRepository {

    // MARK: - TTL cache

    private let ttl: TimeInterval = 15 * 60
    private var lastFetchedAt: [String: Date] = [:]
    private var cache: [String: Any] = [:]

    private func isFresh(_ key: String) -> Bool {
        guard let t = lastFetchedAt[key] else { return false }
        return Date().timeIntervalSince(t) < ttl
    }

    private func store<T>(_ value: T, key: String) -> T {
        cache[key] = value
        lastFetchedAt[key] = Date()
        return value
    }

    // MARK: - Protocol

    func fetchPerformanceReport(range: DateInterval, platforms: [SocialPlatform]) async throws -> PerformanceReport {
        let key = "report_\(Int(range.start.timeIntervalSince1970))_\(Int(range.end.timeIntervalSince1970))_\(platforms.map(\.rawValue).sorted().joined(separator: ","))"
        if isFresh(key), let cached = cache[key] as? PerformanceReport { return cached }
        let report = try await loadReport(range: range, platforms: platforms)
        return store(report, key: key)
    }

    func fetchAudienceDemographics() async throws -> [AudienceDemographic] {
        let key = "demographics"
        if isFresh(key), let cached = cache[key] as? [AudienceDemographic] { return cached }
        return store(try await loadDemographics(), key: key)
    }

    func fetchContentPerformance(sortBy: ContentSortField, limit: Int) async throws -> [ContentPerformance] {
        let key = "content_\(sortBy.rawValue)_\(limit)"
        if isFresh(key), let cached = cache[key] as? [ContentPerformance] { return cached }
        return store(try await loadContent(sortBy: sortBy, limit: limit), key: key)
    }

    func fetchPostTimeAnalysis() async throws -> [PostTimeAnalysis] {
        let key = "posttime"
        if isFresh(key), let cached = cache[key] as? [PostTimeAnalysis] { return cached }
        return store(try await loadPostTime(), key: key)
    }

    func fetchFunnelData() async throws -> [FunnelStep] {
        let key = "funnel"
        if isFresh(key), let cached = cache[key] as? [FunnelStep] { return cached }
        return store(try await loadFunnel(), key: key)
    }

    func fetchPeriodComparison(current: DateInterval, previous: DateInterval) async throws -> [ComparisonPeriod] {
        let key = "comparison_\(Int(current.start.timeIntervalSince1970))_\(Int(previous.start.timeIntervalSince1970))"
        if isFresh(key), let cached = cache[key] as? [ComparisonPeriod] { return cached }
        return store(try await loadComparison(current: current, previous: previous), key: key)
    }

    // MARK: - Loaders

    #if canImport(FirebaseFirestore)

    private let providers: [SocialPlatform] = [
        .instagram, .facebook, .tiktok, .x, .threads, .linkedin,
    ]

    private func uid() -> String? { Auth.auth().currentUser?.uid }

    private func loadReport(range: DateInterval, platforms: [SocialPlatform]) async throws -> PerformanceReport {
        guard let uid = uid() else {
            return PerformanceReport(dateRange: range, platforms: platforms, metrics: [], summary: "")
        }
        let db = Firestore.firestore()
        var metrics: [MetricDataPoint] = []
        for provider in platforms {
            let snaps = try await dailySnapshotsInRange(db: db, uid: uid, provider: provider, range: range)
            for s in snaps {
                guard let d = parseDate(s.date) else { continue }
                metrics.append(MetricDataPoint(date: d, value: Double(s.views), platform: provider))
            }
        }
        return PerformanceReport(
            dateRange: range,
            platforms: platforms,
            metrics: metrics,
            summary: metrics.isEmpty ? "No data yet for the selected range." : ""
        )
    }

    private func loadDemographics() async throws -> [AudienceDemographic] {
        guard let uid = uid() else { return [] }
        let db = Firestore.firestore()
        var out: [AudienceDemographic] = []
        for provider in providers {
            guard let monthly = try await latestMonthlyRollup(db: db, uid: uid, provider: provider) else { continue }
            let ageBuckets = monthly.audienceAge ?? [:]
            let genderBuckets = monthly.audienceGender ?? [:]
            let countryBuckets = monthly.audienceCountry ?? [:]
            let total = Double(ageBuckets.values.reduce(0, +) +
                               genderBuckets.values.reduce(0, +) +
                               countryBuckets.values.reduce(0, +))
            let denom = max(total, 1)
            for (age, value) in ageBuckets {
                for (gender, gvalue) in genderBuckets {
                    let topCountry = countryBuckets.max(by: { $0.value < $1.value })?.key ?? "—"
                    out.append(AudienceDemographic(
                        ageRange: age,
                        gender: gender,
                        location: topCountry,
                        percentage: Double(value + gvalue) / denom * 100.0
                    ))
                }
            }
        }
        return out
    }

    private func loadContent(sortBy: ContentSortField, limit: Int) async throws -> [ContentPerformance] {
        guard let uid = uid() else { return [] }
        let db = Firestore.firestore()
        var all: [ContentPerformance] = []
        for provider in providers {
            let snaps = try await recentDailies(db: db, uid: uid, provider: provider, days: 30)
            for s in snaps {
                for p in s.posts {
                    all.append(ContentPerformance(
                        contentID: p.postId,
                        title: "Post \(p.postId.prefix(6))",
                        platform: provider,
                        impressions: p.views,
                        reach: p.views,
                        engagement: p.likes + p.comments + p.shares + (p.saves ?? 0),
                        saves: p.saves ?? 0,
                        shares: p.shares,
                        comments: p.comments,
                        clickRate: 0
                    ))
                }
            }
        }
        let sorted: [ContentPerformance]
        switch sortBy {
        case .impressions: sorted = all.sorted { $0.impressions > $1.impressions }
        case .engagement:  sorted = all.sorted { $0.engagement > $1.engagement }
        case .saves:       sorted = all.sorted { $0.saves > $1.saves }
        case .shares:      sorted = all.sorted { $0.shares > $1.shares }
        case .clickRate:   sorted = all.sorted { $0.clickRate > $1.clickRate }
        }
        return Array(sorted.prefix(limit))
    }

    private func loadPostTime() async throws -> [PostTimeAnalysis] {
        guard let uid = uid() else { return [] }
        let db = Firestore.firestore()
        var buckets: [String: (eng: Int, count: Int)] = [:]  // key "day-hour"
        let cal = Calendar.current
        for provider in providers {
            let snaps = try await recentDailies(db: db, uid: uid, provider: provider, days: 90)
            for s in snaps {
                guard let baseDate = parseDate(s.date) else { continue }
                let dayIdx = cal.component(.weekday, from: baseDate) - 1  // Sun=0
                for (hourStr, eng) in s.postsByHour ?? [:] {
                    guard let hour = Int(hourStr) else { continue }
                    let key = "\(dayIdx)-\(hour)"
                    let existing = buckets[key] ?? (0, 0)
                    buckets[key] = (existing.eng + eng, existing.count + 1)
                }
            }
        }
        return buckets.compactMap { (key, value) in
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            let avg = value.count > 0 ? Double(value.eng) / Double(value.count) : 0
            return PostTimeAnalysis(
                dayOfWeek: parts[0],
                hour: parts[1],
                avgEngagement: avg,
                postCount: value.count
            )
        }
    }

    private func loadFunnel() async throws -> [FunnelStep] {
        guard let uid = uid() else { return [] }
        let db = Firestore.firestore()
        var totalViews = 0
        var totalReach = 0
        var totalEngagement = 0
        var totalClicks = 0
        for provider in providers {
            let snaps = try await recentDailies(db: db, uid: uid, provider: provider, days: 30)
            for s in snaps {
                totalViews += s.views
                totalReach += s.reach
                totalEngagement += s.likes + s.comments + s.shares + (s.saves ?? 0)
                totalClicks += s.linkClicks ?? 0
            }
        }
        guard totalViews > 0 else { return [] }
        func dropoff(_ from: Int, _ to: Int) -> Double {
            guard from > 0 else { return 0 }
            return (1.0 - Double(to) / Double(from)) * 100.0
        }
        return [
            FunnelStep(name: "Views", count: totalViews, dropoffRate: 0),
            FunnelStep(name: "Reach", count: totalReach, dropoffRate: dropoff(totalViews, totalReach)),
            FunnelStep(name: "Engagement", count: totalEngagement, dropoffRate: dropoff(totalReach, totalEngagement)),
            FunnelStep(name: "Link clicks", count: totalClicks, dropoffRate: dropoff(totalEngagement, totalClicks)),
        ]
    }

    private func loadComparison(current: DateInterval, previous: DateInterval) async throws -> [ComparisonPeriod] {
        guard let uid = uid() else { return [] }
        let db = Firestore.firestore()
        let curTotals = try await totalsInRange(db: db, uid: uid, range: current)
        let prevTotals = try await totalsInRange(db: db, uid: uid, range: previous)
        func pct(_ c: Double, _ p: Double) -> Double {
            guard p > 0 else { return 0 }
            return (c - p) / p * 100.0
        }
        return [
            ComparisonPeriod(metricName: "Views", current: Double(curTotals.views), previous: Double(prevTotals.views), changePercent: pct(Double(curTotals.views), Double(prevTotals.views))),
            ComparisonPeriod(metricName: "Engagement", current: Double(curTotals.engagement), previous: Double(prevTotals.engagement), changePercent: pct(Double(curTotals.engagement), Double(prevTotals.engagement))),
            ComparisonPeriod(metricName: "Followers", current: Double(curTotals.followers), previous: Double(prevTotals.followers), changePercent: pct(Double(curTotals.followers), Double(prevTotals.followers))),
        ]
    }

    // MARK: - Low-level reads

    private func dailySnapshotsInRange(
        db: Firestore,
        uid: String,
        provider: SocialPlatform,
        range: DateInterval
    ) async throws -> [DailySnapshotDTO] {
        var out: [DailySnapshotDTO] = []
        var cursor = range.start
        let cal = Calendar.current
        while cursor <= range.end {
            let key = dateKey(cursor)
            let ref = db
                .collection("users").document(uid)
                .collection("insights").document(provider.apiSlug)
                .collection("daily").document(key)
            let doc = try await ref.getDocument()
            if doc.exists, let dto = try? doc.data(as: DailySnapshotDTO.self) {
                out.append(dto)
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return out
    }

    private func recentDailies(
        db: Firestore,
        uid: String,
        provider: SocialPlatform,
        days: Int
    ) async throws -> [DailySnapshotDTO] {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end
        return try await dailySnapshotsInRange(db: db, uid: uid, provider: provider, range: DateInterval(start: start, end: end))
    }

    private func latestMonthlyRollup(
        db: Firestore,
        uid: String,
        provider: SocialPlatform
    ) async throws -> MonthlyRollupDTO? {
        let ref = db
            .collection("users").document(uid)
            .collection("insights").document(provider.apiSlug)
            .collection("rollups").document("monthly")
            .collection("entries")
        let snap = try await ref.order(by: "startDate", descending: true).limit(to: 1).getDocuments()
        return try snap.documents.first?.data(as: MonthlyRollupDTO.self)
    }

    private struct Totals {
        var views: Int = 0
        var engagement: Int = 0
        var followers: Int = 0
    }

    private func totalsInRange(db: Firestore, uid: String, range: DateInterval) async throws -> Totals {
        var totals = Totals()
        for provider in providers {
            let snaps = try await dailySnapshotsInRange(db: db, uid: uid, provider: provider, range: range)
            for s in snaps {
                totals.views += s.views
                totals.engagement += s.likes + s.comments + s.shares + (s.saves ?? 0)
                totals.followers = max(totals.followers, s.followers)  // use peak per-provider then sum via loop
            }
        }
        return totals
    }

    // MARK: - Small utils

    private func dateKey(_ date: Date) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    private func parseDate(_ key: String) -> Date? {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")
        return fmt.date(from: key)
    }

    #else

    // MARK: - Fallback

    private func loadReport(range: DateInterval, platforms: [SocialPlatform]) async throws -> PerformanceReport {
        PerformanceReport(dateRange: range, platforms: platforms, metrics: [], summary: "")
    }
    private func loadDemographics() async throws -> [AudienceDemographic] { [] }
    private func loadContent(sortBy: ContentSortField, limit: Int) async throws -> [ContentPerformance] { [] }
    private func loadPostTime() async throws -> [PostTimeAnalysis] { [] }
    private func loadFunnel() async throws -> [FunnelStep] { [] }
    private func loadComparison(current: DateInterval, previous: DateInterval) async throws -> [ComparisonPeriod] { [] }

    #endif
}

// MARK: - Advanced Repository Provider extension

extension AdvancedAnalyticsRepositoryProvider {
    /// Main-actor-safe resolver. Returns a Firestore-backed repo when the
    /// feature flag is on, otherwise the existing `shared.repository`.
    @MainActor
    static func resolve() -> AdvancedAnalyticsRepository {
        if FeatureFlags.shared.connectorsInsightsLive {
            return FirestoreBackedAdvancedAnalyticsRepository()
        }
        return shared.repository
    }
}
