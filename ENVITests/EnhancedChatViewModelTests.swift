//
//  EnhancedChatViewModelTests.swift
//  ENVITests
//
//  Phase 19 — Plan 04. Baseline coverage for the Chat tab's primary VM.
//  EnhancedChatViewModel owns input/typing/home-state rather than talking
//  to a repository directly (Oracle + ENVI Brain are singletons), so the
//  pins here are around state transitions rather than repo-driven loading.
//

import XCTest
@testable import ENVI

@MainActor
final class EnhancedChatViewModelTests: XCTestCase {

    /// Default state: home screen visible, no active thread, no typing,
    /// no error, empty input. Mirrors the EducationViewModelTests contract.
    func testDefaultStateIsHome() {
        let vm = EnhancedChatViewModel()
        XCTAssertTrue(vm.isHome, "Chat should default to home/empty state.")
        XCTAssertNil(vm.activeThread, "No thread should be active before the user types.")
        XCTAssertFalse(vm.isTyping)
        XCTAssertTrue(vm.inputText.isEmpty)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.quickActions.isEmpty, "Quick actions should always be available.")
    }

    /// `resetToHome()` must clear any prior thread/input/typing state and
    /// return the VM to the home screen. Pins the back-button behavior.
    func testResetToHomeClearsState() {
        let vm = EnhancedChatViewModel()
        vm.inputText = "Some prior query"
        vm.isHome = false
        vm.isTyping = true

        vm.resetToHome()

        XCTAssertTrue(vm.isHome)
        XCTAssertNil(vm.activeThread)
        XCTAssertFalse(vm.isTyping)
        XCTAssertTrue(vm.inputText.isEmpty)
    }

    /// `sendMessage()` with an empty / whitespace-only input should be a
    /// no-op — Chat shouldn't switch away from home for a blank query.
    func testSendMessageWithBlankInputIsNoOp() {
        let vm = EnhancedChatViewModel()
        vm.inputText = "   \n\t  "
        vm.sendMessage()

        XCTAssertTrue(vm.isHome, "Blank input should leave us on the home screen.")
        XCTAssertNil(vm.activeThread)
        XCTAssertFalse(vm.isTyping)
    }

    /// `selectQuickAction(_:)` should copy the text into inputText and
    /// trigger sendMessage(). After calling we expect isTyping=true
    /// briefly (the resolve runs on a Task, so we just verify the input
    /// + home-state transition happened synchronously).
    func testSelectQuickActionPopulatesInputAndStartsThread() {
        let vm = EnhancedChatViewModel()
        let action = vm.quickActions.first ?? "Weekly energy forecast"

        vm.selectQuickAction(action)

        XCTAssertFalse(vm.isHome, "Selecting a quick action should leave the home screen.")
        // inputText was sent, so it's cleared inside sendMessage()
        XCTAssertEqual(vm.inputText, "")
    }
}
