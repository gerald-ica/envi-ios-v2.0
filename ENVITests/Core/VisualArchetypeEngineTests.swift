import XCTest
@testable import ENVI

final class VisualArchetypeEngineTests: XCTestCase {

    private let engine: VisualArchetypeEngine = VisualArchetypeEngineImpl()

    func testArchetypesIgnoresNoise() {
        let result = engine.archetypes(for: [-1, 0, -1, 1])
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0], .minimalist)
        XCTAssertEqual(result[1], .maximalist)
    }

    func testArchetypesDeduplicatesAndSorts() {
        let result = engine.archetypes(for: [2, 2, 0, 5, 5, 5])
        XCTAssertEqual(result, [.minimalist, .documentarian, .architectural])
    }

    func testArchetypesCyclesThroughCanonicalList() {
        // 6 archetypes exist; label 6 should wrap to index 0 (minimalist)
        let result = engine.archetypes(for: [6])
        XCTAssertEqual(result.first, .minimalist)
    }

    func testConfidenceHighWhenConcentrated() {
        let score = engine.confidence(for: [0, 0, 0, 0])
        XCTAssertGreaterThan(score, 0.7)
    }

    func testConfidenceLowWhenDispersed() {
        let score = engine.confidence(for: [0, 1, 2, 3, 4, 5])
        XCTAssertLessThan(score, 0.3)
    }

    func testConfidenceZeroForAllNoise() {
        let score = engine.confidence(for: [-1, -1, -1])
        XCTAssertEqual(score, 0)
    }

    func testAllArchetypesAreUnique() {
        let ids = VisualArchetype.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}
