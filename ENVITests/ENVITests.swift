import XCTest
import SwiftUI
@testable import ENVI

final class ENVITests: XCTestCase {
    func testColorHexInit() {
        let color = Color(hex: "#7B68EE")
        XCTAssertNotNil(color)
    }

    func testUserMock() {
        let user = User.mock
        XCTAssertEqual(user.firstName, "Alex")
        XCTAssertEqual(user.initials, "AR")
    }

    func testContentItemMockFeed() {
        let items = ContentItem.mockFeed
        XCTAssertGreaterThan(items.count, 0)
    }

    func testOnboardingViewModel() {
        let vm = OnboardingViewModel()
        vm.firstName = "Test"
        vm.lastName = "User"
        XCTAssertTrue(vm.isNameValid)
        XCTAssertTrue(vm.canContinue)
    }

    func testAnalyticsDataMock() {
        let data = AnalyticsData.mock
        XCTAssertEqual(data.dailyEngagement.count, 7)
    }

    func testThemeManager() {
        let manager = ThemeManager.shared
        XCTAssertNotNil(manager.mode)
    }

    // MARK: - 1. Model Codable Tests

    func testContentItemCodable() throws {
        let item = ContentItem.mockFeed[0]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(item)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ContentItem.self, from: data)

        XCTAssertEqual(decoded.id, item.id)
        XCTAssertEqual(decoded.creatorName, item.creatorName)
        XCTAssertEqual(decoded.creatorHandle, item.creatorHandle)
        XCTAssertEqual(decoded.platform, item.platform)
        XCTAssertEqual(decoded.caption, item.caption)
        XCTAssertEqual(decoded.confidenceScore, item.confidenceScore)
        XCTAssertEqual(decoded.likes, item.likes)
        XCTAssertEqual(decoded.comments, item.comments)
        XCTAssertEqual(decoded.shares, item.shares)
    }

    func testContentPieceCodable() throws {
        let piece = ContentPiece(
            id: "test-1", title: "Test Piece", type: .photo, platform: .instagram,
            description: "A test piece", aiScore: 85, createdAt: Date(),
            tags: ["test"], metrics: ContentMetrics(views: 100, likes: 50, shares: 10, comments: 5),
            aiSuggestion: "Test suggestion", imageName: "Closer", source: .photoLibrary
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(piece)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ContentPiece.self, from: data)

        XCTAssertEqual(decoded.id, piece.id)
        XCTAssertEqual(decoded.title, piece.title)
        XCTAssertEqual(decoded.aiScore, 85)
        // Verify Date survives round-trip (within 1 second tolerance for ISO8601 precision)
        XCTAssertEqual(decoded.createdAt.timeIntervalSince1970, piece.createdAt.timeIntervalSince1970, accuracy: 1.0)
    }

    func testChatMessageCodable() throws {
        let message = ChatMessage(
            id: UUID(), role: .user,
            content: "Hello test", timestamp: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(message)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ChatMessage.self, from: data)

        XCTAssertEqual(decoded.id, message.id)
        XCTAssertEqual(decoded.role, .user)
        XCTAssertEqual(decoded.content, "Hello test")
    }

    func testChatMessageWithDataCardCodable() throws {
        let message = ChatMessage.mockThread.last!
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(message)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ChatMessage.self, from: data)

        XCTAssertEqual(decoded.role, .assistant)
        XCTAssertNotNil(decoded.dataCard)
        XCTAssertEqual(decoded.dataCard?.title, "Weekly Performance")
        XCTAssertNotNil(decoded.relatedQuestions)
    }

    func testAnalyticsDataCodable() throws {
        let analyticsData = AnalyticsData.mock
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(analyticsData)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AnalyticsData.self, from: data)

        XCTAssertEqual(decoded.reach.label, "Reach")
        XCTAssertEqual(decoded.dailyEngagement.count, 7)
        XCTAssertEqual(decoded.engagement.value, "12.4K")
    }

    func testUserCodable() throws {
        let user = User.mock
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(user)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(User.self, from: data)

        XCTAssertEqual(decoded.firstName, "Alex")
        XCTAssertEqual(decoded.lastName, "Rivera")
        XCTAssertEqual(decoded.email, "alex@envi.app")
        XCTAssertEqual(decoded.handle, "@alexrivera")
        XCTAssertEqual(decoded.fullName, "Alex Rivera")
        XCTAssertEqual(decoded.initials, "AR")
        XCTAssertEqual(decoded.connectedPlatforms.count, user.connectedPlatforms.count)
    }

    // MARK: - 2. Validation / Clamping Tests

    func testContentInsightConfidenceClamped() {
        let overOne = ContentInsight(
            title: "Test", body: "Body", category: .performance,
            actionable: false, confidence: 1.5
        )
        XCTAssertEqual(overOne.confidence, 1.0)

        let underZero = ContentInsight(
            title: "Test", body: "Body", category: .performance,
            actionable: false, confidence: -0.5
        )
        XCTAssertEqual(underZero.confidence, 0.0)

        let inRange = ContentInsight(
            title: "Test", body: "Body", category: .performance,
            actionable: false, confidence: 0.75
        )
        XCTAssertEqual(inRange.confidence, 0.75)
    }

    func testContentPredictionConfidenceClamped() {
        let engagement = PredictedEngagement(views: 100, likes: 10, shares: 5, engagementRate: 0.1)

        let overOne = ContentPrediction(
            title: "Test", description: "Desc", suggestedType: .photo,
            suggestedPlatform: .instagram, suggestedDate: Date(),
            confidence: 2.0, predictedEngagement: engagement,
            reasoning: "Test", category: .contentRecommendation, priority: .medium
        )
        XCTAssertEqual(overOne.confidence, 1.0)

        let underZero = ContentPrediction(
            title: "Test", description: "Desc", suggestedType: .photo,
            suggestedPlatform: .instagram, suggestedDate: Date(),
            confidence: -1.0, predictedEngagement: engagement,
            reasoning: "Test", category: .contentRecommendation, priority: .medium
        )
        XCTAssertEqual(underZero.confidence, 0.0)
    }

    func testContentPieceAiScoreClamped() {
        let over100 = ContentPiece(
            id: "test-over", title: "Test", type: .photo, platform: .instagram,
            description: "Desc", aiScore: 150, createdAt: Date(), tags: [],
            metrics: nil, aiSuggestion: nil, imageName: "Closer", source: .photoLibrary
        )
        XCTAssertEqual(over100.aiScore, 100)

        let underZero = ContentPiece(
            id: "test-under", title: "Test", type: .photo, platform: .instagram,
            description: "Desc", aiScore: -10, createdAt: Date(), tags: [],
            metrics: nil, aiSuggestion: nil, imageName: "Closer", source: .photoLibrary
        )
        XCTAssertEqual(underZero.aiScore, 0)

        let inRange = ContentPiece(
            id: "test-normal", title: "Test", type: .photo, platform: .instagram,
            description: "Desc", aiScore: 75, createdAt: Date(), tags: [],
            metrics: nil, aiSuggestion: nil, imageName: "Closer", source: .photoLibrary
        )
        XCTAssertEqual(inRange.aiScore, 75)
    }

    // MARK: - 3. OnboardingViewModel Tests

    func testOnboardingDOBRequiresEditedFlag() {
        let vm = OnboardingViewModel()
        // Even with a valid date, isDOBValid should be false if hasEditedDOB is false
        XCTAssertFalse(vm.isDOBValid)

        vm.hasEditedDOB = true
        // With flag set and default date (which is Date()), it may or may not be in range
        // Set a date that is definitely in the valid range
        var components = DateComponents()
        components.year = 2000
        components.month = 6
        components.day = 15
        vm.dateOfBirth = Calendar.current.date(from: components) ?? Date()
        XCTAssertTrue(vm.isDOBValid)
    }

    func testOnboardingNameMaxLength() {
        let vm = OnboardingViewModel()
        vm.firstName = "A"
        vm.lastName = "B"
        XCTAssertTrue(vm.isNameValid)

        // Exactly 50 characters should be valid
        vm.firstName = String(repeating: "A", count: 50)
        vm.lastName = String(repeating: "B", count: 50)
        XCTAssertTrue(vm.isNameValid)

        // 51 characters should be invalid
        vm.firstName = String(repeating: "A", count: 51)
        XCTAssertFalse(vm.isNameValid)
    }

    func testOnboardingNameRejectsEmpty() {
        let vm = OnboardingViewModel()
        vm.firstName = ""
        vm.lastName = "User"
        XCTAssertFalse(vm.isNameValid)

        vm.firstName = "Test"
        vm.lastName = ""
        XCTAssertFalse(vm.isNameValid)

        vm.firstName = "   "
        vm.lastName = "User"
        XCTAssertFalse(vm.isNameValid)
    }

    // MARK: - 4. FeedViewModel Tests

    func testFeedRemoveCard() {
        let vm = FeedViewModel()
        let initialCount = vm.items.count
        XCTAssertGreaterThan(initialCount, 0)

        let idToRemove = vm.items[0].id
        vm.removeCard(id: idToRemove)

        XCTAssertEqual(vm.items.count, initialCount - 1)
        XCTAssertNil(vm.items.first(where: { $0.id == idToRemove }))
    }

    func testFeedRemoveCardClearsExpanded() {
        let vm = FeedViewModel()
        let id = vm.items[0].id
        vm.expandedItemID = id
        vm.removeCard(id: id)
        XCTAssertNil(vm.expandedItemID)
    }

    func testFeedToggleBookmark() {
        let vm = FeedViewModel()
        let id = vm.items[0].id
        XCTAssertFalse(vm.items[0].isBookmarked)

        vm.bookmarkCard(id: id)
        XCTAssertTrue(vm.items[0].isBookmarked)

        vm.bookmarkCard(id: id)
        XCTAssertFalse(vm.items[0].isBookmarked)
    }

    // MARK: - 5. LibraryViewModel Tests

    func testLibraryFilteredItemsAll() {
        let vm = LibraryViewModel()
        vm.selectedFilter = .all
        XCTAssertEqual(vm.filteredItems.count, vm.items.count)
    }

    func testLibraryFilteredItemsByType() {
        let vm = LibraryViewModel()

        vm.selectedFilter = .videos
        let videoItems = vm.filteredItems
        for item in videoItems {
            XCTAssertEqual(item.type, .videos)
        }

        vm.selectedFilter = .photos
        let photoItems = vm.filteredItems
        for item in photoItems {
            XCTAssertEqual(item.type, .photos)
        }
    }

    func testLibraryInitialItemsFromMock() {
        let vm = LibraryViewModel()
        // Items should include at least the mock items
        XCTAssertGreaterThanOrEqual(vm.items.count, LibraryItem.mockItems.count)
    }

    // MARK: - 6. AnalyticsViewModel Tests

    func testAnalyticsSelectedPlatformFiltering() {
        let vm = AnalyticsViewModel()
        vm.selectedPlatform = nil
        let allData = vm.filteredData
        XCTAssertEqual(allData.calendarDays.count, vm.data.calendarDays.count)

        vm.selectedPlatform = .instagram
        let instagramData = vm.filteredData
        // Filtered calendar should only contain days without content or with instagram
        for day in instagramData.calendarDays {
            if day.hasContent {
                XCTAssertEqual(day.platform, .instagram)
            }
        }
    }

    func testAnalyticsDateRangeComputed() {
        let vm = AnalyticsViewModel()
        let dateRange = vm.dateRange
        // Should contain an en-dash separator and not be "No data"
        XCTAssertTrue(dateRange.contains("–"), "Expected date range to contain en-dash separator")
        XCTAssertNotEqual(dateRange, "No data")
    }

    func testAnalyticsPlatformLabel() {
        let vm = AnalyticsViewModel()
        XCTAssertEqual(vm.platformLabel(nil), "All")
        XCTAssertEqual(vm.platformLabel(.instagram), "Instagram")
        XCTAssertEqual(vm.platformLabel(.tiktok), "TikTok")
    }

    // MARK: - 7. ThemeManager Tests

    func testThemeModePersistedToUserDefaults() {
        let manager = ThemeManager.shared

        manager.mode = .light
        let savedLight = UserDefaults.standard.string(forKey: "envi_appearance_mode")
        XCTAssertEqual(savedLight, "light")

        manager.mode = .dark
        let savedDark = UserDefaults.standard.string(forKey: "envi_appearance_mode")
        XCTAssertEqual(savedDark, "dark")

        manager.mode = .system
        let savedSystem = UserDefaults.standard.string(forKey: "envi_appearance_mode")
        XCTAssertEqual(savedSystem, "system")
    }

    func testThemeColorSchemeComputed() {
        let manager = ThemeManager.shared

        manager.mode = .light
        XCTAssertEqual(manager.colorScheme, .light)

        manager.mode = .dark
        XCTAssertEqual(manager.colorScheme, .dark)

        manager.mode = .system
        XCTAssertNil(manager.colorScheme)
    }
}
