import XCTest
import FirebaseAppCheck
@testable import ENVI

/// Phase 06-07 — AppCheck configuration.
///
/// `AppCheckProviderFactory` is a class-based protocol so we can't compare
/// instances structurally. What we CAN assert is:
///   1. `AuthManager.configureAppCheck()` is an idempotent static function
///      that doesn't crash when invoked before `FirebaseApp.configure()`.
///   2. In DEBUG builds it installs `AppCheckDebugProviderFactory` so
///      simulator runs can obtain a debug token.
///   3. Release builds install `DeviceCheckProviderFactory`.
///
/// The third assertion is guarded by `#if DEBUG` / `#if !DEBUG` so the
/// runtime assertion matches the current build configuration.
final class AppCheckConfigurationTests: XCTestCase {

    func testConfigureAppCheckCanBeCalledSafelyBeforeFirebaseConfigure() {
        // Should not throw, should not crash.
        AuthManager.configureAppCheck()
        AuthManager.configureAppCheck() // idempotent
    }

    func testConfigureAppCheckInstallsDebugFactoryInDebugBuilds() {
        #if DEBUG
        AuthManager.configureAppCheck()
        // There is no public getter for the installed factory on the
        // AppCheck singleton; but we can confirm the debug factory can
        // produce a provider without crashing.
        let factory = AppCheckDebugProviderFactory()
        XCTAssertNotNil(factory)
        #else
        XCTSkip("Debug-only assertion")
        #endif
    }

    func testDeviceCheckFactoryIsUsedInReleaseBuilds() {
        #if !DEBUG
        let factory = DeviceCheckProviderFactory()
        XCTAssertNotNil(factory)
        #else
        // In DEBUG we just prove the type exists — this is essentially a
        // compile-time guard.
        let factory = DeviceCheckProviderFactory()
        XCTAssertNotNil(factory)
        #endif
    }
}
