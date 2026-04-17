import XCTest
@testable import ENVI

/// Phase 16-03 — pin tests for `AIToolsMenuView`'s catalog and the
/// seven AIFeatures destinations it surfaces.
@MainActor
final class AIToolsMenuTests: XCTestCase {

    func testAIToolsMenuContainsSevenTools() {
        XCTAssertEqual(AIToolsMenuView.tools.count, 7,
                       "The AI toolbelt ships with exactly 7 tools (Ideation, Caption, Hook, Script, Image, Style, Visual).")
    }

    func testEachToolHasValidDestinationAndDistinctID() {
        let tools = AIToolsMenuView.tools
        let destinationIDs = Set(tools.map { $0.destination.id })
        XCTAssertEqual(destinationIDs.count, tools.count,
                       "Every AI tool must route to a unique destination.")

        let toolIDs = Set(tools.map { $0.id })
        XCTAssertEqual(toolIDs.count, tools.count,
                       "Every AI tool must have a distinct identifier.")
    }

    func testAllAIDestinationsDefaultToSheetPresentation() {
        let destinations: [AppDestination] = [
            .ideation, .aiVisualEditor, .captionGenerator,
            .hookLibrary, .scriptEditor, .styleTransfer, .imageGenerator
        ]
        for destination in destinations {
            XCTAssertEqual(destination.defaultPresentation, .sheet,
                           "AI destination \(destination.id) should default to .sheet.")
        }
    }

    func testToolTitlesAreNonEmpty() {
        for tool in AIToolsMenuView.tools {
            XCTAssertFalse(tool.title.isEmpty,
                           "Tool \(tool.id) must have a display title.")
            XCTAssertFalse(tool.subtitle.isEmpty,
                           "Tool \(tool.id) must have a subtitle.")
            XCTAssertFalse(tool.icon.isEmpty,
                           "Tool \(tool.id) must have an SF Symbol icon name.")
        }
    }

    func testExploreModeHasAIMember() {
        // Three modes after 16-03: EXPLORE, CHAT, AI.
        XCTAssertEqual(ExploreMode.allCases.count, 3)
        XCTAssertTrue(ExploreMode.allCases.contains(.ai))
    }
}
