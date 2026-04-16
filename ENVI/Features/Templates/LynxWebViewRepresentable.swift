//
//  LynxWebViewRepresentable.swift
//  ENVI
//
//  Phase 4 — Task 2: SwiftUI wrapper around LynxWebViewController so Phase 5's
//  TemplateTabView can host the Lynx-powered catalog surface directly.
//
//  Binding strategy:
//    - `manifest` and `userAssets` are @Binding inputs. Whenever they change,
//      the Coordinator re-serializes to JSON and pushes into the web view.
//    - `onTemplateSelected` / `onSlotSwap` are closure outputs. The Coordinator
//      registers itself as the concrete WKScriptMessageHandler for the two
//      events this wrapper cares about; Task 3's richer bridge can replace
//      these via `configure(bridgeHandlers:)`.
//
//  Target: iOS 26, Swift 6.2. Imports SwiftUI + WebKit + UIKit only.
//

import SwiftUI
import UIKit
import WebKit

struct LynxWebView: UIViewControllerRepresentable {
    let config: LynxBridgeConfig
    @Binding var manifest: TemplateManifest?
    @Binding var userAssets: [ClassifiedAsset]
    let onTemplateSelected: (UUID) -> Void
    let onSlotSwap: (UUID, UUID) -> Void

    init(
        config: LynxBridgeConfig,
        manifest: Binding<TemplateManifest?>,
        userAssets: Binding<[ClassifiedAsset]>,
        onTemplateSelected: @escaping (UUID) -> Void,
        onSlotSwap: @escaping (UUID, UUID) -> Void
    ) {
        self.config = config
        self._manifest = manifest
        self._userAssets = userAssets
        self.onTemplateSelected = onTemplateSelected
        self.onSlotSwap = onSlotSwap
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTemplateSelected: onTemplateSelected, onSlotSwap: onSlotSwap)
    }

    func makeUIViewController(context: Context) -> LynxWebViewController {
        // Merge Task 3 handlers (from config) with this wrapper's default
        // template-selected / slot-swap handler so the SwiftUI callbacks
        // fire even when Task 3's bridge isn't present yet.
        var merged = config.messageHandlers
        merged["envi.templateSelected"] = context.coordinator
        merged["envi.slotSwapRequested"] = context.coordinator

        let merged_config = LynxBridgeConfig(
            shellBundleURL: config.shellBundleURL,
            lynxBundlePath: config.lynxBundlePath,
            messageHandlers: merged
        )
        let vc = LynxWebViewController(bridgeConfig: merged_config)
        context.coordinator.controller = vc
        return vc
    }

    func updateUIViewController(_ vc: LynxWebViewController, context: Context) {
        context.coordinator.onTemplateSelected = onTemplateSelected
        context.coordinator.onSlotSwap = onSlotSwap
        context.coordinator.push(manifest: manifest, assets: userAssets, into: vc)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler {
        fileprivate weak var controller: LynxWebViewController?
        fileprivate var onTemplateSelected: (UUID) -> Void
        fileprivate var onSlotSwap: (UUID, UUID) -> Void

        private var lastManifestHash: Int?
        private var lastAssetsHash: Int?

        private static let encoder: JSONEncoder = {
            let e = JSONEncoder()
            e.dateEncodingStrategy = .iso8601
            e.outputFormatting = [.withoutEscapingSlashes]
            return e
        }()

        init(
            onTemplateSelected: @escaping (UUID) -> Void,
            onSlotSwap: @escaping (UUID, UUID) -> Void
        ) {
            self.onTemplateSelected = onTemplateSelected
            self.onSlotSwap = onSlotSwap
        }

        /// Lightweight DTO sent to Lynx. `ClassifiedAsset` is a SwiftData
        /// @Model and not directly Codable; we project the few fields Lynx
        /// needs for rendering thumbnails via the envi-asset:// scheme.
        private struct AssetDTO: Encodable {
            let id: String
            let thumbnailURL: String
        }

        fileprivate func push(
            manifest: TemplateManifest?,
            assets: [ClassifiedAsset],
            into vc: LynxWebViewController
        ) {
            if let manifest {
                // TemplateManifest is Equatable but not Hashable — use a
                // cheap proxy (version + template count + generatedAt) to
                // decide whether to resend.
                let h = manifestChangeToken(manifest)
                if h != lastManifestHash,
                   let data = try? Self.encoder.encode(manifest) {
                    lastManifestHash = h
                    Task { await vc.loadCatalog(data) }
                }
            }
            let ids = assets.map(\.localIdentifier)
            let ah = ids.hashValue
            if ah != lastAssetsHash {
                lastAssetsHash = ah
                let dtos = ids.map { id in
                    AssetDTO(id: id, thumbnailURL: "envi-asset://\(id)?size=300")
                }
                if let data = try? Self.encoder.encode(dtos) {
                    Task { await vc.updateUserAssets(data) }
                }
            }
        }

        private func manifestChangeToken(_ m: TemplateManifest) -> Int {
            var hasher = Hasher()
            hasher.combine(m.version)
            hasher.combine(m.generatedAt)
            hasher.combine(m.templates.count)
            hasher.combine(m.categories.count)
            hasher.combine(m.lynxBundleHash)
            return hasher.finalize()
        }

        // MARK: WKScriptMessageHandler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            // Sanitized name flattens the "." to "_" — see sanitize(_:) in VC.
            switch message.name {
            case "envi_templateSelected":
                if let dict = message.body as? [String: Any],
                   let raw = dict["templateId"] as? String,
                   let id = UUID(uuidString: raw) {
                    onTemplateSelected(id)
                }
            case "envi_slotSwapRequested":
                if let dict = message.body as? [String: Any],
                   let tRaw = dict["templateId"] as? String,
                   let sRaw = dict["slotId"] as? String,
                   let tid = UUID(uuidString: tRaw),
                   let sid = UUID(uuidString: sRaw) {
                    onSlotSwap(tid, sid)
                }
            default:
                break
            }
        }
    }
}
