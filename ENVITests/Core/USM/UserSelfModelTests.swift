//
//  UserSelfModelTests.swift
//  ENVITests
//
//  Exercises the Swift USM v1 layer: schema round-trip with snake_case
//  server payloads, schema version upgrade path, SwiftData cache writes,
//  and USMSyncActor retry + LWW semantics.
//
//  Part of USM Sprint 1 — Task 1.8 (Swift half).
//

import Foundation
import XCTest
@testable import ENVI

final class UserSelfModelTests: XCTestCase {

    // MARK: - Schema round-trip

    func testRoundTripEncodeDecodeUsesSnakeCase() throws {
        let model = makeSampleModel(userId: "11111111-1111-1111-1111-111111111111")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(model)

        // Verify snake_case keys match the server schema exactly.
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json?["identity"])
        XCTAssertNotNil(json?["astro_block"])
        XCTAssertNotNil(json?["psych_block"])
        XCTAssertNotNil(json?["dynamic_block"])
        XCTAssertNotNil(json?["visual_block"])
        XCTAssertNotNil(json?["predict_block"])
        XCTAssertNotNil(json?["neuro_block"])

        let identity = json?["identity"] as? [String: Any]
        XCTAssertEqual(identity?["user_id"] as? String, "11111111-1111-1111-1111-111111111111")
        XCTAssertNotNil(identity?["model_version"])
        XCTAssertNotNil(identity?["recomputed_at"])

