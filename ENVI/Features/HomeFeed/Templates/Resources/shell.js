// ENVI Lynx shell bootstrap.
// Runs inside WKWebView. Exposes window.envi for Swift <-> JS messaging,
// bootstraps the Lynx runtime from a downloaded bundle (Phase 4 Task 1),
// and forwards catalog / user-asset / scan-progress updates into Lynx.
//
// Security:
//   - No inline handlers; all events registered via addEventListener.
//   - No eval / new Function.
//   - All payloads from Swift are JSON; we JSON.parse + validate shape.
//   - CSP in lynx-shell.html restricts script-src to 'self'.
(function () {
  'use strict';

  var post = function (name, payload) {
    try {
      var handlers = (window.webkit && window.webkit.messageHandlers) || {};
      if (handlers[name] && typeof handlers[name].postMessage === 'function') {
        handlers[name].postMessage(payload == null ? {} : payload);
      }
    } catch (e) { /* swallow — bridge unavailable */ }
  };

  var state = {
    ready: false,
    lynxView: null,
    catalog: null,
    assets: null,
    bundleURL: null
  };

  var fallback = document.getElementById('fallback');
  var root = document.getElementById('root');

  function showFallback(msg) {
    if (fallback) {
      fallback.textContent = msg || 'Loading templates...';
      fallback.style.display = 'flex';
    }
  }
  function hideFallback() {
    if (fallback) fallback.style.display = 'none';
  }

  function safeParse(raw) {
    if (raw == null) return null;
    if (typeof raw === 'object') return raw;
    try { return JSON.parse(String(raw)); } catch (e) { return null; }
  }

  function pushToLynx(method, data) {
    if (!state.lynxView || typeof state.lynxView.updateData !== 'function') return;
    try { state.lynxView.updateData({ channel: method, payload: data }); }
    catch (e) { post('envi.telemetry', { event: 'lynx_update_error', properties: { method: method, message: String(e) } }); }
  }

  // window.envi — the Swift-facing API. Swift calls these via evaluateJavaScript.
  window.envi = Object.freeze({
    bootstrap: function (configJSON) {
      var cfg = safeParse(configJSON);
      if (!cfg) { showFallback('Invalid bootstrap config'); return; }
      state.bundleURL = cfg.lynxBundleURL || null;
      if (!state.bundleURL) {
        showFallback('Loading templates...');
        post('envi.catalogReady', { ready: false, reason: 'no-bundle' });
        return;
      }
      // Dynamic import of the Lynx runtime bundle (served from app bundle via
      // file:// or the envi-asset scheme). Must be same-origin per CSP.
      import(state.bundleURL).then(function (mod) {
        var createLynxView = mod.createLynxView || (mod.default && mod.default.createLynxView);
        if (typeof createLynxView !== 'function') {
          showFallback('Lynx runtime missing createLynxView');
          return;
        }
        state.lynxView = createLynxView({
          container: root,
          template: mod.template || cfg.template || null,
          initialData: { catalog: state.catalog, assets: state.assets },
          onError: function (err) { post('envi.telemetry', { event: 'lynx_error', properties: { message: String(err) } }); }
        });
        state.ready = true;
        hideFallback();
        post('envi.catalogReady', { ready: true });
      }).catch(function (err) {
        showFallback('Failed to load Lynx runtime');
        post('envi.telemetry', { event: 'lynx_import_failed', properties: { message: String(err) } });
      });
    },

    setCatalog: function (manifestJSON) {
      var parsed = safeParse(manifestJSON);
      if (!parsed) return;
      state.catalog = parsed;
      pushToLynx('catalog', parsed);
    },

    setUserAssets: function (assetsJSON) {
      var parsed = safeParse(assetsJSON);
      if (!parsed) return;
      state.assets = parsed;
      pushToLynx('assets', parsed);
    },

    updateScanProgress: function (progressJSON) {
      var parsed = safeParse(progressJSON);
      if (!parsed) return;
      pushToLynx('scanProgress', parsed);
    },

    notifyError: function (message) {
      pushToLynx('error', { message: String(message || '') });
    }
  });

  // Delegate UI events (no inline handlers). Lynx-rendered nodes can set
  // data-envi-action="template-selected" / "slot-swap" and data-* payload.
  document.addEventListener('click', function (ev) {
    var el = ev.target && ev.target.closest && ev.target.closest('[data-envi-action]');
    if (!el) return;
    var action = el.getAttribute('data-envi-action');
    if (action === 'template-selected') {
      var tid = el.getAttribute('data-template-id');
      if (tid) post('envi.templateSelected', { templateId: tid });
    } else if (action === 'slot-swap') {
      var templateId = el.getAttribute('data-template-id');
      var slotId = el.getAttribute('data-slot-id');
      if (templateId && slotId) post('envi.slotSwapRequested', { templateId: templateId, slotId: slotId });
    }
  }, false);

  // Disable long-press callout / contextmenu on any Lynx-rendered content.
  document.addEventListener('contextmenu', function (ev) { ev.preventDefault(); }, false);

  // Tell Swift the shell itself is alive. Swift will follow up with bootstrap().
  post('envi.shellReady', { version: 1 });
})();
