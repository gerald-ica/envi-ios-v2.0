import XCTest
@testable import ENVI

final class TemplateRankerTests: XCTestCase {
    // MARK: - Ranker

    func testRankerPrioritizesHighFill() {
        // 10 populated templates with varying fill rates. The 100%-fill
        // template should outrank the 50%-fill template.
        let populated = (0..<10).map { i -> PopulatedTemplate in
            let fill = Double(i) / 10.0 // 0.0, 0.1, ... 0.9
            return TemplateRankerTestFixtures.populated(
                name: "Template \(i)",
                fillRate: fill,
                overallScore: 0.5,
                popularity: 100
            )
        }
        // Add a 100% fill template.
        let full = TemplateRankerTestFixtures.populated(
            name: "Full",
            fillRate: 1.0,
            overallScore: 0.5,
            popularity: 100
        )
        let half = TemplateRankerTestFixtures.populated(
            name: "Half",
            fillRate: 0.5,
            overallScore: 0.5,
            popularity: 100
        )
        let input = populated + [full, half]

        let ranker = TemplateRanker()
        let ranked = ranker.rank(input)

        let fullIndex = ranked.firstIndex { $0.template.name == "Full" } ?? -1
        let halfIndex = ranked.firstIndex { $0.template.name == "Half" } ?? -1
        XCTAssertGreaterThanOrEqual(fullIndex, 0)
        XCTAssertGreaterThanOrEqual(halfIndex, 0)
        XCTAssertLessThan(fullIndex, halfIndex, "100%-fill template must rank above 50%-fill")
        XCTAssertEqual(ranked.first?.template.name, "Full")
    }

    func testRankerBreakdownMatchesFormula() {
        let pop = TemplateRankerTestFixtures.populated(
            name: "BreakdownCheck",
            fillRate: 0.8,
            overallScore: 0.6,
            popularity: 100
        )
        let ranker = TemplateRanker()
        let ranked = ranker.rankWithBreakdown([pop])
        XCTAssertEqual(ranked.count, 1)
        let bd = ranked[0].scoreBreakdown

        // Weighted components must sum to the stored total (within float epsilon).
        let computedTotal = bd.fill + bd.score + bd.popularity
        XCTAssertEqual(computedTotal, bd.total, accuracy: 1e-9)

        // Individual weighted components match formula.
        XCTAssertEqual(bd.fill, 0.8 * ranker.fillWeight, accuracy: 1e-9)
        XCTAssertEqual(bd.score, 0.6 * ranker.scoreWeight, accuracy: 1e-9)
        // Single template → maxPopularity == its own popularity → ratio == 1.
        XCTAssertEqual(bd.popularity, 1.0 * ranker.popularityWeight, accuracy: 1e-9)
    }

    // MARK: - Mock Repository

    func testMockRepoFetchCatalogReturnsLibrary() async throws {
        let repo = MockVideoTemplateRepository()
        let catalog = try await repo.fetchCatalog()
        XCTAssertEqual(catalog.count, VideoTemplate.mockLibrary.count)
    }

    func testMockRepoFilterByCategory() async throws {
        let repo = MockVideoTemplateRepository()
        let cooking = try await repo.fetchByCategory(.cooking)
        XCTAssertFalse(cooking.isEmpty, "mockLibrary should include at least one cooking template")
        for template in cooking {
            XCTAssertEqual(template.category, .cooking)
        }
    }

    func testMockRepoErrorInjection() async {
        let repo = MockVideoTemplateRepository(
            throwMode: .onCatalog(.catalogUnavailable)
        )
        do {
            _ = try await repo.fetchCatalog()
            XCTFail("Expected catalogUnavailable")
        } catch let error as VideoTemplateRepositoryError {
            if case .catalogUnavailable = error {
                // ok
            } else {
                XCTFail("Wrong error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Fixtures

private enum TemplateRankerTestFixtures {
    /// Builds a minimal PopulatedTemplate with the given ranker-relevant
    /// fields. Leaves asset-level details nil — the ranker doesn't inspect
    /// them when creationDate is nil (recency signal defaults to 0).
    static func populated(
        name: String,
        fillRate: Double,
        overallScore: Double,
        popularity: Int
    ) -> PopulatedTemplate {
        let template = VideoTemplate(
            id: UUID(),
            remoteID: nil,
            name: name,
            category: .cooking,
            aspectRatio: .portrait9x16,
            duration: 15,
            slots: [],
            textOverlays: [],
            transitions: [],
            audioTrack: nil,
            suggestedPlatforms: [],
            thumbnailURL: nil,
            popularity: popularity
        )
        return PopulatedTemplate(
            template: template,
            filledSlots: [],
            fillRate: fillRate,
            overallScore: overallScore,
            previewThumbnail: nil
        )
    }
}
