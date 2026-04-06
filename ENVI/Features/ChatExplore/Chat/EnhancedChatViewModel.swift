import Foundation
import Combine

// MARK: - Oracle API Response

/// Decodable response from the `oracle/chat` endpoint.
///
/// Endpoint contract:
/// - POST `oracle/chat`
/// - Body: `{ "prompt": "...", "threadId": "..." }`
/// - Response: `{ "message": "...", "citations": [...], "suggestedFollowUps": [...] }`
struct OracleResponse: Decodable {
    let message: String
    let citations: [Citation]
    let suggestedFollowUps: [String]

    struct Citation: Decodable {
        let title: String
        let url: String?
    }
}

/// Encodable request body for the `oracle/chat` endpoint.
private struct OracleChatRequest: Encodable {
    let prompt: String
    let threadId: String?
}

/// ViewModel powering the enhanced ENVI AI chat experience.
/// Manages thread state, typing simulation, and Oracle API integration.
///
/// ## ENVI Brain Integration
///
/// The ViewModel bridges user queries to the ENVI Brain (ENVIBrain.shared),
/// which provides data-backed insights through its InsightGenerator subsystem.
/// When the Brain has relevant insights for a query, they are used to build
/// a richer ChatThread response. In dev mode, mock data serves as fallback
/// for queries the Brain doesn't yet handle or when running in preview mode.
/// In staging/prod, unmatched queries are routed to the Oracle API.
final class EnhancedChatViewModel: ObservableObject {

    // MARK: - Published State

    @Published var activeThread: ChatThread?
    @Published var isTyping: Bool = false
    @Published var isHome: Bool = true
    @Published var inputText: String = ""
    @Published var errorMessage: String?

    // MARK: - Quick Actions

    let quickActions: [String] = [
        "Weekly energy forecast",
        "Who should I connect with?",
        "Create a story from my week",
        "Analyze my patterns",
        "What's my vibe today?",
    ]

    // MARK: - ENVI Brain Reference
    //
    // The Brain provides AI-powered insights via its autoresearch loop.
    // In production, ENVIBrain.shared.getChatResponse(query:) returns
    // a ChatInsightResponse with structured insights and follow-up questions.
    // Currently used via askBrain(_:) to augment the mock data pipeline.

    private let brain = ENVIBrain.shared

    // MARK: - Private

    private var typingWorkItem: DispatchWorkItem?

    // MARK: - Mock Thread Data (dev environment only)

