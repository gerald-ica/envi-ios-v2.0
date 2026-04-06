import SwiftUI
import Combine

/// ViewModel for the AI Ideation and Research feature set.
final class IdeationViewModel: ObservableObject {
    // MARK: - Ideas
    @Published var generatedIdeas: [ContentIdea] = []
    @Published var isGenerating = false
    @Published var ideaPrompt = ""
    @Published var selectedPlatform: SocialPlatform = .instagram
    @Published var ideaError: String?

    // MARK: - Trends
    @Published var trends: [TrendTopic] = []
    @Published var isLoadingTrends = false
    @Published var trendPlatformFilter: SocialPlatform?
    @Published var trendError: String?

    // MARK: - Competitor Insights
    @Published var competitorInsights: [CompetitorInsight] = []
    @Published var isLoadingCompetitors = false
    @Published var competitorHandle = ""
    @Published var competitorError: String?

    // MARK: - Niche Keywords
    @Published var keywords: [NicheKeyword] = []
    @Published var isLoadingKeywords = false
    @Published var nicheQuery = ""
    @Published var keywordError: String?

    // MARK: - Boards
    @Published var boards: [IdeaBoard] = []
    @Published var selectedBoard: IdeaBoard?
    @Published var isLoadingBoards = false
    @Published var boardError: String?

    // MARK: - Navigation
    @Published var selectedTab: IdeationTab = .trends

    private let repository: IdeationRepository

    init(repository: IdeationRepository = IdeationRepositoryProvider.shared.repository) {
        self.repository = repository
        Task {
            await loadTrends()
            await loadBoards()
        }
    }

    // MARK: - Idea Generation

    @MainActor
    func generateIdeas(count: Int = 4) async {
        guard !ideaPrompt.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isGenerating = true
        ideaError = nil

        do {
            generatedIdeas = try await repository.generateIdeas(
                prompt: ideaPrompt,
                platform: selectedPlatform,
                count: count
            )
        } catch {
            if AppEnvironment.current == .dev {
                generatedIdeas = ContentIdea.mockList
            } else {
                ideaError = "Unable to generate ideas."
            }
        }

        isGenerating = false
    }

    // MARK: - Trends

    @MainActor
    func loadTrends() async {
        isLoadingTrends = true
        trendError = nil

        do {
            trends = try await repository.fetchTrends(platform: trendPlatformFilter)
        } catch {
            if AppEnvironment.current == .dev {
                trends = TrendTopic.mockList
            } else {
                trendError = "Unable to load trends."
            }
        }

        isLoadingTrends = false
    }

    @MainActor
    func refreshTrends(for platform: SocialPlatform?) async {
        trendPlatformFilter = platform
        await loadTrends()
    }

    // MARK: - Competitor Insights

    @MainActor
    func analyzeCompetitor() async {
        guard !competitorHandle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoadingCompetitors = true
        competitorError = nil

        do {
            competitorInsights = try await repository.fetchCompetitorInsights(handle: competitorHandle)
        } catch {
            if AppEnvironment.current == .dev {
                competitorInsights = CompetitorInsight.mockList
            } else {
                competitorError = "Unable to analyze competitor."
            }
        }

        isLoadingCompetitors = false
    }

    // MARK: - Niche Keywords

    @MainActor
    func exploreKeywords() async {
        guard !nicheQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoadingKeywords = true
        keywordError = nil

        do {
            keywords = try await repository.exploreNicheKeywords(niche: nicheQuery)
        } catch {
            if AppEnvironment.current == .dev {
                keywords = NicheKeyword.mockList
            } else {
                keywordError = "Unable to explore keywords."
            }
        }

        isLoadingKeywords = false
    }

    // MARK: - Boards

    @MainActor
    func loadBoards() async {
        isLoadingBoards = true
        boardError = nil

        do {
            boards = try await repository.fetchIdeaBoards()
            if selectedBoard == nil, let first = boards.first {
                selectedBoard = first
            }
        } catch {
            if AppEnvironment.current == .dev {
                boards = IdeaBoard.mockList
                selectedBoard = boards.first
            } else {
                boardError = "Unable to load idea boards."
            }
        }

        isLoadingBoards = false
    }

    @MainActor
    func moveIdea(_ idea: ContentIdea, to column: IdeaBoardColumn) async {
        guard let board = selectedBoard else { return }

        // Optimistic update
        if let boardIndex = boards.firstIndex(where: { $0.id == board.id }),
           let ideaIndex = boards[boardIndex].ideas.firstIndex(where: { $0.id == idea.id }) {
            boards[boardIndex].ideas[ideaIndex].boardColumn = column
            selectedBoard = boards[boardIndex]
        }

        do {
            try await repository.updateIdeaColumn(ideaID: idea.id, boardID: board.id, column: column)
        } catch {
            // Revert on failure
            await loadBoards()
            boardError = "Could not move idea."
        }
    }

    @MainActor
    func saveIdeaToBoard(_ idea: ContentIdea, boardID: UUID) async {
        do {
            try await repository.saveIdeaToBoard(ideaID: idea.id, boardID: boardID)
            await loadBoards()
        } catch {
            boardError = "Could not save idea to board."
        }
    }

    // MARK: - Helpers

    func useIdea(from trend: TrendTopic) {
        ideaPrompt = "Create content about: \(trend.topic)"
        selectedTab = .generate
    }
}

// MARK: - Tab

enum IdeationTab: String, CaseIterable {
    case trends
    case generate
    case competitors
    case keywords
    case boards

    var displayName: String {
        switch self {
        case .trends:      return "Trends"
        case .generate:    return "Generate"
        case .competitors: return "Competitors"
        case .keywords:    return "Keywords"
        case .boards:      return "Boards"
        }
    }

    var iconName: String {
        switch self {
        case .trends:      return "chart.line.uptrend.xyaxis"
        case .generate:    return "sparkles"
        case .competitors: return "person.2"
        case .keywords:    return "magnifyingglass"
        case .boards:      return "rectangle.3.group"
        }
    }
}
