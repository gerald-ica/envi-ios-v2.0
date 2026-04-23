import XCTest
@testable import ENVI

final class VoiceGuardTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Existing tests exercise the matcher logic, which is gated behind
        // `VoiceGuard.isEnabled`. Opt-in here so the tests still verify the
        // regex/compile behavior. The default-disabled no-op behavior is
        // exercised by `testDisabledByDefaultIsNoOp` below (which clears the
        // override first).
        VoiceGuard.overrideEnabled = true
    }

    override func tearDownWithError() throws {
        VoiceGuard.overrideEnabled = nil
        try super.tearDownWithError()
    }

    func testCheckCleanTextReturnsTrue() {
        let guard_ = VoiceGuard.preview
        XCTAssertTrue(guard_.check("This is a perfectly clean sentence."))
    }

    func testCheckDirtyTextReturnsFalse() {
        let guard_ = VoiceGuard.preview
        XCTAssertFalse(guard_.check("This contains a badword."))
    }

    func testFindReturnsMatchedTerms() {
        let guard_ = VoiceGuard.preview
        let found = guard_.find(in: "badword and explicit content")
        XCTAssertEqual(found, ["badword", "explicit"])
    }

    func testCensoredReplacesTerms() {
        let guard_ = VoiceGuard.preview
        let result = guard_.censored("badword explicit slur")
        XCTAssertEqual(result, "[redacted] [redacted] [redacted]")
    }

    func testCensoredPreservesCleanText() {
        let guard_ = VoiceGuard.preview
        let result = guard_.censored("Everything is fine here.")
        XCTAssertEqual(result, "Everything is fine here.")
    }

    func testEmptyGuardAlwaysPasses() {
        let guard_ = VoiceGuard(terms: [])
        XCTAssertTrue(guard_.check("anything goes"))
        XCTAssertEqual(guard_.censored("hello"), "hello")
    }

    // MARK: - Feature flag

    /// When the Info.plist flag is missing and no override is set, VoiceGuard
    /// must behave as a strict no-op even when banned terms are present.
    func testDisabledByDefaultIsNoOp() {
        // Clear the override set by `setUp` so we're simulating a pristine
        // build where `VoiceGuardEnabled` is absent from Info.plist.
        VoiceGuard.overrideEnabled = nil
        XCTAssertFalse(
            VoiceGuard.isEnabled,
            "VoiceGuard must default to disabled when Info.plist key is absent."
        )

        let guard_ = VoiceGuard.preview
        let dirty = "badword explicit slur"

        XCTAssertTrue(
            guard_.check(dirty),
            "check() must return true (clean) when gate is off."
        )
        XCTAssertEqual(
            guard_.find(in: dirty), [],
            "find() must return [] when gate is off."
        )
        XCTAssertEqual(
            guard_.censored(dirty), dirty,
            "censored() must return input unchanged when gate is off."
        )
    }

    func testExplicitlyDisabledIsNoOp() {
        VoiceGuard.overrideEnabled = false
        let guard_ = VoiceGuard.preview
        XCTAssertTrue(guard_.check("badword"))
        XCTAssertEqual(guard_.find(in: "badword explicit"), [])
        XCTAssertEqual(guard_.censored("badword"), "badword")
    }
}
