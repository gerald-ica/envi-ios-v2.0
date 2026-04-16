//
//  TemplateManifest.swift
//  ENVI
//
//  Phase 4 — Template Tab v1 (Task 1).
//
//  JSON schema for server-delivered template catalog. Reuses
//  Phase 3's `VideoTemplate` directly so the ranker/match engine
//  do not need any changes when the server starts shipping real
//  templates. `lynxBundleURL` + `lynxBundleHash` describe an
//  optional Lynx render bundle that the Phase 4 WKWebView host
//  (Task 2/3) downloads + integrity-verifies.
//
//  Schema versioning: clients that don't recognize `version` MUST
//  reject the manifest (see TemplateCatalogClient). Current
//  version = 1. Bumping the version is reserved for
//  backward-incompatible schema changes.
//

import Foundation

/// Wire format for `/v1/templates/manifest`.
struct TemplateManifest: Codable, Equatable {
    /// Schema version. Current = 1. Clients reject higher versions
    /// and fall back to cached/previous manifest.
    let version: Int

    /// Server-side generation timestamp (ISO8601). Used for cache
    /// freshness heuristics and telemetry.
    let generatedAt: Date

    /// Full catalog. Phase 3 `VideoTemplate` is reused verbatim.
    let templates: [VideoTemplate]

    /// Denormalized list of categories present in `templates`.
    /// Served from the API so the client can render category
    /// chips without iterating the full catalog.
    let categories: [VideoTemplateCategory]

    /// Optional CDN URL for the Lynx render bundle. When present,
    /// `lynxBundleHash` is REQUIRED. The bundle is downloaded by
    /// `TemplateCatalogClient.refreshBundle()`.
    let lynxBundleURL: URL?

    /// SHA-256 (hex, lowercase) of the Lynx bundle at
    /// `lynxBundleURL`. Used as an integrity check before
    /// evaluating any CDN-delivered JS.
    let lynxBundleHash: String?

    /// Current manifest schema version the client understands.
    static let currentSchemaVersion: Int = 1

    /// Persisted ETag metadata for conditional (If-None-Match)
    /// refresh of the manifest. Stored alongside the cached
    /// manifest JSON.
    struct ETag: Codable, Equatable {
        let value: String
        let receivedAt: Date

        init(value: String, receivedAt: Date = Date()) {
            self.value = value
            self.receivedAt = receivedAt
        }
    }
}
