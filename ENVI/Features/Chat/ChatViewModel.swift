import SwiftUI
import Combine

/// ViewModel for the ENVI AI Chat screen.
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var isHome = true

    let quickActions = [
        "Weekly engagement summary",
        "Edit a clip for TikTok",
        "Best posting times this week",
        "Analyze my latest post",
    ]

    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let userMessage = ChatMessage(
            id: UUID(),
            role: .user,
            content: inputText,
            timestamp: Date()
        )
        messages.append(userMessage)
        inputText = ""
        isHome = false

        // Simulate AI response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.simulateResponse()
        }
    }

    func selectQuickAction(_ action: String) {
        inputText = action
        sendMessage()
    }

    private func simulateResponse() {
        let response = ChatMessage(
            id: UUID(),
            role: .assistant,
            content: "Here's your weekly performance summary. Your overall engagement is up 18.4% compared to last week, driven primarily by your Instagram Reels.",
            timestamp: Date(),
            dataCard: ChatMessage.DataCard(
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
                "What's the best time to post?",
                "Show me engagement by platform",
            ]
        )
        messages.append(response)
    }
}
