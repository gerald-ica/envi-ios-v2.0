import SwiftUI

/// Suggestion pills shown after an AI answer.
struct RelatedQuestionsView: View {
    let questions: [String]
    var onSelect: ((String) -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("RELATED")
                .font(.spaceMono(10))
                .tracking(0.80)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            ForEach(questions, id: \.self) { question in
                Button(action: { onSelect?(question) }) {
                    HStack(spacing: ENVISpacing.sm) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(ENVITheme.primary(for: colorScheme))

                        Text(question)
                            .font(.interRegular(13))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, ENVISpacing.md)
                    .padding(.vertical, ENVISpacing.sm)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(Capsule())
                }
            }
        }
    }
}
