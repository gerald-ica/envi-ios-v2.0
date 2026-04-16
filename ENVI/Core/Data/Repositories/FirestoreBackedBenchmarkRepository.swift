//
//  FirestoreBackedBenchmarkRepository.swift
//  ENVI — Phase 13 (analytics insights read-path).
//
//  Conforms to `BenchmarkRepository`. Reads:
//    - `benchmarks/{category}/{metric}`            — global static/quarterly
//    - `users/{uid}/generatedInsights/{yyyy-mm-dd}` — written by CF
//    - `trendSignals/{yyyy-mm-dd}`                  — global nightly trends
//    - `users/{uid}/weeklyDigest/{yyyy-Www}`        — weekly digest CF
//
//  The 15-min TTL cache pattern is identical to the dashboard repo.
//
import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
import FirebaseAuth
#endif

final class FirestoreBackedBenchmarkRepository: BenchmarkRepository {

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

    func fetchBenchmarks(category: IndustryCategory) async throws -> [Benchmark] {
        let key = "benchmarks_\(category.rawValue)"
        if isFresh(key), let cached = cache[key] as? [Benchmark] { return cached }
        return store(try await loadBenchmarks(category: category), key: key)
    }

    func fetchInsights() async throws -> [InsightCard] {
        let key = "insights"
        if isFresh(key), let cached = cache[key] as? [InsightCard] { return cached }
        return store(try await loadInsights(), key: key)
    }

    func fetchTrendSignals() async throws -> [TrendSignal] {
        let key = "trends"
        if isFresh(key), let cached = cache[key] as? [TrendSignal] { return cached }
        return store(try await loadTrends(), key: key)
    }

    func fetchWeeklyDigest() async throws -> WeeklyDigest {
        let key = "digest"
        if isFresh(key), let cached = cache[key] as? WeeklyDigest { return cached }
        return store(try await loadDigest(), key: key)
    }

    // MARK: - Loaders

    #if canImport(FirebaseFirestore)

    private let providers: [SocialPlatform] = [
        .instagram, .facebook, .tiktok, .x, .threads, .linkedin,
    ]

    private func uid() -> String? { Auth.auth().currentUser?.uid }

    /// Merge user rollup metrics with the global benchmarks doc for the
    /// selected industry category. `userValue` comes from the latest
    /// monthly rollup (aggregated across providers when multiple exist);
    /// industry stats come from `benchmarks/{category}/{metric}`.
    private func loadBenchmarks(category: IndustryCategory) async throws -> [Benchmark] {
        guard let uid = uid() else { return [] }
        let db = Firestore.firestore()

        // 1. Aggregate user performance from latest monthly rollups.
        var userEngagementRateSum: Double = 0
        var userFollowerGrowthSum: Int = 0
        var userAvgReachSum: Int = 0
        var providerCount = 0
        for provider in providers {
            let ref = db
                .collection("users").document(uid)
                .collection("insights").document(provider.apiSlug)
                .collection("rollups").document("monthly")
                .collection("entries")
            let snap = try await ref.order(by: "startDate", descending: true).limit(to: 1).getDocuments()
            guard let monthly = try? snap.documents.first?.data(as: MonthlyRollupDTO.self) else { continue }
            userEngagementRateSum += monthly.avgEngagementRate
            userFollowerGrowthSum += monthly.followerGrowth
            userAvgReachSum += monthly.totalReach
            providerCount += 1
        }
        let divisor = max(providerCount, 1)

        // 2. Read the category's industry benchmarks.
        let metrics = ["engagement_rate", "follower_growth", "avg_reach", "save_rate", "share_rate"]
        var out: [Benchmark] = []
        for metric in metrics {
            let ref = db.collection("benchmarks").document(category.rawValue)
                .collection(metric).document("current")
            let doc = try? await ref.getDocument()
            guard let data = doc?.data() else { continue }
            let industryAvg = (data["industryAvg"] as? Double) ?? 0
            let topPerformer = (data["topPerformerThreshold"] as? Double) ?? 0
            let userValue: Double = {
                switch metric {
                case "engagement_rate":  return userEngagementRateSum / Double(divisor)
                case "follower_growth":  return Double(userFollowerGrowthSum)
                case "avg_reach":        return Double(userAvgReachSum) / Double(divisor)
                default:                 return 0
                }
            }()
            let percentile = computePercentile(user: userValue, avg: industryAvg, top: topPerformer)
            out.append(Benchmark(
                metric: metric.replacingOccurrences(of: "_", with: " ").capitalized,
                userValue: userValue,
                industryAvg: industryAvg,
                topPerformer: topPerformer,
                percentile: percentile
            ))
        }
        return out
    }

