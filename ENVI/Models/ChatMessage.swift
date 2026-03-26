import Foundation

/// Represents a message in the ENVI AI chat.
struct ChatMessage: Identifiable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    var dataCard: DataCard?
    var relatedQuestions: [String]?

    enum Role {
        case user
        case assistant
    }

    struct DataCard: Identifiable {
        let id = UUID()
        let title: String
        let metrics: [Metric]

        struct Metric: Identifiable {
            let id = UUID()
            let label: String
            let value: String
            let change: String?
            let isPositive: Bool
        }
    }

    static let mockThread: [ChatMessage] = [
        ChatMessage(
            id: UUID(),
            role: .user,
            content: "How did my content perform this week?",
            timestamp: Date().addingTimeInterval(-3600)
        ),
        ChatMessage(
            id: UUID(),
            role: .assistant,
            content: "Here's your weekly performance summary. Your overall engagement is up 18.4% compared to last week, driven primarily by your Instagram Reels.",
            timestamp: Date().addingTimeInterval(-3500),
            dataCard: DataCard(
                title: "Weekly Performance",
                metrics: [
                    .init(label: "Total Reach", value: "847.2K", change: "+23.1%", isPositive: true),
                    .init(label: "Engagement", value: "12.4K", change: "+18.4%", isPositive: true),
                    .init(label: "Eng. Rate", value: "4.2%", change: "-0.3%", isPositive: false),
                    .init(label: "New Followers", value: "1,204", change: "+12.8%", isPositive: true),
                ]
            ),
            relatedQuestions: [
                "Which post performed best?",
                "What's the best time to post this week?",
                "Show me engagement by platform",
            ]
        ),
    ]
}
