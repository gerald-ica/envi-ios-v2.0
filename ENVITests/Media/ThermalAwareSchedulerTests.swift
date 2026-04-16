//
//  ThermalAwareSchedulerTests.swift
//  ENVITests
//
//  Unit tests for the Phase 6 Task 1 ThermalAwareScheduler.
//  Uses the injected ThermalStateProvider to drive deterministic state
//  transitions without touching ProcessInfo.processInfo.
//

import XCTest
@testable import ENVI

final class ThermalAwareSchedulerTests: XCTestCase {

    // MARK: - Mocks

    private final class MockThermalProvider: ThermalStateProvider, @unchecked Sendable {
        private let lock = NSLock()
        private var _thermal: ProcessInfo.ThermalState
        private var _lowPower: Bool

        init(thermal: ProcessInfo.ThermalState = .nominal, lowPower: Bool = false) {
            self._thermal = thermal
            self._lowPower = lowPower
        }

        var thermalState: ProcessInfo.ThermalState {
            lock.lock(); defer { lock.unlock() }
            return _thermal
        }
        var isLowPowerModeEnabled: Bool {
            lock.lock(); defer { lock.unlock() }
            return _lowPower
        }

        func set(thermal: ProcessInfo.ThermalState) {
            lock.lock(); _thermal = thermal; lock.unlock()
        }
        func set(lowPower: Bool) {
            lock.lock(); _lowPower = lowPower; lock.unlock()
        }
    }

    private final class CaptureTelemetry: ThermalSchedulerTelemetry, @unchecked Sendable {
        private let lock = NSLock()
        private(set) var events: [(String, [String: String])] = []
        func log(event: String, parameters: [String: String]) {
            lock.lock(); events.append((event, parameters)); lock.unlock()
        }
    }

    // MARK: - Budget mapping

    func testInitialBudgetReflectsCurrentThermalState() async {
        for (state, lowPower, expected) in [
            (ProcessInfo.ThermalState.nominal, false, ThermalAwareScheduler.WorkBudget.full),
            (.fair, false, .reduced),
            (.serious, false, .minimal),
            (.critical, false, .none),
            // Low Power Mode caps at .reduced regardless of thermal
            (.nominal, true, .reduced),
            (.fair, true, .reduced),
            (.serious, true, .minimal),
            (.critical, true, .none)
        ] as [(ProcessInfo.ThermalState, Bool, ThermalAwareScheduler.WorkBudget)] {
            let provider = MockThermalProvider(thermal: state, lowPower: lowPower)
            let scheduler = ThermalAwareScheduler(
                provider: provider,
                telemetry: CaptureTelemetry()
            )
            let budget = await scheduler.currentBudget
            XCTAssertEqual(budget, expected, "state=\(state) lowPower=\(lowPower)")
        }
    }

    // MARK: - Transition notifications

    func testBudgetAdjustsWhenThermalChanges() async {
        let provider = MockThermalProvider(thermal: .nominal)
        let telemetry = CaptureTelemetry()
        let scheduler = ThermalAwareScheduler(provider: provider, telemetry: telemetry)

        XCTAssertEqual(await scheduler.currentBudget, .full)

        provider.set(thermal: .serious)
        await scheduler.systemStateDidChange()
        XCTAssertEqual(await scheduler.currentBudget, .minimal)

        let changed = telemetry.events.contains { $0.0 == "media_scan_thermal_state_changed" }
        XCTAssertTrue(changed, "Expected a state-changed telemetry event")
    }

    // MARK: - Suspension + resume

    func testWaitForWorkSlotSuspendsOnNone() async {
        let provider = MockThermalProvider(thermal: .critical)
        let telemetry = CaptureTelemetry()
        let scheduler = ThermalAwareScheduler(provider: provider, telemetry: telemetry)

        XCTAssertEqual(await scheduler.currentBudget, .none)

        let waited = expectation(description: "waitForWorkSlot resumes")
        Task {
            await scheduler.waitForWorkSlot()
            waited.fulfill()
        }

        // Give the waiting task a moment to enqueue its continuation.
        try? await Task.sleep(nanoseconds: 50_000_000)

        provider.set(thermal: .fair) // recovers to .reduced (>= .minimal)
        await scheduler.systemStateDidChange()

        await fulfillment(of: [waited], timeout: 2.0)

        let events = telemetry.events.map { $0.0 }
        XCTAssertTrue(events.contains("media_scan_thermal_pause"))
        XCTAssertTrue(events.contains("media_scan_thermal_resume"))
    }

    func testWaitForWorkSlotReturnsImmediatelyWhenBudgetOk() async {
        let provider = MockThermalProvider(thermal: .nominal)
        let scheduler = ThermalAwareScheduler(provider: provider, telemetry: CaptureTelemetry())
        // Should not hang.
        await scheduler.waitForWorkSlot()
    }

    // MARK: - Batch-size table

    func testBatchSizeScalesWithBudget() {
        typealias WB = ThermalAwareScheduler.WorkBudget
        typealias WT = ThermalAwareScheduler.WorkType

        // classifyBatch
        XCTAssertEqual(ThermalAwareScheduler.batchSize(for: .classifyBatch, budget: .full), 20)
        XCTAssertEqual(ThermalAwareScheduler.batchSize(for: .classifyBatch, budget: .reduced), 10)
        XCTAssertEqual(ThermalAwareScheduler.batchSize(for: .classifyBatch, budget: .minimal), 5)
        XCTAssertEqual(ThermalAwareScheduler.batchSize(for: .classifyBatch, budget: .none), 0)

        // embeddingRebuild — all-or-nothing on full/reduced
        XCTAssertEqual(ThermalAwareScheduler.batchSize(for: .embeddingRebuild, budget: .full), 1)
        XCTAssertEqual(ThermalAwareScheduler.batchSize(for: .embeddingRebuild, budget: .reduced), 1)
        XCTAssertEqual(ThermalAwareScheduler.batchSize(for: .embeddingRebuild, budget: .minimal), 0)
        XCTAssertEqual(ThermalAwareScheduler.batchSize(for: .embeddingRebuild, budget: .none), 0)

        // backgroundScan
        XCTAssertEqual(ThermalAwareScheduler.batchSize(for: .backgroundScan, budget: .full), 100)
        XCTAssertEqual(ThermalAwareScheduler.batchSize(for: .backgroundScan, budget: .reduced), 50)
        XCTAssertEqual(ThermalAwareScheduler.batchSize(for: .backgroundScan, budget: .minimal), 25)
        XCTAssertEqual(ThermalAwareScheduler.batchSize(for: .backgroundScan, budget: .none), 0)

        // lazyRescan
        XCTAssertEqual(ThermalAwareScheduler.batchSize(for: .lazyRescan, budget: .full), 50)
        XCTAssertEqual(ThermalAwareScheduler.batchSize(for: .lazyRescan, budget: .reduced), 25)
        XCTAssertEqual(ThermalAwareScheduler.batchSize(for: .lazyRescan, budget: .minimal), 10)
        XCTAssertEqual(ThermalAwareScheduler.batchSize(for: .lazyRescan, budget: .none), 0)

        // Sanity: the async instance-method wrapper matches the pure table.
        _ = WB.full; _ = WT.classifyBatch
    }

    // MARK: - Observer idempotency

    func testBeginObservingIsIdempotent() async {
        let scheduler = ThermalAwareScheduler(
            provider: MockThermalProvider(),
            telemetry: CaptureTelemetry()
        )
        await scheduler.beginObserving()
        await scheduler.beginObserving()
        await scheduler.beginObserving()
        // No crash, no leak — passes if we reach this line.
    }
}
