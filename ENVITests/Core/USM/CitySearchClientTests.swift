//
//  CitySearchClientTests.swift
//  ENVITests
//
//  XCTests for CitySearchClient network implementation.
//  Tests Oracle city search API integration and response mapping.
//
//  Part of USM Sprint 2 — Task 2.8b (city search client tests).
//

import Foundation
import XCTest
@testable import ENVI

@MainActor
final class CitySearchClientTests: XCTestCase {

    // MARK: - testSearchBelowMinimumLengthReturnsEmpty

    func testSearchBelowMinimumLengthReturnsEmpty() async throws {
        let stubSession = URLSession(configuration: {
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [FailingURLProtocol.self]
            return config
        }())

        let client = CitySearchClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: stubSession
        )

        let result = try await client.search("A")
        XCTAssertTrue(result.isEmpty, "Query 'A' (< 2 chars) should return empty array without network call")
    }

    // MARK: - testSearchParsesOracleResponse

    func testSearchParsesOracleResponse() async throws {
        let responseJSON = """
        [
          {
            "name": "New York, NY, USA",
            "lat": 40.7128,
            "lon": -74.0060,
            "timezone": "America/New_York",
            "population": 8000000
          }
        ]
        """
        let responseData = responseJSON.data(using: .utf8)!

        let stubSession = URLSession(configuration: {
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [StubURLProtocol.self]
            return config
        }())

        StubURLProtocol.responseData = responseData
        StubURLProtocol.responseStatus = 200

        let client = CitySearchClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: stubSession
        )

        let cities = try await client.search("New")
        XCTAssertEqual(cities.count, 1)

        let city = cities[0]
        XCTAssertEqual(city.name, "New York")
        XCTAssertEqual(city.country, "USA")
        XCTAssertEqual(city.timezone, "America/New_York")
        XCTAssertEqual(city.lat, 40.7128, accuracy: 0.0001)
        XCTAssertEqual(city.lon, -74.0060, accuracy: 0.0001)
    }

    // MARK: - testSearchSplitsMultiCommaName

    func testSearchSplitsMultiCommaName() async throws {
        let responseJSON = """
        [
          {
            "name": "Springfield, IL, USA",
            "lat": 39.7817,
            "lon": -89.6501,
            "timezone": "America/Chicago",
            "population": 113000
          }
        ]
        """
        let responseData = responseJSON.data(using: .utf8)!

        let stubSession = URLSession(configuration: {
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [StubURLProtocol.self]
            return config
        }())

        StubURLProtocol.responseData = responseData
        StubURLProtocol.responseStatus = 200

        let client = CitySearchClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: stubSession
        )

        let cities = try await client.search("Springfield")
        XCTAssertEqual(cities.count, 1)

        let city = cities[0]
        XCTAssertEqual(city.name, "Springfield")
        XCTAssertEqual(city.country, "USA")
    }

    // MARK: - testSearchHandlesTwoComponentName

    func testSearchHandlesTwoComponentName() async throws {
        let responseJSON = """
        [
          {
            "name": "London, UK",
            "lat": 51.5074,
            "lon": -0.1278,
            "timezone": "Europe/London",
            "population": 9000000
          }
        ]
        """
        let responseData = responseJSON.data(using: .utf8)!

        let stubSession = URLSession(configuration: {
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [StubURLProtocol.self]
            return config
        }())

        StubURLProtocol.responseData = responseData
        StubURLProtocol.responseStatus = 200

        let client = CitySearchClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: stubSession
        )

        let cities = try await client.search("London")
        XCTAssertEqual(cities.count, 1)

        let city = cities[0]
        XCTAssertEqual(city.name, "London")
        XCTAssertEqual(city.country, "UK")
    }

    // MARK: - testSearchServerErrorThrows

    func testSearchServerErrorThrows() async throws {
        let responseJSON = """
        {"detail": "Bad request"}
        """
        let responseData = responseJSON.data(using: .utf8)!

        let stubSession = URLSession(configuration: {
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [StubURLProtocol.self]
            return config
        }())

        StubURLProtocol.responseData = responseData
        StubURLProtocol.responseStatus = 500

        let client = CitySearchClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: stubSession
        )

        do {
            _ = try await client.search("test")
            XCTFail("Expected CitySearchError.server to be thrown")
        } catch let error as CitySearchError {
            if case .server(let status, let message) = error {
                XCTAssertEqual(status, 500)
                XCTAssertEqual(message, "Bad request")
            } else {
                XCTFail("Expected .server error, got \(error)")
            }
        }
    }

    // MARK: - testSearchTransportErrorThrows

    func testSearchTransportErrorThrows() async throws {
        let stubSession = URLSession(configuration: {
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [TransportErrorURLProtocol.self]
            return config
        }())

        let client = CitySearchClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: stubSession
        )

        do {
            _ = try await client.search("test")
            XCTFail("Expected CitySearchError.transport to be thrown")
        } catch let error as CitySearchError {
            if case .transport = error {
                // Expected
            } else {
                XCTFail("Expected .transport error, got \(error)")
            }
        }
    }
}

// MARK: - Test URL Protocols

/// URLProtocol that fails immediately (used to verify minimum length returns [] without network)
private class FailingURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        let error = NSError(domain: "TestError", code: -1, userInfo: nil)
        client?.urlProtocol(self, didFailWithError: error)
    }

    override func stopLoading() {}
}

/// URLProtocol that returns canned response data
private class StubURLProtocol: URLProtocol {
    static var responseData: Data?
    static var responseStatus: Int = 200

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let url = request.url else {
            let error = NSError(domain: "TestError", code: -1)
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: Self.responseStatus,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData ?? Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// URLProtocol that simulates a transport error
private class TransportErrorURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost)
        client?.urlProtocol(self, didFailWithError: error)
    }

    override func stopLoading() {}
}
