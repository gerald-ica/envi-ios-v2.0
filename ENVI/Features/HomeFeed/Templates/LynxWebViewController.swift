//
//  LynxWebViewController.swift
//  ENVI
//
//  Phase 4 — Task 2: UIKit view controller hosting a WKWebView configured
//  for the Lynx runtime. Loads a local HTML shell (Resources/lynx-shell.html)
//  which bootstraps Lynx from a downloaded bundle path (Task 1) and
//  communicates with Swift over registered WKScriptMessageHandlers (Task 3).
//
//  Scope:
//    - This controller owns the WKWebView lifecycle, shell loading, message
//      handler registration, and a custom envi-asset:// URL scheme handler.
//    - It does NOT implement concrete bridge handlers (Task 3 provides them).
//    - It does NOT own the feature flag (Task 4).
//
//  Target: iOS 26, Swift 6.2. Imports UIKit + WebKit only.
//

import UIKit
import WebKit

// MARK: - Bridge configuration

/// Configuration passed from the SwiftUI wrapper / coordinator describing
/// the local HTML shell location, the (optional) downloaded Lynx bundle
/// path, and the set of JS→Swift message handlers Task 3 wants registered.
struct LynxBridgeConfig {
    /// Local HTML shell in the app bundle (`Resources/lynx-shell.html`).
    let shellBundleURL: URL
    /// Optional local path to the downloaded Lynx render bundle (Task 1).
    /// When nil, the shell displays a "Loading templates…" fallback.
    let lynxBundlePath: URL?
    /// Concrete handlers registered onto the web view's
    /// userContentController by name — supplied by Task 3's SwiftLynxBridge.
    let messageHandlers: [String: WKScriptMessageHandler]

    init(
        shellBundleURL: URL,
        lynxBundlePath: URL?,
        messageHandlers: [String: WKScriptMessageHandler]
    ) {
        self.shellBundleURL = shellBundleURL
        self.lynxBundlePath = lynxBundlePath
        self.messageHandlers = messageHandlers
    }
}

// MARK: - View controller

/// Hosts a WKWebView configured for Lynx. Transparent background, no
/// selection / callouts, local HTML only, custom envi-asset:// scheme for
/// user asset thumbnails.
final class LynxWebViewController: UIViewController {

    // Names reserved for Swift→JS surface; never registered as handlers.
    // Task 3 registers names like "envi.templateSelected", "envi.catalogReady", etc.

    private var bridgeConfig: LynxBridgeConfig
    private(set) var webView: WKWebView!
    private var isShellLoaded = false
    private var pendingAfterLoad: [() -> Void] = []

    // MARK: Init

    init(bridgeConfig: LynxBridgeConfig) {
        self.bridgeConfig = bridgeConfig
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: Lifecycle

    override func loadView() {
        let config = makeConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.backgroundColor = .clear
        wv.isOpaque = false
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = false
        wv.scrollView.bounces = false
        wv.allowsLinkPreview = false
        wv.navigationDelegate = self
        self.webView = wv

        let container = UIView()
        container.backgroundColor = .clear
        container.addSubview(wv)
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: container.topAnchor),
            wv.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            wv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadShell()
    }

    deinit {
        // Prevent the userContentController from retaining handlers past VC life.
        MainActor.assumeIsolated {
            let ucc = webView?.configuration.userContentController
            let handlers = bridgeConfig.messageHandlers.keys
            for name in handlers {
                let sanitizedName = sanitize(name)
                ucc?.removeScriptMessageHandler(forName: sanitizedName)
            }
        }
    }

    // MARK: Public API (called from SwiftUI wrapper / Task 3 bridge)

    /// Register/replace the JS→Swift message handlers (Task 3's bridge uses this).
    func configure(bridgeHandlers: [String: WKScriptMessageHandler]) {
        let ucc = webView.configuration.userContentController
        // Remove old handlers first.
        for name in bridgeConfig.messageHandlers.keys {
            ucc.removeScriptMessageHandler(forName: sanitize(name))
        }
        bridgeConfig = LynxBridgeConfig(
            shellBundleURL: bridgeConfig.shellBundleURL,
            lynxBundlePath: bridgeConfig.lynxBundlePath,
            messageHandlers: bridgeHandlers
        )
        for (name, handler) in bridgeHandlers {
            ucc.add(WeakScriptMessageHandler(wrapping: handler), name: sanitize(name))
        }
    }

    /// Swift → JS: window.envi.setCatalog(manifestJSON)
    func loadCatalog(_ manifestJSON: Data) async {
        await callEnvi(method: "setCatalog", rawJSON: manifestJSON)
    }

    /// Swift → JS: window.envi.setUserAssets(assetsJSON)
    func updateUserAssets(_ assetsJSON: Data) async {
        await callEnvi(method: "setUserAssets", rawJSON: assetsJSON)
    }

    /// Swift → JS: window.envi.updateScanProgress({ done, total })
    func notifyScanProgress(done: Int, total: Int) async {
        let payload = #"{"done":\#(done),"total":\#(total)}"#
        await callEnvi(method: "updateScanProgress", rawJSON: Data(payload.utf8))
    }

    // MARK: Configuration

    private func makeConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = false
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        // App-bound domains hardening (Info.plist must declare the domains).
        config.limitsNavigationsToAppBoundDomains = true

        // envi-asset:// — used by Lynx to fetch user asset thumbnails by
        // local identifier without leaking filesystem paths.
        config.setURLSchemeHandler(EnviAssetSchemeHandler(), forURLScheme: "envi-asset")

        let ucc = WKUserContentController()

