import SwiftUI

/// Q&A thread view showing conversation messages.
struct ThreadView: View {
    let messages: [ChatMessage]
    var onRelatedSelect: ((String) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LazyVStack(alignment: .leading, spacing: ENVISpacing.xl) {
            ForEach(messages) { message in
                switch message.role {
                case .user:
                    UserMessageView(message: message)
                case .assistant:
                    AssistantMessageView(
                        message: message,
                        onRelatedSelect: onRelatedSelect
                    )
                }
            }
        }
    }
}

private struct UserMessageView: View {
    let message: ChatMessage
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(message.content)
            .font(.spaceMonoBold(20))
            .tracking(-0.5)
            .foregroundColor(ENVITheme.text(for: colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AssistantMessageView: View {
    let message: ChatMessage
    var onRelatedSelect: ((String) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.lg) {
            ENVIBadge(text: "ENVI ANSWER", color: ENVITheme.primary(for: colorScheme))

            Text(message.content)
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            if let dataCard = message.dataCard {
                DataCardView(dataCard: dataCard)
            }

            if let related = message.relatedQuestions, !related.isEmpty {
                RelatedQuestionsView(
                    questions: related,
                    onSelect: onRelatedSelect
                )
            }
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }
}
