import SwiftUI

// MARK: - Waterfall Suggestions
// Uses WaterfallSuggestion from Models/WaterfallSuggestion.swift (canonical definition).
// Suggestions are accessed via WaterfallSuggestion.suggestions(for:).

// MARK: - Content Node View (Detail Overlay)

/// Full-screen detail view when content is selected. Matches the React detail panel (lines 1336-1571)
/// including waterfall suggestions, related content, video play overlay, type-specific CTA.
struct ContentNodeView: View {

    let content: ContentPiece
    var lightMode: Bool = false
    let onClose: () -> Void
    var onNavigateToContent: ((ContentPiece) -> Void)?

    var body: some View {
        ZStack {
            // Full-screen backdrop
            (lightMode ? Color.white.opacity(0.9) : Color.black.opacity(0.9))
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .onTapGesture { onClose() }

            // Two-column layout (stacked on narrow screens)
            GeometryReader { geo in
                let isWide = geo.size.width > 700

                if isWide {
                    HStack(spacing: 0) {
                        previewArea
                            .frame(maxWidth: .infinity)
                        metadataPanel
                            .frame(width: 420)
                    }
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            previewArea
                                .frame(height: geo.size.height * 0.45)
                            metadataPanel
                        }
                    }
                }
            }
        }
    }

    // MARK: - Preview Area (Left side)

    private var previewArea: some View {
        VStack {
            Spacer()
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
                .frame(maxWidth: 560)
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.lg)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )

                // Video play overlay for video/reel types
                if content.type == .video || content.type == .reel {
                    ZStack {
                        Color.black.opacity(0.3)
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 64, height: 64)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(
                                Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                                    .offset(x: 2)
                            )
                    }
                    .frame(maxWidth: 560)
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
                }

                // Type badge (top-left) + AI Score badge (top-right)
                HStack(spacing: ENVISpacing.sm) {
                    typeBadge
                    Spacer()
                    scoreBadge
                }
                .padding(ENVISpacing.md)
            }
            .frame(maxWidth: 560)
            Spacer()
        }
        .padding(.horizontal, ENVISpacing.xxl)
    }

    // MARK: - Metadata Panel (Right side)

    private var metadataPanel: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    closeButton
                }
                .padding(.bottom, ENVISpacing.xxl)

                // Platform + date
                platformRow
                    .padding(.bottom, ENVISpacing.lg)

                // Title (Inter Black 26px uppercase tracking-tight)
                Text(content.title.uppercased())
                    .font(.interBlack(26))
                    .tracking(-0.5)
                    .lineSpacing(0)
                    .foregroundColor(lightMode ? .black : .white)
                    .padding(.bottom, ENVISpacing.xl)

                // Description (SpaceMono 12px line-height 1.7)
                Text(content.description)
                    .font(.spaceMono(12))
                    .foregroundColor(lightMode ? .black.opacity(0.55) : .white.opacity(0.6))
                    .lineSpacing(4.5)
                    .padding(.bottom, ENVISpacing.xxl)

                // Content source context
                Text(content.isFuture ? "✦ AI RECOMMENDED" : "From your content library")
                    .font(.spaceMono(10))
                    .tracking(1.0)
                    .foregroundColor(content.isFuture
                        ? Color(hex: "#3B82F6").opacity(0.8)
                        : (lightMode ? .black.opacity(0.25) : .white.opacity(0.25)))
                    .padding(.bottom, ENVISpacing.md)

                // Tags
                tagsRow
                    .padding(.bottom, ENVISpacing.xxl)

                divider

                // Future content: predicted engagement + confidence + AI explanation
                if content.isFuture {
                    futurePredictionSection
                        .padding(.bottom, ENVISpacing.xxl)
                }

                // Metrics (only for past content with real data)
                if !content.isFuture, content.metrics != nil {
                    metricsSection
                        .padding(.bottom, ENVISpacing.xxl)
                }

                // AI Score section
                aiScoreSection
                    .padding(.bottom, ENVISpacing.xxl)

                divider

                // Related content
                relatedContentSection
                    .padding(.bottom, ENVISpacing.xxl)

                divider

                // Waterfall — Repurpose suggestions
                waterfallSection
                    .padding(.bottom, ENVISpacing.xxl)

                divider

                // Edit CTA
                editCTAButton
                    .padding(.top, ENVISpacing.sm)
            }
            .padding(.horizontal, ENVISpacing.xxl)
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(
            (lightMode
                ? Color.white.opacity(0.8)
                : Color.black.opacity(0.6))
                .background(.ultraThinMaterial)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(lightMode ? Color.black.opacity(0.05) : Color.white.opacity(0.05))
                .frame(width: 0.5)
        }
    }

    // MARK: - Subviews

    private var closeButton: some View {
        Button(action: onClose) {
            ZStack {
                Circle()
                    .fill(lightMode ? Color.black.opacity(0.05) : Color.white.opacity(0.05))
                    .frame(width: 36, height: 36)
                Circle()
                    .strokeBorder(
                        lightMode ? Color.black.opacity(0.1) : Color.white.opacity(0.15),
                        lineWidth: 1
                    )
                    .frame(width: 36, height: 36)
                Text("×")
                    .font(.spaceMono(16))
                    .foregroundColor(lightMode ? .black.opacity(0.5) : .white.opacity(0.5))
            }
        }
    }

    private var typeBadge: some View {
        Group {
            if content.isFuture {
                // AI PREDICTION badge for future content
                HStack(spacing: 4) {
                    Text("✦")
                        .font(.system(size: 9))
                    Text("AI PREDICTION")
                        .font(.spaceMonoBold(10))
                        .tracking(2.0)
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, ENVISpacing.sm)
                .padding(.vertical, ENVISpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: ENVIRadius.sm)
                        .fill(Color(hex: "#30217C").opacity(0.85))
                        .background(.ultraThinMaterial.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.sm)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                )
            } else {
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
        }
    }

    private var scoreBadge: some View {
        Group {
            if content.isFuture, let confidence = content.confidenceScore {
                HStack(spacing: ENVISpacing.xs) {
                    Circle()
                        .fill(Color(hex: "#3B82F6"))
                        .frame(width: 6, height: 6)
                    Text("\(confidence)%")
                        .font(.spaceMonoBold(10))
                        .tracking(2.0)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, ENVISpacing.sm)
                .padding(.vertical, ENVISpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: ENVIRadius.sm)
                        .fill(Color(hex: "#30217C").opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.sm)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                )
            } else {
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
        }
    }

    private var platformRow: some View {
        HStack(spacing: ENVISpacing.sm) {
            Text(content.platform.label.uppercased())
                .font(.spaceMonoBold(10))
                .tracking(2.0)
                .foregroundColor(content.platform.color)

            Text("•")
                .font(.spaceMonoBold(10))
                .foregroundColor(lightMode ? .black.opacity(0.25) : .white.opacity(0.3))

            Text(formattedDate(content.createdAt).uppercased())
                .font(.spaceMono(10))
                .tracking(2.0)
                .foregroundColor(lightMode ? .black.opacity(0.45) : .white.opacity(0.5))
        }
    }

    private var tagsRow: some View {
        FlowLayout(spacing: ENVISpacing.xs) {
            ForEach(content.tags, id: \.self) { tag in
                Text(tag.uppercased())
                    .font(.spaceMono(10))
                    .tracking(1.0)
                    .foregroundColor(lightMode ? .black.opacity(0.5) : .white.opacity(0.5))
                    .padding(.horizontal, ENVISpacing.sm)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: ENVIRadius.sm)
                            .fill(lightMode ? Color.black.opacity(0.05) : Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.sm)
                            .strokeBorder(lightMode ? Color.black.opacity(0.1) : Color.white.opacity(0.1), lineWidth: 0.5)
                    )
            }
        }
    }

    // MARK: - Metrics Grid (matches React exactly)

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("PERFORMANCE")
                .font(.spaceMonoBold(10))
                .tracking(2.5)
                .foregroundColor(lightMode ? .black.opacity(0.4) : .white.opacity(0.35))

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
                .foregroundColor(lightMode ? .black.opacity(0.4) : .white.opacity(0.4))
            Text(value)
                .font(.interBold(18))
                .foregroundColor(lightMode ? .black : .white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ENVISpacing.md)
        .background(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .fill(lightMode ? Color.black.opacity(0.05) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(lightMode ? Color.black.opacity(0.05) : Color.white.opacity(0.05), lineWidth: 0.5)
        )
    }

    // MARK: - AI Score Section

    private var aiScoreSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("ENVI AI SCORE")
                .font(.spaceMonoBold(10))
                .tracking(2.5)
                .foregroundColor(lightMode ? .black.opacity(0.4) : .white.opacity(0.35))

            VStack(alignment: .leading, spacing: ENVISpacing.md) {
                HStack(spacing: ENVISpacing.md) {
                    // Score number (Inter 32px black)
                    Text("\(content.aiScore)")
                        .font(.interBlack(32))
                        .foregroundColor(scoreColor(for: content.aiScore))

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(lightMode ? Color.black.opacity(0.1) : Color.white.opacity(0.1))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(scoreColor(for: content.aiScore))
                                .frame(
                                    width: geo.size.width * CGFloat(content.aiScore) / 100.0,
                                    height: 6
                                )
                        }
                    }
                    .frame(height: 6)
                }

                // AI Suggestion
                if let suggestion = content.aiSuggestion {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("AI TIP:")
                                .font(.spaceMonoBold(11))
                                .foregroundColor(lightMode ? .black.opacity(0.7) : .white.opacity(0.7))
                        }
                        Text(suggestion)
                            .font(.spaceMono(11))
                            .foregroundColor(lightMode ? .black.opacity(0.5) : .white.opacity(0.5))
                            .lineSpacing(3)
                    }
                }
            }
            .padding(ENVISpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .fill(lightMode ? Color.black.opacity(0.05) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .strokeBorder(lightMode ? Color.black.opacity(0.05) : Color.white.opacity(0.05), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Related Content Section

    private var relatedContentSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("RELATED CONTENT")
                .font(.spaceMonoBold(10))
                .tracking(2.5)
                .foregroundColor(lightMode ? .black.opacity(0.4) : .white.opacity(0.35))

            VStack(spacing: 0) {
                let relatedLinks = kContentLinks.filter { $0.source == content.id || $0.target == content.id }

                ForEach(Array(relatedLinks.enumerated()), id: \.offset) { _, link in
                    let otherId = link.source == content.id ? link.target : link.source
                    if let otherContent = ContentLibrary.piece(for: otherId) {
                        Button {
                            onNavigateToContent?(otherContent)
                        } label: {
                            HStack(spacing: ENVISpacing.md) {
                                // Thumbnail
                                Group {
                                    if let uiImage = UIImage(named: otherContent.imageName) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } else {
                                        Rectangle().fill(ENVITheme.Dark.surfaceLow)
                                    }
                                }
                                .frame(width: 32, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 4))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(otherContent.title)
                                        .font(.interRegular(12))
                                        .foregroundColor(lightMode ? .black.opacity(0.6) : .white.opacity(0.6))
                                        .lineLimit(1)

                                    Text("\(otherContent.type.label) • \(otherContent.platform.label)")
                                        .font(.spaceMono(9))
                                        .tracking(1.0)
                                        .foregroundColor(lightMode ? .black.opacity(0.3) : .white.opacity(0.3))
                                }

                                Spacer()

                                // Similarity percentage
                                Text("\(Int(link.strength * 100))%")
                                    .font(.spaceMono(10))
                                    .tracking(1.0)
                                    .foregroundColor(lightMode ? .black.opacity(0.3) : .white.opacity(0.3))
                            }
                            .padding(.vertical, 10)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(lightMode ? Color.black.opacity(0.05) : Color.white.opacity(0.05))
                                    .frame(height: 0.5)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Waterfall Section (Repurpose suggestions)

    private var waterfallSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("WATERFALL")
                .font(.spaceMonoBold(10))
                .tracking(2.5)
                .foregroundColor(lightMode ? .black.opacity(0.4) : .white.opacity(0.35))

            Text("Ways to repurpose this piece across platforms")
                .font(.spaceMono(10))
                .lineSpacing(2)
                .foregroundColor(lightMode ? .black.opacity(0.3) : .white.opacity(0.3))

            VStack(spacing: ENVISpacing.sm) {
                ForEach(WaterfallSuggestion.suggestions(for: content)) { suggestion in
                    VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                        HStack {
                            Text(suggestion.format)
                                .font(.interSemiBold(12))
                                .foregroundColor(lightMode ? .black.opacity(0.8) : .white.opacity(0.8))
                            Spacer()
                            Text(suggestion.platform.uppercased())
                                .font(.spaceMono(9))
                                .tracking(1.0)
                                .foregroundColor(lightMode ? .black.opacity(0.3) : .white.opacity(0.3))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(lightMode ? Color.black.opacity(0.05) : Color.white.opacity(0.05))
                                )
                        }

                        Text(suggestion.description)
                            .font(.spaceMono(10))
                            .lineSpacing(2)
                            .foregroundColor(lightMode ? .black.opacity(0.4) : .white.opacity(0.4))
                    }
                    .padding(ENVISpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: ENVIRadius.lg)
                            .fill(lightMode ? Color.black.opacity(0.05) : Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.lg)
                            .strokeBorder(
                                lightMode ? Color.black.opacity(0.05) : Color.white.opacity(0.05),
                                lineWidth: 0.5
                            )
                    )
                }
            }
        }
    }

    // MARK: - Future Prediction Section

    private var futurePredictionSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("AI PREDICTION")
                .font(.spaceMonoBold(10))
                .tracking(2.5)
                .foregroundColor(Color(hex: "#3B82F6").opacity(0.8))

            VStack(alignment: .leading, spacing: ENVISpacing.md) {
                // Predicted engagement
                if let predicted = content.predictedEngagement {
                    HStack(spacing: ENVISpacing.sm) {
                        Text("PREDICTED ENGAGEMENT")
                            .font(.spaceMono(9))
                            .tracking(1.5)
                            .foregroundColor(lightMode ? .black.opacity(0.4) : .white.opacity(0.4))
                        Spacer()
                        Text(predicted)
                            .font(.spaceMonoBold(11))
                            .foregroundColor(lightMode ? .black.opacity(0.8) : .white.opacity(0.8))
                    }
                }

                // Confidence score
                if let confidence = content.confidenceScore {
                    HStack(spacing: ENVISpacing.sm) {
                        Text("CONFIDENCE")
                            .font(.spaceMono(9))
                            .tracking(1.5)
                            .foregroundColor(lightMode ? .black.opacity(0.4) : .white.opacity(0.4))
                        Spacer()
                        HStack(spacing: 6) {
                            Text("\(confidence)%")
                                .font(.interBold(14))
                                .foregroundColor(Color(hex: "#3B82F6"))
                            Text("confidence based on your patterns")
                                .font(.spaceMono(9))
                                .foregroundColor(lightMode ? .black.opacity(0.35) : .white.opacity(0.35))
                        }
                    }

                    // Confidence bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(lightMode ? Color.black.opacity(0.1) : Color.white.opacity(0.1))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: "#3B82F6"))
                                .frame(width: geo.size.width * CGFloat(confidence) / 100.0, height: 4)
                        }
                    }
                    .frame(height: 4)
                }

                // AI explanation
                if let explanation = content.aiExplanation {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WHY THIS RECOMMENDATION")
                            .font(.spaceMonoBold(9))
                            .tracking(1.5)
                            .foregroundColor(lightMode ? .black.opacity(0.5) : .white.opacity(0.5))
                        Text(explanation)
                            .font(.spaceMono(10))
                            .foregroundColor(lightMode ? .black.opacity(0.45) : .white.opacity(0.45))
                            .lineSpacing(3)
                    }
                    .padding(.top, ENVISpacing.xs)
                }
            }
            .padding(ENVISpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .fill(Color(hex: "#30217C").opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .strokeBorder(Color(hex: "#30217C").opacity(0.2), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Edit CTA Button (type-specific, #30217C background)

    private var editCTAButton: some View {
        Button(action: {}) {
            Text(editLabel.uppercased())
                .font(.interBold(13))
                .tracking(2.0)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: ENVIRadius.lg)
                        .fill(Color(hex: "#30217C"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.lg)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(lightMode ? Color.black.opacity(0.1) : Color.white.opacity(0.1))
            .frame(height: 0.5)
            .padding(.vertical, ENVISpacing.md)
    }

    // MARK: - Helpers

    /// Type-specific edit CTA label (matches React exactly)
    /// Future pieces show "Create Now" instead.
    private var editLabel: String {
        if content.isFuture { return "Create Now" }
        switch content.type {
        case .video, .reel:     return "Edit in Video Editor"
        case .carousel:         return "Edit Carousel"
        case .photo, .story:    return "Edit in Photo Editor"
        }
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