        // Disable text selection, long-press menus, zoom, and the 300ms
        // tap delay. Injected at documentStart so it applies before Lynx
        // mounts content into the DOM.
        let hardenJS = """
        (function(){
          var s=document.createElement('style');
          s.textContent='*{-webkit-user-select:none!important;user-select:none!important;-webkit-touch-callout:none!important;-webkit-tap-highlight-color:transparent!important;}';
          (document.head||document.documentElement).appendChild(s);
          document.addEventListener('gesturestart', function(e){e.preventDefault();}, false);
        })();
        """
        ucc.addUserScript(WKUserScript(
            source: hardenJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        // Register Task 3's handlers, wrapped to avoid retaining the VC.
        for (name, handler) in bridgeConfig.messageHandlers {
            ucc.add(WeakScriptMessageHandler(wrapping: handler), name: sanitize(name))
        }
        config.userContentController = ucc

        return config
    }

    // MARK: Load / bridge

    private func loadShell() {
        let shellURL = bridgeConfig.shellBundleURL
        // Allow read access to the Resources dir so shell.js sibling loads.
        let readAccess = shellURL.deletingLastPathComponent()
        webView.loadFileURL(shellURL, allowingReadAccessTo: readAccess)
    }

    /// Build the Swift→JS bootstrap call sent after the shell finishes loading.
    private func sendBootstrap() {
        var cfg: [String: Any] = [:]
        if let bundlePath = bridgeConfig.lynxBundlePath {
            cfg["lynxBundleURL"] = bundlePath.absoluteString
        }
        let data = (try? JSONSerialization.data(withJSONObject: cfg)) ?? Data("{}".utf8)
        Task { await callEnvi(method: "bootstrap", rawJSON: data) }
    }

    /// Swift → JS invocation. Payload is passed as a JSON string argument so
    /// the shell can JSON.parse + validate. We never string-concat values.
    private func callEnvi(method: String, rawJSON: Data) async {
        guard isShellLoaded else {
            pendingAfterLoad.append { [weak self] in
                Task { await self?.callEnvi(method: method, rawJSON: rawJSON) }
            }
            return
        }
        let jsonString = String(data: rawJSON, encoding: .utf8) ?? "null"
        // JSON is valid JS; embedding as a literal is safe and avoids eval.
        let js = "window.envi && window.envi.\(method) && window.envi.\(method)(\(jsonString));"
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { [weak self] in
                guard let self else { cont.resume(); return }
                self.webView.evaluateJavaScript(js) { _, _ in cont.resume() }
            }
        }
    }

    /// WKScriptMessageHandler names must be valid JS identifiers when
    /// referenced as `window.webkit.messageHandlers.<name>`. We flatten dots
    /// to underscores so JS uses e.g. `envi_templateSelected`.
    private func sanitize(_ name: String) -> String {
        name.replacingOccurrences(of: ".", with: "_")
    }
}

// MARK: - WKNavigationDelegate

extension LynxWebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isShellLoaded = true
        sendBootstrap()
        let pending = pendingAfterLoad
        pendingAfterLoad.removeAll()
        for job in pending { job() }
    }

    @MainActor
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else {
            return .cancel
        }
        // Only permit the local shell file, the envi-asset scheme, and
        // the explicit lynxBundlePath (if any).
        if url.isFileURL {
            return .allow
        }
        if url.scheme == "envi-asset" {
            return .allow
        }
        if let bundle = bridgeConfig.lynxBundlePath, url == bundle {
            return .allow
        }
        return .cancel
    }
}

// MARK: - envi-asset:// URL scheme handler

/// Serves JPEG thumbnails for `envi-asset://<localIdentifier>?size=<px>`.
///
/// Phase 4 stub: returns a solid-color JPEG so the Lynx surface can render
/// end-to-end without the asset cache. Phase 5 wires this to the real
/// ClassifiedAsset thumbnail pipeline (PHImageManager / on-disk cache).
private final class EnviAssetSchemeHandler: NSObject, WKURLSchemeHandler {

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL)); return
        }
        let size = parseSize(url) ?? 300
        let data = Self.stubJPEG(size: size, seed: url.host ?? url.path)
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "image/jpeg",
                "Content-Length": "\(data.count)",
                "Cache-Control": "max-age=300",
            ]
        )!
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        // Stub returns immediately; nothing to cancel.
    }

    private func parseSize(_ url: URL) -> Int? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "size" })?
            .value
            .flatMap { Int($0) }
    }

    /// Cheap deterministic color-from-string for the Phase 4 stub so
    /// different localIdentifiers render as different tiles.
    static func stubJPEG(size: Int, seed: String) -> Data {
        let px = max(16, min(size, 600))
        var hash: UInt32 = 5381
        for b in seed.utf8 { hash = (hash &* 33) &+ UInt32(b) }
        let r = CGFloat((hash >> 16) & 0xFF) / 255.0
        let g = CGFloat((hash >> 8) & 0xFF) / 255.0
        let b = CGFloat(hash & 0xFF) / 255.0
        let rect = CGRect(x: 0, y: 0, width: px, height: px)
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        let image = renderer.image { ctx in
            UIColor(red: r, green: g, blue: b, alpha: 1).setFill()
            ctx.cgContext.fill(rect)
        }
        return image.jpegData(compressionQuality: 0.7) ?? Data()
    }
}

// MARK: - Weak message-handler wrapper

/// WKUserContentController retains its handlers strongly, which can retain
/// the controller transitively. This wrapper holds its target weakly.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(wrapping target: WKScriptMessageHandler) {
        self.target = target
    }
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
