//
//  ThermalAwareScheduler.swift
//  ENVI
//
//  Phase 6 Task 1 — Adaptive thermal-aware work throttling.
//
//  A single actor that every background/bulk pipeline (MediaClassifier.classifyBatch,
//  MediaScanCoordinator background sweep, EmbeddingIndex.rebuild, lazy rescan) asks
//  before scheduling its next unit of work. The scheduler maps the current
//  `ProcessInfo.ThermalState` and Low Power Mode flag onto a `WorkBudget`,
//  dynamically resizes per-work-type batches, and suspends callers when the
//  budget drops to `.none` (critical thermal) until the OS broadcasts recovery.
//
//  Key design decisions:
//    - Single actor. All state mutation (observer tokens, continuations, last
//      transitioned budget) is actor-isolated so we never race with the
//      NotificationCenter callback that re-posts into the actor.
//    - No polling. We observe `ProcessInfo.thermalStateDidChangeNotification`
//      and `.NSProcessInfoPowerStateDidChange`. When either fires we recompute
//      and resume every suspended `waitForWorkSlot()` continuation if the new
//      budget is `>= .minimal`.
//    - Testability. The real thermal state is injected via `ThermalStateProvider`,
//      so tests can mock both ProcessInfo and the notification feed without
//      monkey-patching Foundation singletons.
//    - Low Power Mode is a hard cap at `.reduced` regardless of thermal —
//      users opt into LPM explicitly and expect reduced background work.
//
//  Telemetry: every transition (both state changes and pause/resume gates) is
//  logged through TelemetryManager with the event names documented in
//  Phase 6 Task 3 of the plan (media_scan_thermal_pause,
//  media_scan_thermal_resume, media_scan_thermal_state_changed).
//

import Foundation

// MARK: - ThermalStateProvider (test seam)

/// Abstracts `ProcessInfo` so tests can drive thermal + low-power state
/// without needing a private framework. The default implementation reads
/// `ProcessInfo.processInfo`; tests inject a mock.
public protocol ThermalStateProvider: Sendable {
    var thermalState: ProcessInfo.ThermalState { get }
    var isLowPowerModeEnabled: Bool { get }
}

/// Production provider — plain `ProcessInfo.processInfo` reads.
public struct SystemThermalStateProvider: ThermalStateProvider {
    public init() {}
    public var thermalState: ProcessInfo.ThermalState {
        ProcessInfo.processInfo.thermalState
    }
    public var isLowPowerModeEnabled: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled
    }
}

// MARK: - Telemetry seam

/// Minimal indirection so the scheduler can be unit-tested without pulling
/// Firebase into the test target. The default logger forwards to the
/// production TelemetryManager; tests can inject a capture-only stub.
public protocol ThermalSchedulerTelemetry: Sendable {
    func log(event: String, parameters: [String: String])
}

public struct DefaultThermalSchedulerTelemetry: ThermalSchedulerTelemetry {
    public init() {}
    public func log(event: String, parameters: [String: String]) {
        // Forward via the existing TelemetryManager. We stringify values so
        // the event is Firebase-safe (all params are primitives).
        var params: [String: Any] = [:]
        for (k, v) in parameters { params[k] = v }
        // We don't require the event to exist in TelemetryManager.Event —
        // thermal events are a new category added in Phase 6. Use the raw
        // log call path (Analytics.logEvent) by routing through
        // TelemetryManager's generic track when the event matches,
        // otherwise no-op safely. Here we simply call a convenience bridge.
        ThermalTelemetryBridge.track(event: event, parameters: params)
    }
}

// Bridge that hides the import of TelemetryManager behind a function call
// and gracefully no-ops when Firebase isn't linked (e.g. in the standalone
// `swiftc -parse` build listed as the phase blocker).
enum ThermalTelemetryBridge {
    static func track(event: String, parameters: [String: Any]) {
        #if canImport(FirebaseAnalytics)
        TelemetryManager.shared.track(rawEvent: event, parameters: parameters)
        #else
        _ = (event, parameters)
        #endif
    }
}

// MARK: - ThermalAwareScheduler

