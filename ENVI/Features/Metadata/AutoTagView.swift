import SwiftUI

/// AI auto-tagging results view with accept/reject per suggestion.
struct AutoTagView: View {
    @ObservedObject var viewModel: MetadataViewModel
    let assetID: UUID
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                statusBanner

                if viewModel.isGenerating {
                    generatingState
                } else if viewModel.suggestions.isEmpty {
                    emptyState
                } else {
                    suggestionList
                    applyButton
                }

                if let error = viewModel.autoTagError {
                    Text(error)
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.error)
                        .padding(.horizontal, ENVISpacing.xl)
                }
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .task {
            await viewModel.autoGenerateTags(for: assetID)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text("AUTO-TAG")
                .font(.spaceMonoBold(17))
                .tracking(-0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("AI-suggested tags for this content")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Status Banner

    private var statusBanner: some View {
        HStack(spacing: ENVISpacing.lg) {
            statusPill(
                count: viewModel.acceptedSuggestions.count,
                label: "Accepted",
                color: ENVITheme.success
            )
            statusPill(
                count: viewModel.rejectedSuggestions.count,
                label: "Rejected",
                color: ENVITheme.error
            )
            statusPill(
                count: viewModel.pendingSuggestions.count,
                label: "Pending",
                color: ENVITheme.warning
            )
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func statusPill(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: ENVISpacing.xs) {
            Text("\(count)")
                .font(.interBold(20))
                .foregroundColor(ENVITheme.text(for: colorScheme))
            Text(label)
                .font(.interRegular(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ENVISpacing.md)
        .background(color.opacity(0.1))
        .cornerRadius(ENVIRadius.sm)
    }

    // MARK: - Suggestion List

    private var suggestionList: some View {
        VStack(spacing: ENVISpacing.sm) {
            ForEach(viewModel.suggestions) { suggestion in
                suggestionRow(suggestion)
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func suggestionRow(_ suggestion: TagSuggestion) -> some View {
        let isAccepted = viewModel.acceptedSuggestions.contains(suggestion.id)
        let isRejected = viewModel.rejectedSuggestions.contains(suggestion.id)

        return HStack(spacing: ENVISpacing.md) {
            // Color dot
            Circle()
                .fill(Color(hex: suggestion.tag.color))
                .frame(width: 10, height: 10)

            // Tag info
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.tag.name)
                    .font(.interSemiBold(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .strikethrough(isRejected)

                HStack(spacing: ENVISpacing.sm) {
                    Text(suggestion.tag.category.displayName)
                        .font(.interRegular(11))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    Text("\(suggestion.confidencePercent)% confidence")
                        .font(.interRegular(11))
                        .foregroundColor(confidenceColor(suggestion.confidence))

                    Text(suggestion.source.rawValue.uppercased())
                        .font(.spaceMonoBold(9))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(ENVITheme.surfaceHigh(for: colorScheme))
                        .cornerRadius(3)
                }
            }

            Spacer()

            // Accept / Reject buttons
            HStack(spacing: ENVISpacing.sm) {
                Button {
                    viewModel.rejectSuggestion(suggestion)
                } label: {
                    Image(systemName: isRejected ? "xmark.circle.fill" : "xmark.circle")
                        .font(.system(size: 22))
                        .foregroundColor(isRejected ? ENVITheme.error : ENVITheme.textSecondary(for: colorScheme))
                }

                Button {
                    viewModel.acceptSuggestion(suggestion)
                } label: {
                    Image(systemName: isAccepted ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: 22))
                        .foregroundColor(isAccepted ? ENVITheme.success : ENVITheme.textSecondary(for: colorScheme))
                }
            }
        }
        .padding(ENVISpacing.md)
        .background(
            isAccepted ? ENVITheme.success.opacity(0.05) :
            isRejected ? ENVITheme.error.opacity(0.05) :
            ENVITheme.surfaceLow(for: colorScheme)
        )
        .cornerRadius(ENVIRadius.md)
    }

    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 { return ENVITheme.success }
        if confidence >= 0.6 { return ENVITheme.warning }
        return ENVITheme.error
    }

    // MARK: - Apply Button

    private var applyButton: some View {
        Button {
            Task { await viewModel.applyAcceptedSuggestions(to: assetID) }
        } label: {
            Text("Apply \(viewModel.acceptedSuggestions.count) Tags")
                .font(.interSemiBold(15))
                .foregroundColor(ENVITheme.background(for: colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, ENVISpacing.md)
                .background(
                    viewModel.acceptedSuggestions.isEmpty
                        ? ENVITheme.textSecondary(for: colorScheme)
                        : ENVITheme.text(for: colorScheme)
                )
                .cornerRadius(ENVIRadius.lg)
        }
        .disabled(viewModel.acceptedSuggestions.isEmpty)
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - States

    private var generatingState: some View {
        VStack(spacing: ENVISpacing.lg) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Analyzing content...")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    private var emptyState: some View {
        VStack(spacing: ENVISpacing.md) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 32))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("No suggestions available")
                .font(.interSemiBold(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Button {
                Task { await viewModel.autoGenerateTags(for: assetID) }
            } label: {
                Text("Try Again")
                    .font(.interSemiBold(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.lg)
                    .padding(.vertical, ENVISpacing.sm)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .cornerRadius(ENVIRadius.sm)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ENVISpacing.xxxxl)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    AutoTagView(
        viewModel: MetadataViewModel(repository: MockMetadataRepository()),
        assetID: UUID()
    )
}
#endif
