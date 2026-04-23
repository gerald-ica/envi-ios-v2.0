//
//  StubUSMRecomputeClient.swift
//  ENVITests
//
//  Reusable stub for testing USMOnboardingViewModel and related flows.
//  Allows tests to inject success/failure responses without network calls.
//
//  Part of USM Sprint 2 shared test infrastructure.
//

import Foundation
@testable import ENVI

/// Test double that stubs USMRecomputeClientProtocol.
/// Allows tests to inject either a success response or a failure error.
struct StubUSMRecomputeClient: USMRecomputeClientProtocol {
    let result: Result<USMRecomputeResponse, Error>

    func recompute(
        userId: String,
        request: USMRecomputeRequest
    ) async throws -> USMRecomputeResponse {
        switch result {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
}
