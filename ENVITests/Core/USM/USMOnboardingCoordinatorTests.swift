//
//  USMOnboardingCoordinatorTests.swift
//  ENVITests
//
//  XCTests for the USM 4-screen onboarding coordinator state machine.
//  Exercises the view model: step progression, canContinue validation,
//  submission flow, and error handling.
//
//  Part of USM Sprint 2 — Task 2.1 (coordinator).
//

import Foundation
import XCTest
@testable import ENVI

@MainActor
final class USMOnboardingCoordinatorTests: XCTestCase {

    // MARK: - Initial State

    func testInitialStateIsName() {
        let vm = makeSampleViewModel()
        XCTAssertEqual(vm.step, .name)
        XCTAssertFalse(vm.canContinue)
    }

    // MARK: - Name Step

    func testNameStepRequiresFirstName() {
        let vm = makeSampleViewModel()
        XCTAssertFalse(vm.canContinue)

        vm.firstName = "John"
        XCTAssertTrue(vm.canContinue)

        vm.firstName = ""
        XCTAssertFalse(vm.canContinue)

        // Last name is optional
        vm.firstName = "John"
        vm.lastName = "Doe"
        XCTAssertTrue(vm.canContinue)

        vm.lastName = ""
        XCTAssertTrue(vm.canContinue)
    }

    // MARK: - Date and Time Step

    func testDateAndTimeStepAllowsUnknownBirthTime() {
        let vm = makeSampleViewModel()
        vm.firstName = "John"
        vm.goToNextStep() // → dateAndTime

        // Default date should not satisfy canContinue (depends on implementation)
        let now = Date()
        vm.dateOfBirth = Date(timeIntervalSince1970: 0) // Far in past
        XCTAssertTrue(vm.canContinue)

        // Even without time, canContinue is true
        vm.hasKnownBirthTime = false
        XCTAssertTrue(vm.canContinue)

        vm.hasKnownBirthTime = true
        vm.timeOfBirth = Date()
        XCTAssertTrue(vm.canContinue)
    }

    // MARK: - Birth Place Step

    func testBirthPlaceStepRequiresSelection() {
        let vm = makeSampleViewModel()
        vm.firstName = "John"
        vm.dateOfBirth = Date(timeIntervalSince1970: 0)

        vm.goToNextStep() // → dateAndTime
        vm.goToNextStep() // → birthPlace

        XCTAssertFalse(vm.canContinue)

        let city = USMCity(
            name: "New York",
            country: "USA",
            timezone: "America/New_York",
            lat: 40.7128,
            lon: -74.0060
        )
        vm.birthPlace = city
        XCTAssertTrue(vm.canContinue)

        vm.birthPlace = nil
        XCTAssertFalse(vm.canContinue)
    }

    // MARK: - Current Location Step

    func testCurrentLocationStepRequiresSelection() {
        let vm = makeSampleViewModel()
        vm.firstName = "John"
        vm.dateOfBirth = Date(timeIntervalSince1970: 0)
        vm.birthPlace = makeSampleCity()

        vm.goToNextStep() // → dateAndTime
        vm.goToNextStep() // → birthPlace
        vm.goToNextStep() // → currentLocation

        XCTAssertFalse(vm.canContinue)

        let city = USMCity(
            name: "London",
            country: "UK",
            timezone: "Europe/London",
            lat: 51.5074,
            lon: -0.1278
        )
        vm.currentLocation = city
        XCTAssertTrue(vm.canContinue)

        vm.currentLocation = nil
        XCTAssertFalse(vm.canContinue)
    }

    // MARK: - Step Ordering

    func testStepOrderingProgresses() {
        let vm = makeSampleViewModel()
        XCTAssertEqual(vm.step, .name)

        vm.goToNextStep()
        XCTAssertEqual(vm.step, .dateAndTime)

        vm.goToNextStep()
        XCTAssertEqual(vm.step, .birthPlace)

        vm.goToNextStep()
        XCTAssertEqual(vm.step, .currentLocation)

        // No step beyond currentLocation
        vm.goToNextStep()
        XCTAssertEqual(vm.step, .currentLocation)
    }

    func testStepOrderingRegresses() {
        let vm = makeSampleViewModel()
        vm.step = .currentLocation

        vm.goToPreviousStep()
        XCTAssertEqual(vm.step, .birthPlace)

        vm.goToPreviousStep()
        XCTAssertEqual(vm.step, .dateAndTime)

        vm.goToPreviousStep()
        XCTAssertEqual(vm.step, .name)

        // No step before name
        vm.goToPreviousStep()
        XCTAssertEqual(vm.step, .name)
    }

    // MARK: - Submission

    func testSubmitTransitionsToLoadingThenCompletes() async throws {
        let stubClient = StubUSMRecomputeClient(
            result: .success(makeSampleResponse())
        )
        let vm = USMOnboardingViewModel(
            userId: "test-user",
            recomputeClient: stubClient
        )

        vm.firstName = "John"
        vm.dateOfBirth = Date(timeIntervalSince1970: 0)
        vm.birthPlace = makeSampleCity()
        vm.currentLocation = makeSampleCity()
        vm.step = .currentLocation

        // Submit
        try await vm.submit()

        // After submit, step should be loading
        XCTAssertEqual(vm.step, .loading)
        XCTAssertNil(vm.submitError)
    }

    func testSubmitFailureRevertsStepAndSetsError() async throws {
        let stubClient = StubUSMRecomputeClient(
            result: .failure(USMRecomputeError.server(status: 500, message: "Internal error"))
        )
        let vm = USMOnboardingViewModel(
            userId: "test-user",
            recomputeClient: stubClient
        )

        vm.firstName = "John"
        vm.dateOfBirth = Date(timeIntervalSince1970: 0)
        vm.birthPlace = makeSampleCity()
        vm.currentLocation = makeSampleCity()
        vm.step = .currentLocation

        // Submit should throw
        do {
            try await vm.submit()
            XCTFail("Expected submit to throw")
        } catch {
            // Expected
        }

        // After error, step should revert to currentLocation
        XCTAssertEqual(vm.step, .currentLocation)
        XCTAssertNotNil(vm.submitError)
    }

    // MARK: - Helpers

    private func makeSampleViewModel() -> USMOnboardingViewModel {
        let stubClient = StubUSMRecomputeClient(
            result: .success(makeSampleResponse())
        )
        return USMOnboardingViewModel(
            userId: "test-user",
            recomputeClient: stubClient
        )
    }

    private func makeSampleCity() -> USMCity {
        USMCity(
            name: "New York",
            country: "USA",
            timezone: "America/New_York",
            lat: 40.7128,
            lon: -74.0060
        )
    }

    private func makeSampleResponse() -> USMRecomputeResponse {
        USMRecomputeResponse(
            status: "recomputation_completed",
            modelVersion: 1,
            recomputedAt: "2026-04-22T12:00:00Z",
            completedAt: "2026-04-22T12:00:00Z"
        )
    }
}

// Note: StubUSMRecomputeClient is imported from ENVITests/Core/USM/TestSupport/StubUSMRecomputeClient.swift