    /// Mock threads are only used in `.dev` environment for preview and offline development.
    /// In `.staging` and `.prod`, unmatched queries are routed to the Oracle API.
    private let mockThreads: [String: ChatThread] = {
        guard AppEnvironment.current == .dev else { return [:] }

        var threads: [String: ChatThread] = [:]

        // 1. Weekly energy forecast
        threads["Weekly energy forecast"] = ChatThread(
            question: "Weekly energy forecast",
            paragraphs: [
                "Your upcoming week shows a strong creative arc. Monday through Wednesday carry momentum from last week\u{2019}s focused work sessions \u{2014} your deep-work streaks have been averaging 2.4 hours, up from 1.8 two weeks ago.",
                "Thursday and Friday look ideal for collaborative work. Your interaction patterns suggest you\u{2019}re most receptive to new ideas mid-week, and several of your close connections have been active in overlapping spaces.",
                "Consider blocking Saturday morning for reflection \u{2014} your journaling consistency drops when weekends get busy, and that\u{2019}s when some of your best insights tend to surface.",
            ],
            metrics: [
                ThreadMetric(label: "Alignment", value: "87%", change: "+5%", trend: .up),
                ThreadMetric(label: "Connection", value: "High", change: "↑12%", trend: .up),
                ThreadMetric(label: "Creative", value: "4.2/5", change: "-0.1", trend: .down),
                ThreadMetric(label: "Optimal", value: "2–5 PM", change: "Today", trend: .neutral),
            ],
            relatedQuestions: [
                "How does my energy compare to last month?",
                "What activities boosted my focus this week?",
                "When am I most creative during the day?",
                "Show me my consistency trends",
            ]
        )

        // 2. Who should I connect with?
        threads["Who should I connect with?"] = ChatThread(
            question: "Who should I connect with?",
            paragraphs: [
                "Based on your recent activity, three connections stand out this week. Someone from your design circle has been exploring similar topics \u{2014} your content overlap is at 73%, the highest it\u{2019}s been.",
                "There\u{2019}s also a dormant connection who was very active in your network six months ago. Re-engaging could open up a creative collaboration that aligns with your current interests.",
                "Your close circle has been unusually active this week. A group thread or shared experience could strengthen those bonds while they\u{2019}re naturally engaged.",
            ],
            metrics: [
                ThreadMetric(label: "Active", value: "24", change: "+3", trend: .up),
                ThreadMetric(label: "Overlap", value: "73%", change: "↑8%", trend: .up),
                ThreadMetric(label: "Dormant", value: "5", change: "reachable", trend: .neutral),
                ThreadMetric(label: "Group Energy", value: "High", change: "this week", trend: .up),
            ],
            relatedQuestions: [
                "Show me my strongest connections this month",
                "Who have I been losing touch with?",
                "What topics are trending in my circle?",
                "Create an intro message for a reconnection",
            ]
        )

        // 3. Create a story from my week
        threads["Create a story from my week"] = ChatThread(
            question: "Create a story from my week",
            paragraphs: [
                "Here\u{2019}s a narrative woven from your week\u{2019}s highlights. Tuesday\u{2019}s coffee shop session sparked a burst of ideas \u{2014} you captured 12 notes in 45 minutes, your fastest ideation pace this month.",
                "Wednesday brought an unexpected conversation that shifted your perspective on a project you\u{2019}ve been mulling over. The exchange lasted 23 minutes and touched on themes you haven\u{2019}t explored since last spring.",
                "The week closed with a quiet Friday evening that your patterns suggest was exactly what you needed \u{2014} your wind-down ritual has become more consistent, and it\u{2019}s showing in your morning energy levels.",
            ],
            metrics: [
                ThreadMetric(label: "Story Score", value: "94%", change: "excellent", trend: .up),
                ThreadMetric(label: "Key Moments", value: "7", change: "+2 vs avg", trend: .up),
                ThreadMetric(label: "Mood Arc", value: "Rising", change: "positive", trend: .up),
                ThreadMetric(label: "Shareable", value: "Yes", change: "ready", trend: .neutral),
            ],
            relatedQuestions: [
                "Make it more poetic",
                "Add photos from my week",
                "Share this as a post draft",
                "Compare this week to last week",
            ]
        )

        // 4. Analyze my patterns
        threads["Analyze my patterns"] = ChatThread(
            question: "Analyze my patterns",
            paragraphs: [
                "Looking at the past 30 days, a few clear patterns emerge. Your most productive hours cluster between 2 PM and 5 PM, with a secondary peak around 9 AM. Morning sessions tend to be more analytical, while afternoons skew creative.",
                "Socially, you\u{2019}re in a consolidation phase \u{2014} fewer new connections but deeper engagement with existing ones. Your response time to close friends has improved by 18%, suggesting stronger presence in those relationships.",
                "One pattern worth noting: your best creative days consistently follow nights where you disconnected from screens before 10 PM. The correlation is strong enough to be worth experimenting with intentionally.",
            ],
            metrics: [
                ThreadMetric(label: "Clarity", value: "91%", change: "high confidence", trend: .up),
                ThreadMetric(label: "Peak Hours", value: "2–5 PM", change: "consistent", trend: .neutral),
                ThreadMetric(label: "Social Depth", value: "+18%", change: "improving", trend: .up),
                ThreadMetric(label: "Screen-Off", value: "Strong", change: "↑ correlation", trend: .up),
            ],
            relatedQuestions: [
                "How can I optimize my peak hours?",
                "Show me my sleep-creativity correlation",
                "What habits should I build on?",
                "Compare my patterns to last quarter",
            ]
        )

        // 5. What's my vibe today?
        threads["What's my vibe today?"] = ChatThread(
            question: "What's my vibe today?",
            paragraphs: [
                "Today has a calm, focused energy about it. Your morning started slower than usual, but that\u{2019}s aligning well with the reflective mode you\u{2019}ve been in this week. No need to force productivity early \u{2014} your momentum will build naturally.",
                "The signals suggest this is a good day for deep work on personal projects. Your creative indicators are above baseline, and there\u{2019}s a gentle pull toward introspection that could yield meaningful output.",
                "If you\u{2019}re looking for connection today, lean into one-on-one conversations rather than group settings. Your energy profile suggests intimate exchanges will feel more rewarding right now.",
            ],
            metrics: [
                ThreadMetric(label: "Vibe", value: "Calm Focus", change: "balanced", trend: .neutral),
                ThreadMetric(label: "Creative", value: "4.1/5", change: "+0.4", trend: .up),
                ThreadMetric(label: "Social", value: "72%", change: "steady", trend: .neutral),
                ThreadMetric(label: "Best For", value: "Deep Work", change: "today", trend: .up),
            ],
            relatedQuestions: [
                "What should I work on today?",
                "Play me a mood-matched playlist",
                "Who\u{2019}s on a similar vibe right now?",
                "Set an intention for today",
            ]
        )

        return threads
    }()

