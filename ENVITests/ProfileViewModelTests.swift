//
//  ProfileViewModelTests.swift
//  ENVITests
//
//  Phase 14 — Plan 03. Pins the contract that `ProfileViewModel` no
//  longer defaults to `User.mock` in production and that the Preview
//  helper still works for SwiftUI previews.
//

import XCTest
@testable import ENVI

@MainActor
final class ProfileViewModelTests: XCTestCase {

    /// v1.2 Audit finding: the Profile tab was showing mock data for
    /// every signed-in user because `ProfileViewModel.user = User.mock`
    /// was the unconditional default. Plan 14-03 made `user` optional
    /// and nil-initialized. This test guarantees a regression here
    /// surfaces immediately rather than shipping silently.
    func testDefaultStateIsEmpty() {
        let vm = ProfileViewModel()
        XCTAssertNil(vm.user, "ProfileViewModel should NOT default to any User (mock or otherwise).")
        XCTAssertFalse(vm.isLoadingProfile, "Loading flag starts off; set only during loadProfile().")
        XCTAssertNil(vm.profileLoadError, "No error should exist before loadProfile() has run.")
        XCTAssertTrue(vm.connections.isEmpty, "No connections exist until loadConnections() runs.")
    }

    /// The Preview helper is the supported way to inject `User.mock`
    /// for SwiftUI previews. Pinning its existence prevents a future
    /// refactor from silently deleting it and breaking every Profile
    /// preview.
    func testPreviewHelperInjectsMock() {
        let vm = ProfileViewModel.preview()
        XCTAssertNotNil(vm.user, "Preview helper should hydrate `user` with User.mock for Previews.")
        XCTAssertEqual(vm.user?.firstName, User.mock.firstName)
        XCTAssertEqual(vm.user?.handle, User.mock.handle)
        XCTAssertFalse(vm.connections.isEmpty, "Preview helper calls loadConnections() so connections list is populated.")
    }

    // MARK: - Phase 19 Plan 04 extensions

    /// `loadConnections()` must synthesize an entry per SocialPlatform so
    /// the Profile UI always has a full row for each connectable platform
    /// (disconnected rows render a "Connect" button). Pins Phase 14's
    /// "merge user.connectedPlatforms with the full platform list" contract.
    func testLoadConnectionsPopulatesRowForEveryPlatform() {
        let vm = ProfileViewModel()
        vm.user = User.mock
        vm.loadConnections()

        XCTAssertEqual(
            vm.connections.count,
            SocialPlatform.allCases.count,
            "Every SocialPlatform case must have a connection row."
        )
        // Every SocialPlatform should appear exactly once.
        let platforms = Set(vm.connections.map(\.platform))
        XCTAssertEqual(platforms.count, SocialPlatform.allCases.count)
    }

    /// `loadConnections()` with nil user should still produce a full row
    /// per platform — all disconnected. Guards against a crash when the
    /// Profile view loads before auth hydration completes.
    func testLoadConnectionsWithNilUserStillProducesFullRowset() {
        let vm = ProfileViewModel()
        vm.user = nil
        vm.loadConnections()

        XCTAssertEqual(vm.connections.count, SocialPlatform.allCases.count)
        XCTAssertTrue(
            vm.connections.allSatisfy { !$0.isConnected },
            "With no user, no platforms should be marked connected."
        )
    }

    /// `isConnectingPlatform` is the spinner flag the UI uses to disable
    /// the Connect button during an in-flight connect. Baseline pin: the
    /// flag starts false and the error message starts nil so the UI
    /// doesn't render a stale error banner.
    func testConnectPlatformDefaultStateIsIdle() {
        let vm = ProfileViewModel()
        XCTAssertFalse(vm.isConnectingPlatform)
        XCTAssertNil(vm.connectionErrorMessage)
    }
}