public actor ThermalAwareScheduler {

    // MARK: Types

    public enum WorkBudget: Int, Comparable, Sendable {
        case none = 0       // critical thermal — stop optional work
        case minimal = 1    // serious thermal — pause non-essential
        case reduced = 2    // fair thermal (or Low Power Mode cap) — slow
        case full = 3       // nominal thermal + not low-power

        public static func < (lhs: WorkBudget, rhs: WorkBudget) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public enum WorkType: Sendable {
        case classifyBatch
        case embeddingRebuild
        case backgroundScan
        case lazyRescan
    }

    // MARK: Singleton

    public static let shared = ThermalAwareScheduler()

    // MARK: State

    private let provider: ThermalStateProvider
    private let telemetry: ThermalSchedulerTelemetry

    /// Cached budget snapshot — updated lazily when notifications fire or
    /// when a caller reads `currentBudget`. Used so transitions can be
    /// diffed against the *previous* observed budget for logging.
    private var lastBudget: WorkBudget

    /// Pending continuations waiting for budget >= .minimal.
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// `true` after `beginObserving()` has registered the NC observers.
    /// Idempotent — repeat calls are no-ops.
    private var isObserving = false

    /// Opaque observer tokens we own; canceled in `deinit` through the
    /// actor's isolated helpers.
    private nonisolated(unsafe) var thermalObserver: NSObjectProtocol?
    private nonisolated(unsafe) var powerObserver: NSObjectProtocol?

    // MARK: Init

    public init(
        provider: ThermalStateProvider = SystemThermalStateProvider(),
        telemetry: ThermalSchedulerTelemetry = DefaultThermalSchedulerTelemetry()
    ) {
        self.provider = provider
        self.telemetry = telemetry
        // Seed from a synchronous read — safe, no async hop needed.
        self.lastBudget = Self.compute(from: provider)
    }

    deinit {
        if let t = thermalObserver {
            NotificationCenter.default.removeObserver(t)
        }
        if let p = powerObserver {
            NotificationCenter.default.removeObserver(p)
        }
        // Clear observers to satisfy Sendable requirements
        thermalObserver = nil
        powerObserver = nil
    }

    // MARK: Public API

    /// Current budget computed from the injected provider. Reading this
    /// also updates the cached `lastBudget` without emitting telemetry —
    /// telemetry transitions fire through the NC observer path only, so
    /// reads stay cheap and side-effect free for callers.
    public var currentBudget: WorkBudget {
        get async {
            let fresh = Self.compute(from: provider)
            lastBudget = fresh
            return fresh
        }
    }

    /// Suspends until budget >= .minimal. Returns immediately when the
    /// current budget already satisfies that threshold.
    public func waitForWorkSlot() async {
        let budget = Self.compute(from: provider)
        lastBudget = budget
        if budget >= .minimal {
            return
        }
        // Log the pause transition so operators can correlate thermal
        // throttling to observed slowdowns in the field.
        telemetry.log(
            event: "media_scan_thermal_pause",
            parameters: [
                "budget": String(describing: budget),
                "thermal_state": Self.describe(provider.thermalState),
                "low_power": provider.isLowPowerModeEnabled ? "1" : "0"
            ]
        )
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            waiters.append(cont)
        }
    }

    /// Dynamic batch size for the given work type at the current budget.
    public func batchSize(for work: WorkType) async -> Int {
        let budget = Self.compute(from: provider)
        lastBudget = budget
        return Self.batchSize(for: work, budget: budget)
    }

    /// Pure helper so tests can validate the table without an actor hop.
    public nonisolated static func batchSize(for work: WorkType, budget: WorkBudget) -> Int {
        switch (work, budget) {
        case (.classifyBatch, .full):       return 20
        case (.classifyBatch, .reduced):    return 10
        case (.classifyBatch, .minimal):    return 5
        case (.classifyBatch, .none):       return 0

        case (.embeddingRebuild, .full):    return 1
        case (.embeddingRebuild, .reduced): return 1
        case (.embeddingRebuild, .minimal): return 0
        case (.embeddingRebuild, .none):    return 0

        case (.backgroundScan, .full):      return 100
        case (.backgroundScan, .reduced):   return 50
        case (.backgroundScan, .minimal):   return 25
        case (.backgroundScan, .none):      return 0

        case (.lazyRescan, .full):          return 50
        case (.lazyRescan, .reduced):       return 25
        case (.lazyRescan, .minimal):       return 10
        case (.lazyRescan, .none):          return 0
        }
    }

    /// Registers NotificationCenter observers for thermal + power transitions.
    /// Idempotent — repeat calls after the first are no-ops.
    public func beginObserving() {
        guard !isObserving else { return }
        isObserving = true

        let center = NotificationCenter.default
        thermalObserver = center.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { await self.systemStateDidChange() }
        }
        powerObserver = center.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { await self.systemStateDidChange() }
        }
    }

    /// Test hook so unit tests can drive the same code path the NC observer
    /// would — without having to actually post system notifications.
    public func systemStateDidChange() {
        let previous = lastBudget
        let next = Self.compute(from: provider)
        lastBudget = next

        if next != previous {
            telemetry.log(
                event: "media_scan_thermal_state_changed",
                parameters: [
                    "from": String(describing: previous),
                    "to": String(describing: next),
                    "thermal_state": Self.describe(provider.thermalState),
                    "low_power": provider.isLowPowerModeEnabled ? "1" : "0"
                ]
            )
        }

        // If we've recovered to at least .minimal, wake every waiter.
        if next >= .minimal, !waiters.isEmpty {
            telemetry.log(
                event: "media_scan_thermal_resume",
                parameters: [
                    "budget": String(describing: next),
                    "waiters": String(waiters.count)
                ]
            )
            let pending = waiters
            waiters.removeAll()
            for cont in pending {
                cont.resume()
            }
        }
    }

    // MARK: Private helpers

    /// Pure mapping: thermalState + lowPower → WorkBudget.
    /// Low Power Mode caps at `.reduced` regardless of thermal.
    private nonisolated static func compute(from provider: ThermalStateProvider) -> WorkBudget {
        let thermal: WorkBudget
        switch provider.thermalState {
        case .nominal:  thermal = .full
        case .fair:     thermal = .reduced
        case .serious:  thermal = .minimal
        case .critical: thermal = .none
        @unknown default: thermal = .reduced
        }
        if provider.isLowPowerModeEnabled {
            return min(thermal, .reduced)
        }
        return thermal
    }

    private nonisolated static func describe(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:  return "nominal"
        case .fair:     return "fair"
        case .serious:  return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - TelemetryManager bridge
//
// The production TelemetryManager's `track(_:parameters:)` takes a typed
// Event enum. Thermal events are new in Phase 6 and we don't want to
// rev the enum from a Core/Media file — instead we extend the manager
// with a raw-event escape hatch used exclusively by this scheduler.
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
import FirebaseCore
extension TelemetryManager {
    func track(rawEvent: String, parameters: [String: Any]?) {
        guard FirebaseApp.app() != nil else { return }
        Analytics.logEvent(rawEvent, parameters: parameters)
    }
}
#endif