    // MARK: - Default Thread (dev-only fallback for unrecognized queries)

    /// Default mock thread used only in `.dev` environment. In staging/prod,
    /// unrecognized queries go through the Oracle API instead.
    private let defaultThread = ChatThread(
        question: "",
        paragraphs: [
            "I\u{2019}ve been observing your patterns over the past few weeks, and there are some interesting threads emerging. Your creative output tends to peak in the late afternoon, especially after social interactions earlier in the day.",
            "Looking at your content pieces, your engagement patterns suggest a preference for depth over breadth right now \u{2014} fewer but more meaningful interactions, longer content creation sessions, and more reflective moments.",
            "This is a strong foundation. The consistency you\u{2019}ve been building compounds over time, and the signals are pointing in a positive direction.",
        ],
        metrics: [
            ThreadMetric(label: "Alignment", value: "82%", change: "+3%", trend: .up),
            ThreadMetric(label: "Focus", value: "Deep", change: "↑ steady", trend: .up),
            ThreadMetric(label: "Quality", value: "4.5/5", change: "+0.3", trend: .up),
            ThreadMetric(label: "Pattern", value: "91%", change: "strong", trend: .neutral),
        ],
        relatedQuestions: [
            "What does my week look like?",
            "Help me draft a reflection post",
            "Show me my growth trajectory",
            "What should I focus on next?",
        ]
    )

    // MARK: - Actions

    /// Send the current `inputText` as a message.
    func sendMessage() {
        let query = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        inputText = ""
        startThread(query)
    }

    /// Trigger a thread from one of the quick-action chips.
    func selectQuickAction(_ action: String) {
        inputText = action
        sendMessage()
    }

    /// Look up (or fall back to default) mock data, simulate typing, then reveal the thread.
    func startThread(_ query: String) {
        // Cancel any in-flight typing simulation
        typingWorkItem?.cancel()

        isHome = false
        isTyping = true

        Task { @MainActor in
            let resolved = await resolveThread(for: query)
            activeThread = resolved
            isTyping = false
        }
    }

    /// Reset to the home / empty state.
    func resetToHome() {
        typingWorkItem?.cancel()
        activeThread = nil
        isTyping = false
        isHome = true
        inputText = ""
    }

    // MARK: - ENVI Brain Integration

