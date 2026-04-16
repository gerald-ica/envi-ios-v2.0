import SwiftUI

/// Main AI ideation screen with tabbed sections for trends, idea generation,
/// competitor monitoring, keyword exploration, and idea boards.
struct IdeationDashboardView: View {
    @StateObject private var viewModel = IdeationViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            tabContent
        }
        .background(ENVITheme.background(for: colorScheme))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text("AI IDEATION")
                    .font(.spaceMonoBold(17))
                    .tracking(-0.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("Research, generate, and organize content ideas")
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(ENVITheme.Dark.accent)
        }
        .padding(.horizontal, ENVISpacing.xl)
        .padding(.vertical, ENVISpacing.lg)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ENVISpacing.sm) {
                ForEach(IdeationTab.allCases, id: \.self) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
        .padding(.bottom, ENVISpacing.md)
    }

    private func tabButton(for tab: IdeationTab) -> some View {
        Button(action: { viewModel.selectedTab = tab }) {
            HStack(spacing: ENVISpacing.xs) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 12, weight: .medium))
                Text(tab.displayName)
                    .font(.interMedium(13))
            }
            .padding(.horizontal, ENVISpacing.md)
            .padding(.vertical, ENVISpacing.sm)
            .foregroundColor(
                viewModel.selectedTab == tab
                    ? ENVITheme.text(for: colorScheme)
                    : ENVITheme.textSecondary(for: colorScheme)
            )
            .background(
                viewModel.selectedTab == tab
                    ? ENVITheme.surfaceLow(for: colorScheme)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.sm)
                    .strokeBorder(
                        viewModel.selectedTab == tab
                            ? ENVITheme.border(for: colorScheme)
                            : Color.clear,
                        lineWidth: 1
                    )
            )
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        ScrollView {
            switch viewModel.selectedTab {
            case .trends:
                trendsSection
            case .generate:
                generateSection
            case .competitors:
                competitorsSection
            case .keywords:
                keywordsSection
            case .boards:
                boardsSection
            }
        }
    }

    // MARK: - Trends Section

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.lg) {
            // Platform filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ENVISpacing.sm) {
                    platformFilterChip(nil, label: "All")
                    ForEach(SocialPlatform.allCases) { platform in
                        platformFilterChip(platform, label: platform.rawValue)
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }

            if viewModel.isLoadingTrends {
                ENVILoadingState()
            } else if viewModel.trends.isEmpty {
                emptyState(icon: "chart.line.uptrend.xyaxis", message: "No trends detected yet")
            } else {
                LazyVStack(spacing: ENVISpacing.md) {
                    ForEach(viewModel.trends) { trend in
                        TrendCardView(trend: trend) {
                            viewModel.useIdea(from: trend)
                        }
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }

            errorLabel(viewModel.trendError)
        }
        .padding(.vertical, ENVISpacing.lg)
    }

    private func platformFilterChip(_ platform: SocialPlatform?, label: String) -> some View {
        let isSelected = viewModel.trendPlatformFilter == platform
        return Button(action: {
            Task { await viewModel.refreshTrends(for: platform) }
        }) {
            Text(label.uppercased())
                .font(.spaceMono(10))
                .tracking(0.5)
                .padding(.horizontal, ENVISpacing.md)
                .padding(.vertical, ENVISpacing.xs)
                .foregroundColor(
                    isSelected
                        ? ENVITheme.text(for: colorScheme)
                        : ENVITheme.textSecondary(for: colorScheme)
                )
                .background(
                    isSelected
                        ? ENVITheme.surfaceLow(for: colorScheme)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.sm)
                        .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                )
        }
    }

    // MARK: - Generate Section

    private var generateSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xl) {
            // Prompt input
            VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                Text("DESCRIBE YOUR IDEA")
                    .font(.spaceMono(10))
                    .tracking(1.0)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                TextField("e.g. Morning routine content for fitness creators...", text: $viewModel.ideaPrompt, axis: .vertical)
                    .font(.interRegular(15))
                    .lineLimit(3...6)
                    .padding(ENVISpacing.md)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.md)
                            .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                    )
            }

            // Platform picker
            VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                Text("PLATFORM")
                    .font(.spaceMono(10))
                    .tracking(1.0)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ENVISpacing.sm) {
                        ForEach(SocialPlatform.allCases) { platform in
                            Button(action: { viewModel.selectedPlatform = platform }) {
                                HStack(spacing: ENVISpacing.xs) {
                                    Image(systemName: platform.iconName)
                                        .font(.system(size: 12))
                                    Text(platform.rawValue)
                                        .font(.interMedium(13))
                                }
                                .padding(.horizontal, ENVISpacing.md)
                                .padding(.vertical, ENVISpacing.sm)
                                .foregroundColor(
                                    viewModel.selectedPlatform == platform
                                        ? .white
                                        : ENVITheme.text(for: colorScheme)
                                )
                                .background(
                                    viewModel.selectedPlatform == platform
                                        ? platform.brandColor
                                        : ENVITheme.surfaceLow(for: colorScheme)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                            }
                        }
                    }
                }
            }

            // Generate button
            ENVIButton(
                viewModel.isGenerating ? "Generating..." : "Generate Ideas",
                variant: .primary,
                isFullWidth: true
            ) {
                Task { await viewModel.generateIdeas() }
            }
            .disabled(viewModel.isGenerating || viewModel.ideaPrompt.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(viewModel.ideaPrompt.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)

            // Results
            if viewModel.isGenerating {
                ProgressView("Thinking...")
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if !viewModel.generatedIdeas.isEmpty {
                VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                    Text("GENERATED IDEAS")
                        .font(.spaceMono(10))
                        .tracking(1.0)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    ForEach(viewModel.generatedIdeas) { idea in
                        ideaResultCard(idea)
                    }
                }
            }

            errorLabel(viewModel.ideaError)
        }
        .padding(.horizontal, ENVISpacing.xl)
        .padding(.vertical, ENVISpacing.lg)
    }

    private func ideaResultCard(_ idea: ContentIdea) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack {
                Text(idea.title)
                    .font(.interSemiBold(15))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                Spacer()
                Text(idea.format.displayName.uppercased())
                    .font(.spaceMono(9))
                    .tracking(0.5)
                    .padding(.horizontal, ENVISpacing.sm)
                    .padding(.vertical, 2)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }

            Text(idea.description)
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .lineLimit(3)

            HStack(spacing: ENVISpacing.md) {
                Label(String(format: "%.1f%%", idea.estimatedEngagement), systemImage: "heart")
                    .font(.spaceMono(10))
                Label(idea.hookStyle, systemImage: "text.quote")
                    .font(.spaceMono(10))
                Spacer()
                if let board = viewModel.boards.first {
                    Button(action: {
                        Task { await viewModel.saveIdeaToBoard(idea, boardID: board.id) }
                    }) {
                        Text("Save")
                            .font(.interMedium(12))
                            .foregroundColor(ENVITheme.Dark.accent)
                    }
                }
            }
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Competitors Section

    private var competitorsSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xl) {
            // Handle input
            VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                Text("COMPETITOR HANDLE")
                    .font(.spaceMono(10))
                    .tracking(1.0)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                HStack(spacing: ENVISpacing.sm) {
                    TextField("@username", text: $viewModel.competitorHandle)
                        .font(.interRegular(15))
                        .padding(ENVISpacing.md)
                        .background(ENVITheme.surfaceLow(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: ENVIRadius.md)
                                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                        )

                    Button(action: { Task { await viewModel.analyzeCompetitor() } }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                            .frame(width: 44, height: 44)
                            .background(ENVITheme.surfaceLow(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: ENVIRadius.md)
                                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                            )
                    }
                    .disabled(viewModel.isLoadingCompetitors)
                }
            }

            if viewModel.isLoadingCompetitors {
                ENVILoadingState()
            } else {
                ForEach(viewModel.competitorInsights) { insight in
                    competitorCard(insight)
                }
            }

            errorLabel(viewModel.competitorError)
        }
        .padding(.horizontal, ENVISpacing.xl)
        .padding(.vertical, ENVISpacing.lg)
    }

    private func competitorCard(_ insight: CompetitorInsight) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.competitorHandle)
                        .font(.interSemiBold(15))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                    Text(insight.platform.rawValue.uppercased())
                        .font(.spaceMono(9))
                        .tracking(0.5)
                        .foregroundColor(insight.platform.brandColor)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f%%", insight.engagementRate))
                        .font(.spaceMonoBold(15))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                    Text("ENG. RATE")
                        .font(.spaceMono(8))
                        .tracking(0.5)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }

            Text(insight.takeaway)
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            HStack(spacing: ENVISpacing.md) {
                Label(formatFollowers(insight.followerCount), systemImage: "person.2")
                Label(insight.postFrequency, systemImage: "clock")
                Label(insight.contentType.displayName, systemImage: insight.contentType.iconName)
            }
            .font(.spaceMono(10))
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Keywords Section

    private var keywordsSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xl) {
            VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                Text("EXPLORE NICHE")
                    .font(.spaceMono(10))
                    .tracking(1.0)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                HStack(spacing: ENVISpacing.sm) {
                    TextField("e.g. fitness creator, tech reviewer...", text: $viewModel.nicheQuery)
                        .font(.interRegular(15))
                        .padding(ENVISpacing.md)
                        .background(ENVITheme.surfaceLow(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: ENVIRadius.md)
                                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                        )

                    Button(action: { Task { await viewModel.exploreKeywords() } }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                            .frame(width: 44, height: 44)
                            .background(ENVITheme.surfaceLow(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: ENVIRadius.md)
                                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                            )
                    }
                    .disabled(viewModel.isLoadingKeywords)
                }
            }

            if viewModel.isLoadingKeywords {
                ENVILoadingState()
            } else {
                ForEach(viewModel.keywords) { keyword in
                    keywordCard(keyword)
                }
            }

            errorLabel(viewModel.keywordError)
        }
        .padding(.horizontal, ENVISpacing.xl)
        .padding(.vertical, ENVISpacing.lg)
    }

    private func keywordCard(_ keyword: NicheKeyword) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack {
                Text(keyword.keyword)
                    .font(.interSemiBold(15))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                Spacer()
                Text(formatVolume(keyword.searchVolume))
                    .font(.spaceMonoBold(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
            }

            // Difficulty / Opportunity bars
            HStack(spacing: ENVISpacing.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DIFFICULTY")
                        .font(.spaceMono(8))
                        .tracking(0.5)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ENVITheme.border(for: colorScheme))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(difficultyColor(keyword.difficulty))
                                .frame(width: geo.size.width * keyword.difficulty / 100, height: 4)
                        }
                    }
                    .frame(height: 4)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("OPPORTUNITY")
                        .font(.spaceMono(8))
                        .tracking(0.5)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ENVITheme.border(for: colorScheme))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(opportunityColor(keyword.opportunity))
                                .frame(width: geo.size.width * keyword.opportunity / 100, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }

            // Related terms
            if !keyword.relatedTerms.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ENVISpacing.xs) {
                        ForEach(keyword.relatedTerms, id: \.self) { term in
                            Text(term)
                                .font(.spaceMono(9))
                                .padding(.horizontal, ENVISpacing.sm)
                                .padding(.vertical, 2)
                                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                                .background(ENVITheme.surfaceLow(for: colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                        }
                    }
                }
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Boards Section

    private var boardsSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.lg) {
            if viewModel.isLoadingBoards {
                ENVILoadingState()
            } else if viewModel.boards.isEmpty {
                emptyState(icon: "rectangle.3.group", message: "No idea boards yet")
            } else {
                // Board picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ENVISpacing.sm) {
                        ForEach(viewModel.boards) { board in
                            Button(action: { viewModel.selectedBoard = board }) {
                                Text(board.name)
                                    .font(.interMedium(13))
                                    .padding(.horizontal, ENVISpacing.md)
                                    .padding(.vertical, ENVISpacing.sm)
                                    .foregroundColor(
                                        viewModel.selectedBoard?.id == board.id
                                            ? ENVITheme.text(for: colorScheme)
                                            : ENVITheme.textSecondary(for: colorScheme)
                                    )
                                    .background(
                                        viewModel.selectedBoard?.id == board.id
                                            ? ENVITheme.surfaceLow(for: colorScheme)
                                            : Color.clear
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: ENVIRadius.sm)
                                            .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, ENVISpacing.xl)
                }

                if let board = viewModel.selectedBoard {
                    IdeaBoardView(board: board) { idea, column in
                        Task { await viewModel.moveIdea(idea, to: column) }
                    }
                    .padding(.horizontal, ENVISpacing.xl)
                }
            }

            errorLabel(viewModel.boardError)
        }
        .padding(.vertical, ENVISpacing.lg)
    }

    // MARK: - Helpers

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: ENVISpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            Text(message)
                .font(.interMedium(15))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(ENVISpacing.xxxl)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func errorLabel(_ error: String?) -> some View {
        if let error {
            Text(error)
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.error)
                .padding(.horizontal, ENVISpacing.xl)
        }
    }

    private func formatFollowers(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func formatVolume(_ volume: Int) -> String {
        if volume >= 1_000 {
            return String(format: "%.1fK", Double(volume) / 1_000)
        }
        return "\(volume)"
    }

    private func difficultyColor(_ value: Double) -> Color {
        if value > 70 { return ENVITheme.error }
        if value > 40 { return .orange }
        return .green
    }

    private func opportunityColor(_ value: Double) -> Color {
        if value > 70 { return .green }
        if value > 40 { return .orange }
        return ENVITheme.error
    }
}

#Preview {
    IdeationDashboardView()
        .preferredColorScheme(.dark)
}
