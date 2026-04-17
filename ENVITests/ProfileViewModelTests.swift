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
}
