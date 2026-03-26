import SwiftUI

/// Thread response view — shows the user's question, AI response paragraphs,
/// a 2×2 metrics grid, and related questions for exploration.
struct EnhancedThreadView: View {
    let thread: ChatThread
    let isTyping: Bool
    let onRelatedQuestion: (String) -> Void
    let onBack: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    init(
        thread: ChatThread,
        isTyping: Bool = false,
        onRelatedQuestion: @escaping (String) -> Void,
        onBack: (() -> Void)? = nil
    ) {
        self.thread = thread
        self.isTyping = isTyping
        self.onRelatedQuestion = onRelatedQuestion
        self.onBack = onBack
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: - User question header
                questionSection

                // MARK: - Divider
                Rectangle()
                    .fill(ENVITheme.border(for: colorScheme))
                    .frame(height: 1)
                    .padding(.bottom, ENVISpacing.xxxl)

                // MARK: - AI response (or typing indicator)
                if isTyping {
                    TypingDotsView()
                } else {
                    responseSection
                }
            }
            .padding(.horizontal, ENVISpacing.xxl)
            .padding(.top, ENVISpacing.xxxl)
            .padding(.bottom, 120) // space for input bar
        }
    }

    // MARK: - Question Section

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            // "[01]" + "YOUR QUESTION" label
            HStack(spacing: ENVISpacing.md) {
                Text("[01]")
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.text(for: colorScheme).opacity(0.3))

                Text("YOUR QUESTION")
                    .font(.spaceMonoBold(11))
                    .tracking(11 * 0.15) // 0.15em tracking
                    .foregroundColor(ENVITheme.text(for: colorScheme).opacity(0.5))
            }

            // Question as large heading
            Text(thread.question.uppercased())
                .font(.interBlack(28))
                .tracking(-0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, ENVISpacing.xxxl)
    }

    // MARK: - Response Section

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            // "✦ ENVI AI RESPONSE" label
            Text("✦  ENVI AI RESPONSE")
                .font(.spaceMonoBold(11))
                .tracking(11 * 0.15) // 0.15em tracking
                .foregroundColor(ENVITheme.text(for: colorScheme).opacity(0.5))
                .padding(.bottom, ENVISpacing.xl)

            // Response paragraphs
            VStack(alignment: .leading, spacing: ENVISpacing.lg) {
                ForEach(Array(thread.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(.interRegular(14))
                        .foregroundColor(ENVITheme.text(for: colorScheme).opacity(0.75))
                        .lineSpacing(14 * 0.7) // ~1.7 line height
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, ENVISpacing.xxxl)

            // MARK: - Metrics grid (2×2)
            if !thread.metrics.isEmpty {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 0),
                        GridItem(.flexible(), spacing: 0),
                    ],
                    spacing: 0
                ) {
                    ForEach(thread.metrics) { metric in
                        MetricCardView(metric: metric)
                    }
                }
                .padding(.bottom, ENVISpacing.xxxl)
            }

            // MARK: - Divider
            Rectangle()
                .fill(ENVITheme.border(for: colorScheme))
                .frame(height: 1)
                .padding(.bottom, ENVISpacing.xxxl)

            // MARK: - Explore more
            Text("EXPLORE MORE")
                .font(.spaceMonoBold(11))
                .tracking(11 * 0.15) // 0.15em tracking
                .foregroundColor(ENVITheme.text(for: colorScheme).opacity(0.5))
                .padding(.bottom, ENVISpacing.lg)

            // Related questions
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(thread.relatedQuestions.enumerated()), id: \.offset) { index, question in
                    Button(action: { onRelatedQuestion(question) }) {
                        HStack {
                            Text(question)
                                .font(.interMedium(13))
                                .foregroundColor(ENVITheme.text(for: colorScheme).opacity(0.6))
                                .multilineTextAlignment(.leading)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(ENVITheme.text(for: colorScheme).opacity(0.3))
                        }
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Divider between items (not after last)
                    if index < thread.relatedQuestions.count - 1 {
                        Rectangle()
                            .fill(ENVITheme.border(for: colorScheme))
                            .frame(height: 1)
                    }
                }
            }
        }
    }
}

#Preview {
    let thread = ChatThread(
        question: "Weekly energy forecast",
        paragraphs: [
            "Your upcoming week shows a strong creative arc. Monday through Wednesday carry momentum from last week's focused work sessions.",
            "Thursday and Friday look ideal for collaborative work. Your interaction patterns suggest you're most receptive to new ideas mid-week.",
            "Consider blocking Saturday morning for reflection — your journaling consistency drops when weekends get busy.",
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

    EnhancedThreadView(
        thread: thread,
        isTyping: false,
        onRelatedQuestion: { _ in }
    )
    .background(Color.black)
    .preferredColorScheme(.dark)
}
