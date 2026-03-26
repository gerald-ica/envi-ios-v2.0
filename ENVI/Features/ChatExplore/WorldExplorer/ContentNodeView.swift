import SwiftUI

// MARK: - Content Node View (Detail Overlay)

/// Glass-morphic dark card that appears when a node is tapped.
/// Shows content metadata, AI score, metrics, suggestion, and action buttons.
struct ContentNodeView: View {

    let content: ContentPiece
    let onClose: () -> Void

    var body: some View {
        ZStack {
            // Full-screen backdrop
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            // Scrollable card
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Close button
                    HStack {
                        Spacer()
                        closeButton
                    }
                    .padding(.bottom, ENVISpacing.lg)

                    // Content image preview
                    imagePreview
                        .padding(.bottom, ENVISpacing.xl)

                    // Platform + date
                    platformRow
                        .padding(.bottom, ENVISpacing.md)

                    // Title
                    Text(content.title.uppercased())
                        .font(.interExtraBold(24))
                        .tracking(-0.5)
                        .foregroundColor(.white)
                        .padding(.bottom, ENVISpacing.md)

                    // Description
                    Text(content.description)
                        .font(.spaceMono(12))
                        .foregroundColor(.white.opacity(0.6))
                        .lineSpacing(4)
                        .padding(.bottom, ENVISpacing.lg)

                    // Tags
                    tagsRow
                        .padding(.bottom, ENVISpacing.lg)

                    divider

                    // AI Score
                    aiScoreSection
                        .padding(.bottom, ENVISpacing.lg)

                    divider

                    // Metrics
                    if content.metrics != nil {
                        metricsGrid
                            .padding(.bottom, ENVISpacing.lg)

                        divider
                    }

                    // AI Suggestion
                    if let suggestion = content.aiSuggestion {
                        aiSuggestionCard(suggestion)
                            .padding(.bottom, ENVISpacing.lg)

                        divider
                    }

                    // Action buttons
                    actionButtons
                        .padding(.top, ENVISpacing.sm)
                }
                .padding(.horizontal, ENVISpacing.xxl)
                .padding(.vertical, ENVISpacing.xl)
            }
            .frame(maxWidth: 400)
            .background(
                RoundedRectangle(cornerRadius: ENVIRadius.xl)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.xl)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, ENVISpacing.lg)
            .padding(.vertical, ENVISpacing.xxxxl)
        }
    }

    // MARK: - Subviews

    private var closeButton: some View {
        Button(action: onClose) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 36, height: 36)
                Circle()
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    .frame(width: 36, height: 36)
                Text("×")
                    .font(.spaceMono(18))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    private var imagePreview: some View {
        ZStack(alignment: .topLeading) {
            // Content image
            Group {
                if let uiImage = UIImage(named: content.imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(4.0 / 5.0, contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(ENVITheme.Dark.surfaceLow)
                        .aspectRatio(4.0 / 5.0, contentMode: .fill)
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )

            // Video play button overlay
            if content.type == .video || content.type == .reel {
                ZStack {
                    Color.black.opacity(0.3)
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .offset(x: 2)
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            }

            // Type badge (top-left)
            HStack(spacing: ENVISpacing.sm) {
                typeBadge
                Spacer()
                scoreBadge
            }
            .padding(ENVISpacing.md)
        }
    }

    private var typeBadge: some View {
        Text(content.type.label)
            .font(.spaceMonoBold(10))
            .tracking(2.0)
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, ENVISpacing.sm)
            .padding(.vertical, ENVISpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: ENVIRadius.sm)
                    .fill(Color.black.opacity(0.7))
                    .background(.ultraThinMaterial.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.sm)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
    }

    private var scoreBadge: some View {
        HStack(spacing: ENVISpacing.xs) {
            Circle()
                .fill(scoreColor(for: content.aiScore))
                .frame(width: 6, height: 6)
            Text("\(content.aiScore)")
                .font(.spaceMonoBold(10))
                .tracking(2.0)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, ENVISpacing.sm)
        .padding(.vertical, ENVISpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                .fill(Color.black.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    private var platformRow: some View {
        HStack(spacing: ENVISpacing.sm) {
            Text(content.platform.label.uppercased())
                .font(.spaceMonoBold(10))
                .tracking(2.0)
                .foregroundColor(content.platform.color)

            Text("•")
                .font(.spaceMonoBold(10))
                .foregroundColor(.white.opacity(0.3))

            Text(formattedDate(content.createdAt).uppercased())
                .font(.spaceMono(10))
                .tracking(2.0)
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var tagsRow: some View {
        FlowLayout(spacing: ENVISpacing.xs) {
            ForEach(content.tags, id: \.self) { tag in
                Text(tag.uppercased())
                    .font(.spaceMono(10))
                    .tracking(1.0)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, ENVISpacing.sm)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: ENVIRadius.sm)
                            .fill(Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.sm)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
            }
        }
    }

    private var aiScoreSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("ENVI AI SCORE")
                .font(.spaceMonoBold(10))
                .tracking(2.5)
                .foregroundColor(.white.opacity(0.35))

            VStack(alignment: .leading, spacing: ENVISpacing.md) {
                HStack(spacing: ENVISpacing.md) {
                    // Score with progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 3)
                            .frame(width: 56, height: 56)
                        Circle()
                            .trim(from: 0, to: CGFloat(content.aiScore) / 100.0)
                            .stroke(
                                scoreColor(for: content.aiScore),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: 56, height: 56)
                            .rotationEffect(.degrees(-90))

                        Text("\(content.aiScore)")
                            .font(.interExtraBold(20))
                            .foregroundColor(scoreColor(for: content.aiScore))
                    }

                    // Progress bar
                    VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                        Text(scoreLabel(for: content.aiScore).uppercased())
                            .font(.spaceMonoBold(10))
                            .tracking(2.0)
                            .foregroundColor(.white.opacity(0.5))

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(scoreColor(for: content.aiScore))
                                    .frame(
                                        width: geo.size.width * CGFloat(content.aiScore) / 100.0,
                                        height: 4
                                    )
                            }
                        }
                        .frame(height: 4)
                    }
                }
            }
            .padding(ENVISpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.5)
            )
        }
    }

    private var metricsGrid: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("PERFORMANCE")
                .font(.spaceMonoBold(10))
                .tracking(2.5)
                .foregroundColor(.white.opacity(0.35))

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: ENVISpacing.md),
                GridItem(.flexible(), spacing: ENVISpacing.md)
            ], spacing: ENVISpacing.md) {
                if let views = content.metrics?.views {
                    metricCell(label: "VIEWS", value: views.formattedShort)
                }
                if let likes = content.metrics?.likes {
                    metricCell(label: "LIKES", value: likes.formattedShort)
                }
                if let shares = content.metrics?.shares {
                    metricCell(label: "SHARES", value: shares.formattedShort)
                }
                if let comments = content.metrics?.comments {
                    metricCell(label: "COMMENTS", value: comments.formattedShort)
                }
            }
        }
    }

    private func metricCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text(label)
                .font(.spaceMono(10))
                .tracking(1.5)
                .foregroundColor(.white.opacity(0.4))
            Text(value)
                .font(.interBold(18))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ENVISpacing.md)
        .background(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.5)
        )
    }

    private func aiSuggestionCard(_ suggestion: String) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            HStack(spacing: ENVISpacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ENVITheme.Dark.accent)
                Text("AI SUGGESTION")
                    .font(.spaceMonoBold(10))
                    .tracking(2.5)
                    .foregroundColor(.white.opacity(0.35))
            }

            VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                HStack(spacing: ENVISpacing.sm) {
                    Text("AI TIP:")
                        .font(.spaceMonoBold(11))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }

                Text(suggestion)
                    .font(.spaceMono(11))
                    .foregroundColor(.white.opacity(0.5))
                    .lineSpacing(3)
            }
            .padding(ENVISpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .fill(ENVITheme.Dark.accent.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .strokeBorder(ENVITheme.Dark.accent.opacity(0.2), lineWidth: 0.5)
            )
        }
    }

    private var actionButtons: some View {
        HStack(spacing: ENVISpacing.md) {
            // Edit button
            Button(action: {}) {
                Text(editLabel.uppercased())
                    .font(.interBold(13))
                    .tracking(1.5)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ENVISpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: ENVIRadius.lg)
                            .fill(ENVITheme.Dark.accent)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.lg)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }

            // Share button
            Button(action: {}) {
                HStack(spacing: ENVISpacing.sm) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                    Text("SHARE")
                        .font(.interBold(13))
                        .tracking(1.5)
                }
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, ENVISpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: ENVIRadius.lg)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.lg)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 0.5)
            .padding(.vertical, ENVISpacing.md)
    }

    // MARK: - Helpers

    private var editLabel: String {
        switch content.type {
        case .video, .reel:     return "Edit in Video Editor"
        case .carousel:         return "Edit Carousel"
        case .photo, .story:    return "Edit in Photo Editor"
        }
    }

    private func scoreLabel(for score: Int) -> String {
        if score >= 90 { return "Excellent" }
        if score >= 80 { return "Good" }
        if score >= 70 { return "Average" }
        return "Needs Work"
    }

    private func formattedDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return dateStr }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d"
        return displayFormatter.string(from: date)
    }
}