    /// Ask the ENVI Brain for an insight-backed ChatThread.
    ///
    /// Maps content-strategy queries to Brain insights. Returns nil for
    /// queries the Brain doesn't handle (e.g. personal energy, social),
    /// allowing the mock data fallback to take over.
    ///
    /// In production, this would be the primary path — the Brain's
    /// InsightGenerator would handle all queries, and mock data would
    /// only exist for offline/preview scenarios.
    func askBrain(_ query: String) -> ChatThread? {
        let lowered = query.lowercased()

        // Content-strategy keywords that the ENVI Brain can answer
        let brainKeywords = [
            "content", "publish", "post", "engagement", "trend",
            "optimize", "repurpose", "performance", "analytics",
            "schedule", "platform", "carousel", "reel", "video",
            "audience", "growth", "recommend", "predict", "gap",
        ]

        let isBrainQuery = brainKeywords.contains { lowered.contains($0) }
        guard isBrainQuery else { return nil }

        // Query the Brain's InsightGenerator via the chat response API
        let response = brain.getChatResponse(query: query)

        // Convert Brain insights into ThreadMetrics for the chat UI
        let metrics: [ThreadMetric] = response.insights.prefix(4).map { insight in
            let trend: MetricTrend
            // Map insight confidence to a trend indicator
            if insight.confidence >= 0.85 {
                trend = .up
            } else if insight.confidence >= 0.70 {
                trend = .neutral
            } else {
                trend = .down
            }

            return ThreadMetric(
                label: insight.title.components(separatedBy: " ").prefix(2).joined(separator: " "),
                value: insight.dataPoints.first?.value ?? "\(Int(insight.confidence * 100))%",
                change: insight.dataPoints.first.flatMap { $0.change } ?? "",
                trend: trend
            )
        }

        // Build paragraphs from the Brain's response message + insight bodies
        var paragraphs = [response.message]
        paragraphs += response.insights.prefix(2).map { $0.body }

        return ChatThread(
            question: query,
            paragraphs: paragraphs,
            metrics: metrics.isEmpty ? defaultThread.metrics : metrics,
            relatedQuestions: response.suggestedFollowUps.isEmpty
                ? defaultThread.relatedQuestions
                : response.suggestedFollowUps
        )
    }

    @MainActor
    private func resolveThread(for query: String) async -> ChatThread {
        errorMessage = nil

        // 1. Try Oracle endpoint if enabled
        if AppConfig.isOracleEnabled,
           let oracleThread = await fetchOracleThread(query) {
            return oracleThread
        }

        // 2. Try ENVI Brain for content-strategy queries
        if let brainThread = askBrain(query) {
            return brainThread
        }

        // 3. Dev environment: fall back to mock data
        if AppEnvironment.current == .dev {
            if let matched = mockThreads[query] {
                return matched
            }
            return ChatThread(
                question: query,
                paragraphs: defaultThread.paragraphs,
                metrics: defaultThread.metrics,
                relatedQuestions: defaultThread.relatedQuestions
            )
        }

        // 4. Staging/prod: call Oracle API as the fallback path
        do {
            let oracleResponse = try await fetchOracleResponse(prompt: query)
            return ChatThread(
                question: query,
                paragraphs: [oracleResponse.message],
                metrics: [],
                relatedQuestions: oracleResponse.suggestedFollowUps
            )
        } catch {
            errorMessage = "Unable to reach Oracle. Please try again."
            return ChatThread(
                question: query,
                paragraphs: ["Something went wrong while fetching your response. Please try again in a moment."],
                metrics: [],
                relatedQuestions: []
            )
        }
    }

    // MARK: - Oracle API

    /// Fetch a full chat thread from the Oracle API client (used when Oracle is explicitly enabled).
    private func fetchOracleThread(_ query: String) async -> ChatThread? {
        do {
            return try await OracleAPIClient.shared.fetchThread(query: query)
        } catch {
            return nil
        }
    }

    /// Call the `oracle/chat` endpoint directly and return the raw `OracleResponse`.
    ///
    /// Used as the production fallback when neither the Oracle feature flag
    /// nor the ENVI Brain can handle a query.
    func fetchOracleResponse(prompt: String, threadId: String? = nil) async throws -> OracleResponse {
        let response: OracleResponse = try await APIClient.shared.request(
            endpoint: "oracle/chat",
            method: .post,
            body: OracleChatRequest(prompt: prompt, threadId: threadId),
            requiresAuth: true
        )
        return response
    }
}
