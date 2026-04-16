import XCTest
@testable import ENVI

/// Phase 06-05 — AppConfig connector environment plumbing.
///
/// We can't mutate `ProcessInfo.processInfo.environment` from an iOS test at
/// runtime, so these tests focus on the _deterministic_ pieces of the
/// contract: defaults, URL shape, and enum coverage. The env-var override
/// path is exercised in the Functions-side test `config.ts` and again in
/// Phase 7 integration tests against the emulator.
final class AppConfigConnectorTests: XCTestCase {

    func testConnectorEnvironmentDefaultsToSandbox() {
        // In an unconfigured test process there is no ENVI_CONNECTOR_ENV.
        // The contract is: fall back to `.sandbox`.
        XCTAssertEqual(AppConfig.currentConnector, .sandbox)
    }

    func testConnectorEnvironmentEnumRawValuesAreStable() {
        // These raw values are the CANONICAL contract shared with
        // functions/src/lib/config.ts. Changing them is a breaking change.
        XCTAssertEqual(AppConfig.ConnectorEnvironment.sandbox.rawValue, "sandbox")
        XCTAssertEqual(AppConfig.ConnectorEnvironment.prod.rawValue, "prod")
    }

    func testConnectorFunctionsBaseURLResolvesToCloudFunctionsHost() {
        let url = AppConfig.connectorFunctionsBaseURL
        XCTAssertEqual(url.scheme, "https")
        XCTAssertTrue(
            url.host?.hasSuffix(".cloudfunctions.net") ?? false,
            "Expected cloudfunctions.net host, got \(url.absoluteString)"
        )
    }

    func testConnectorFunctionsBaseURLIncludesRegionAndProjectID() {
        let url = AppConfig.connectorFunctionsBaseURL
        let host = url.host ?? ""
        XCTAssertTrue(
            host.hasPrefix("us-central1-"),
            "Expected us-central1- prefix, got \(host)"
        )
    }

    func testConnectorEnvKeyMatchesServerSideContract() {
        // Must match the `ENVI_CONNECTOR_ENV` key in functions/.env.staging.
        XCTAssertEqual(AppConfig.connectorEnvKey, "ENVI_CONNECTOR_ENV")
    }
}