    private func loadInsights() async throws -> [InsightCard] {
        guard let uid = uid() else { return [] }
        let db = Firestore.firestore()
        // Try today's doc first, fall back to yesterday, then give up.
        let today = dateKey(Date())
        let yesterday = dateKey(Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        for key in [today, yesterday] {
            let ref = db.collection("users").document(uid)
                .collection("generatedInsights").document(key)
            let doc = try? await ref.getDocument()
            guard let data = doc?.data(),
                  let raw = data["insights"] as? [[String: Any]] else { continue }
            let cards = raw.compactMap { dict -> InsightCard? in
                guard let title = dict["title"] as? String,
                      let description = dict["description"] as? String,
                      let advice = dict["actionableAdvice"] as? String,
                      let impactStr = dict["impact"] as? String,
                      let confidence = dict["confidence"] as? Double else { return nil }
                return InsightCard(
                    title: title,
                    description: description,
                    actionableAdvice: advice,
                    impact: ImpactLevel(rawValue: impactStr) ?? .medium,
                    confidence: confidence
                )
            }
            if !cards.isEmpty { return cards }
        }
        return []
    }

    private func loadTrends() async throws -> [TrendSignal] {
        let db = Firestore.firestore()
        let today = dateKey(Date())
        let ref = db.collection("trendSignals").document(today)
        let doc = try? await ref.getDocument()
        guard let data = doc?.data(),
              let raw = data["signals"] as? [[String: Any]] else { return [] }
        return raw.compactMap { dict in
            guard let topic = dict["topic"] as? String,
                  let momentum = dict["momentum"] as? Double,
                  let direction = dict["direction"] as? String,
                  let timeframe = dict["timeframe"] as? String else { return nil }
            let platforms = (dict["platforms"] as? [String] ?? []).compactMap { platformFromSlug($0) }
            return TrendSignal(
                topic: topic,
                momentum: momentum,
                direction: TrendDirection(rawValue: direction) ?? .stable,
                platforms: platforms,
                timeframe: timeframe
            )
        }
    }

    private func loadDigest() async throws -> WeeklyDigest {
        guard let uid = uid() else {
            return WeeklyDigest(weekStarting: Date(), highlights: [], topContent: [], keyMetrics: [], recommendations: [])
        }
        let db = Firestore.firestore()
        let weekLabel = isoWeekLabel(Date())
        let ref = db.collection("users").document(uid)
            .collection("weeklyDigest").document(weekLabel)
        let doc = try? await ref.getDocument()
        guard let data = doc?.data() else {
            return WeeklyDigest(weekStarting: Date(), highlights: [], topContent: [], keyMetrics: [], recommendations: [])
        }
        let weekStartStr = data["weekStarting"] as? String
        let weekStartDate = weekStartStr.flatMap(parseDate) ?? Date()
        let highlights = data["highlights"] as? [String] ?? []
        let recommendations = data["recommendations"] as? [String] ?? []
        return WeeklyDigest(
            weekStarting: weekStartDate,
            highlights: highlights,
            topContent: [],
            keyMetrics: [],
            recommendations: recommendations
        )
    }

    // MARK: - Helpers

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

    private func isoWeekLabel(_ date: Date) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", comps.yearForWeekOfYear ?? 1970, comps.weekOfYear ?? 1)
    }

    private func platformFromSlug(_ slug: String) -> SocialPlatform? {
        switch slug.lowercased() {
        case "instagram": return .instagram
        case "facebook":  return .facebook
        case "tiktok":    return .tiktok
        case "x":         return .x
        case "threads":   return .threads
        case "linkedin":  return .linkedin
        default:          return nil
        }
    }

    /// Lightweight percentile estimate: linear interpolation between
    /// industry-avg (50th) and top-performer (95th). Clamped to [0, 99].
    private func computePercentile(user: Double, avg: Double, top: Double) -> Int {
        if user <= 0 || avg <= 0 { return 0 }
        if user >= top { return 99 }
        if user <= avg { return max(0, Int((user / max(avg, 1)) * 50)) }
        let rangePct = (user - avg) / max(top - avg, 1)
        return min(99, 50 + Int(rangePct * 45))
    }

    #else

    // MARK: - Fallback

    private func loadBenchmarks(category: IndustryCategory) async throws -> [Benchmark] { [] }
    private func loadInsights() async throws -> [InsightCard] { [] }
    private func loadTrends() async throws -> [TrendSignal] { [] }
    private func loadDigest() async throws -> WeeklyDigest {
        WeeklyDigest(weekStarting: Date(), highlights: [], topContent: [], keyMetrics: [], recommendations: [])
    }

    #endif
}

// MARK: - Benchmark Repository Provider extension

extension BenchmarkRepositoryProvider {
    @MainActor
    static func resolve() -> BenchmarkRepository {
        if FeatureFlags.shared.connectorsInsightsLive {
            return FirestoreBackedBenchmarkRepository()
        }
        return shared.repository
    }
}
