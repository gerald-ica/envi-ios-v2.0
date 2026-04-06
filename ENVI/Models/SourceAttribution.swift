import Foundation

struct SourceAttribution: Identifiable {
    let id = UUID()
    let source: String
    let channel: String?
    let visitors: Int
    let conversions: Int
    let conversionRate: Double
}

extension SourceAttribution {
    static let mock: [SourceAttribution] = [
        SourceAttribution(source: "Organic", channel: "Instagram Explore", visitors: 4200, conversions: 420, conversionRate: 10.0),
        SourceAttribution(source: "Organic", channel: "TikTok FYP", visitors: 3800, conversions: 340, conversionRate: 8.9),
        SourceAttribution(source: "Direct", channel: "Profile Visit", visitors: 2100, conversions: 280, conversionRate: 13.3),
        SourceAttribution(source: "Hashtag", channel: "#creator", visitors: 1500, conversions: 180, conversionRate: 12.0),
        SourceAttribution(source: "Referral", channel: "Link in Bio", visitors: 900, conversions: 120, conversionRate: 13.3),
    ]
}