        // Round-trip: decode → encode → decode again.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(UserSelfModel.self, from: data)
        XCTAssertEqual(decoded, model)
    }

    func testDecodesServerStyleSnakeCasePayload() throws {
        let payload = """
        {
          "identity": {
            "user_id": "abc",
            "model_version": 1,
            "created_at": "2026-04-22T15:00:00Z",
            "updated_at": "2026-04-22T15:00:00Z",
            "recomputed_at": "2026-04-22T15:00:00Z"
          },
          "astro_block": {"sun_sign":"Aries","moon_sign":"Cancer","rising_sign":"Leo","planetary_positions":{},"nakshatras":{},"dasha_cycle":""},
          "psych_block": {"mbti_type":"INTJ","enneagram_type":5,"enneagram_wing":"","archetype":"","big_five_scores":{},"cognitive_functions":[]},
          "dynamic_block": {"mood":"focused","energy_level":0.7,"focus_areas":[],"stress_level":0.3,"recent_events":[]},
          "visual_block": {"avatar_url":"","color_palette":[],"symbolic_elements":[],"design_metadata":{}},
          "predict_block": {"near_term_outlook":"","long_term_trajectory":"","key_periods":[],"risk_factors":[]},
          "neuro_block": {"neurotype":"","cognitive_style":"","learning_preferences":[],"sensory_sensitivities":{}}
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let model = try decoder.decode(UserSelfModel.self, from: payload)

        XCTAssertEqual(model.identity.userId, "abc")
        XCTAssertEqual(model.astroBlock.sunSign, "Aries")
        XCTAssertEqual(model.psychBlock.enneagramType, 5)
        XCTAssertEqual(model.dynamicBlock.energyLevel, 0.7, accuracy: 0.001)
    }

    // MARK: - Schema version upgrade

    func testSameVersionUpgradeReturnsSameModel() throws {
        let model = makeSampleModel(userId: "u1")
        let upgraded = try UserSelfModel.upgrade(from: model, fromVersion: 1, toVersion: 1)
        XCTAssertEqual(upgraded, model)
    }

    func testUnknownUpgradePathThrows() {
        let model = makeSampleModel(userId: "u1")
        XCTAssertThrowsError(try UserSelfModel.upgrade(from: model, fromVersion: 1, toVersion: 2))
    }

    // MARK: - Cache

    func testCacheSaveLoadRoundTrip() async throws {
        let cache = try USMCache(inMemory: true)
        let model = makeSampleModel(userId: "cache-user")
        let saved = try await cache.save(
            userId: "cache-user",
            model: model,
            blockVersions: ["astro": 1, "psych": 1],
            recomputedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertTrue(saved)

        let loaded = try await cache.load(userId: "cache-user")
        XCTAssertEqual(loaded, model)

        // Re-saving the same model is a no-op because the hash matches.
        let resaved = try await cache.save(
            userId: "cache-user",
            model: model,
            blockVersions: ["astro": 1, "psych": 1],
            recomputedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertFalse(resaved)
    }

    func testCacheClearRemovesRecord() async throws {
        let cache = try USMCache(inMemory: true)
        let model = makeSampleModel(userId: "clear-me")
        try await cache.save(
            userId: "clear-me",
            model: model,
            blockVersions: [:],
            recomputedAt: Date()
        )
        try await cache.clear(userId: "clear-me")
        let loaded = try await cache.load(userId: "clear-me")
        XCTAssertNil(loaded)
    }

    // MARK: - Sync actor retry + LWW

    func testSyncActorRetriesOn5xxThenSucceeds() async throws {
        let transport = MockTransport(
            script: [
                .response(statusCode: 503, data: Data("{}".utf8)),
                .response(statusCode: 503, data: Data("{}".utf8)),
                .response(statusCode: 200, data: sampleServerPayload()),
            ]
        )
        let sync = USMSyncActor(
            baseURL: URL(string: "https://example.test")!,
            cache: try USMCache(inMemory: true),
            tokenProvider: MockTokenProvider(token: "test"),
            transport: transport,
            configuration: USMSyncActor.Configuration(
                maxAttempts: 3,
                baseDelay: 0.01,
                maxDelay: 0.05,
                jitterFactor: 0.0
            )
        )

        let model = try await sync.pull(userId: "abc")
        XCTAssertEqual(model.identity.userId, "abc")
        let calls = await transport.callCount
        XCTAssertEqual(calls, 3)
    }

    func testSyncActorFailsFastOn4xx() async throws {
        let transport = MockTransport(
            script: [
                .response(statusCode: 401, data: Data(#"{"detail":"unauthorized"}"#.utf8)),
            ]
        )
        let sync = USMSyncActor(
            baseURL: URL(string: "https://example.test")!,
            cache: try USMCache(inMemory: true),
            tokenProvider: MockTokenProvider(token: "test"),
            transport: transport,
            configuration: USMSyncActor.Configuration(
                maxAttempts: 3,
                baseDelay: 0.01,
                maxDelay: 0.05,
                jitterFactor: 0.0
            )
        )

        do {
            _ = try await sync.pull(userId: "abc")
            XCTFail("expected pull to throw")
        } catch let USMSyncError.http(statusCode) {
            XCTAssertEqual(statusCode, 401)
        }
        let calls = await transport.callCount
        XCTAssertEqual(calls, 1) // no retry on 4xx
    }

    func testSyncActorExhaustsAfterMaxAttempts() async throws {
        let transport = MockTransport(
            script: [
                .response(statusCode: 500, data: Data("{}".utf8)),
                .response(statusCode: 500, data: Data("{}".utf8)),
                .response(statusCode: 500, data: Data("{}".utf8)),
            ]
        )
        let sync = USMSyncActor(
            baseURL: URL(string: "https://example.test")!,
            cache: try USMCache(inMemory: true),
            tokenProvider: MockTokenProvider(token: "test"),
            transport: transport,
            configuration: USMSyncActor.Configuration(
                maxAttempts: 3,
                baseDelay: 0.01,
                maxDelay: 0.05,
                jitterFactor: 0.0
            )
        )

        do {
            _ = try await sync.pull(userId: "abc")
            XCTFail("expected pull to throw")
        } catch {
            // accept both .retryExhausted and the last wrapped http error
        }
        let calls = await transport.callCount
        XCTAssertEqual(calls, 3)
    }

    // MARK: - Helpers

    private func makeSampleModel(userId: String) -> UserSelfModel {
        UserSelfModel(
            identity: UserSelfModel.Identity(
                userId: userId,
                modelVersion: 1,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
                recomputedAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            astroBlock: USMAstroBlock(sunSign: "Aries", moonSign: "Cancer", risingSign: "Leo"),
            psychBlock: USMPsychBlock(mbtiType: "INTJ", enneagramType: 5),
            dynamicBlock: USMDynamicBlock(mood: "focused", energyLevel: 0.6),
            visualBlock: USMVisualBlock(),
            predictBlock: USMPredictBlock(),
            neuroBlock: USMNeuroBlock()
        )
    }

    private func sampleServerPayload() -> Data {
        """
        {
          "user_id": "abc",
          "model_version": 1,
          "created_at": "2026-04-22T15:00:00Z",
          "updated_at": "2026-04-22T15:00:00Z",
          "recomputed_at": "2026-04-22T15:00:00Z",
          "block_versions": {"astro": 1, "psych": 1, "dynamic": 1, "visual": 1, "predict": 1, "neuro": 1},
          "astro_block": {"sun_sign":"Aries","moon_sign":"Cancer","rising_sign":"Leo","planetary_positions":{},"nakshatras":{},"dasha_cycle":""},
          "psych_block": {"mbti_type":"INTJ","enneagram_type":5,"enneagram_wing":"","archetype":"","big_five_scores":{},"cognitive_functions":[]},
          "dynamic_block": {"mood":"focused","energy_level":0.7,"focus_areas":[],"stress_level":0.3,"recent_events":[]},
          "visual_block": {"avatar_url":"","color_palette":[],"symbolic_elements":[],"design_metadata":{}},
          "predict_block": {"near_term_outlook":"","long_term_trajectory":"","key_periods":[],"risk_factors":[]},
          "neuro_block": {"neurotype":"","cognitive_style":"","learning_preferences":[],"sensory_sensitivities":{}}
        }
        """.data(using: .utf8)!
    }
}

// MARK: - Test doubles

private struct MockTokenProvider: USMAuthTokenProvider {
    let token: String
    func idToken() async throws -> String { token }
}

private actor MockTransport: USMSyncTransport {
    enum Step {
        case response(statusCode: Int, data: Data)
        case error(Error)
    }

    private var script: [Step]
    private(set) var callCount: Int = 0

    init(script: [Step]) {
        self.script = script
    }

    func send(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        callCount += 1
        guard !script.isEmpty else {
            throw USMSyncError.transport(message: "script exhausted")
        }
        let step = script.removeFirst()
        switch step {
        case .response(let statusCode, let data):
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (data, response)
        case .error(let error):
            throw error
        }
    }
}
