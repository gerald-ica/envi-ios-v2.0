import Foundation

struct RetentionCohort: Identifiable {
    let id = UUID()
    let weekLabel: String
    let cohortSize: Int
    let retainedPercent: Double
    let platform: SocialPlatform?
}

extension RetentionCohort {
    static let mock: [RetentionCohort] = [
        RetentionCohort(weekLabel: "Week 1", cohortSize: 1840, retainedPercent: 100.0, platform: nil),
        RetentionCohort(weekLabel: "Week 2", cohortSize: 1548, retainedPercent: 84.1, platform: nil),
        RetentionCohort(weekLabel: "Week 3", cohortSize: 1290, retainedPercent: 70.1, platform: nil),
        RetentionCohort(weekLabel: "Week 4", cohortSize: 1105, retainedPercent: 60.1, platform: nil),
    ]
}
