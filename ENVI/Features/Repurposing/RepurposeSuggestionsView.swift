import SwiftUI

/// AI-powered suggestions for repurposing top-performing content into new formats.
struct RepurposeSuggestionsView: View {
    @ObservedObject var viewModel: RepurposingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header

                if viewModel.isLoadingSuggestions {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else if viewModel.suggestions.isEmpty {
                    emptyState
                } else {
                    suggestionsList
                }
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text("Repurpose Suggestions")
                .font(.interSemiBold(22))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("AI recommendations based on your top-performing content.")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Suggestions List

    private var suggestionsList: some View {
        VStack(spacing: ENVISpacing.md) {
            ForEach(viewModel.suggestions) { suggestion in
                suggestionCard(suggestion)
            }
        }
    }

    // MARK: - Suggestion Card

    private func suggestionCard(_ suggestion: RepurposeSuggestion) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            HStack(spacing: ENVISpacing.sm) {
                Image(systemName: suggestion.targetFormat.systemImage)
                    .font(.system(size: 16))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .frame(width: 32, height: 32)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Repurpose as \(suggestion.targetFormat.displayName)")
                        .font(.interSemiBold(15))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    if suggestion.estimatedEngagement > 0 {
                        Text("Est. reach: \(formattedEngagement(suggestion.estimatedEngagement))")
                            .font(.interRegular(12))
                            .foregroundColor(ENVITheme.success)
                    }
                }

                Spacer()
            }

            Text(suggestion.reason)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                viewModel.selectedTargetFormats = [suggestion.targetFormat]
            } label: {
                Text("Use Suggestion")
                    .font(.interMedium(13))
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.md)
                            .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                    )
            }
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: ENVISpacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("No suggestions yet")
                .font(.interMedium(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Publish more content to unlock AI-powered repurposing suggestions.")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ENVISpacing.xxxl)
    }

    // MARK: - Helpers

    private func formattedEngagement(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fK", value / 1000)
        }
        return "\(Int(value))"
    }
}

// MARK: - Preview

#Preview {
    RepurposeSuggestionsView(viewModel: RepurposingViewModel())
}
