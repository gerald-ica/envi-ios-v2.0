import Foundation

/// Sprint-03 — Client-side banned-terms checker for voice and text pipelines.
///
/// Loads a bundled JSON/YAML word-list and provides `check(_:)` and `censored(_:)`
/// so the iOS surface can gate user-generated content before it reaches the
/// network layer.
///
/// # Safety gate
///
/// The bundled `banned_terms.json` currently contains **placeholder entries
/// only** (`slur_placeholder_1`, `hate_speech_example`, etc.). Until that file
/// is replaced with a curated production list, VoiceGuard is gated behind the
/// `VoiceGuardEnabled` Boolean key in `Info.plist`, which defaults to `false`.
/// When the gate is off, the public methods (`check`, `find`, `censored`) are
/// guaranteed no-ops and never report a match. Production rollout requires
/// BOTH populating `banned_terms.json` AND setting `VoiceGuardEnabled = true`
/// in the app's Info.plist.
struct VoiceGuard {

    // MARK: - Constants

    static let defaultBundleName = "banned_terms"
    static let defaultBundleExtension = "json"

    /// Info.plist key consulted by `isEnabled`.
    static let enabledInfoPlistKey = "VoiceGuardEnabled"

    // MARK: - Feature flag

    /// Test-only override. When non-nil, short-circuits the Info.plist lookup.
    /// Leave `nil` in production code — unit tests set this in `setUp()`
    /// to exercise the matcher logic.
    nonisolated(unsafe) static var overrideEnabled: Bool? = nil

    /// `true` only when explicitly enabled via `Info.plist` (`VoiceGuardEnabled`)
    /// or via `overrideEnabled` in tests. Defaults to `false` so the moderation
    /// layer is a no-op until a curated `banned_terms.json` is shipped AND the
    /// Info.plist flag is flipped on.
    static var isEnabled: Bool {
        if let override = overrideEnabled {
            return override
        }
        let value = Bundle.main.object(forInfoDictionaryKey: enabledInfoPlistKey)
        if let flag = value as? Bool {
            return flag
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let string = value as? String {
            return (string as NSString).boolValue
        }
        return false
    }

    // MARK: - State

    private let terms: [String]
    private let pattern: NSRegularExpression?

    // MARK: - Init

    init(terms: [String]) {
        self.terms = terms
        self.pattern = VoiceGuard.compile(terms: terms)
    }

    /// Load from a bundled JSON file shaped as `["word1", "word2"]`
    /// or `{"banned_terms": ["word1", "word2"]}`.
    init?(bundleURL: URL? = nil) {
        let url: URL
        if let provided = bundleURL {
            url = provided
        } else if let bundled = Bundle.main.url(
            forResource: Self.defaultBundleName,
            withExtension: Self.defaultBundleExtension
        ) {
            url = bundled
        } else {
            return nil
        }

        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data)
        else {
            self.terms = []
            self.pattern = nil
            return
        }

        let extracted: [String]
        if let array = json as? [String] {
            extracted = array
        } else if let dict = json as? [String: Any],
                  let array = dict["banned_terms"] as? [String] {
            extracted = array
        } else {
            extracted = []
        }

        self.terms = extracted
        self.pattern = VoiceGuard.compile(terms: extracted)
    }

    // MARK: - API

    /// Returns `true` if the text contains no banned terms.
    ///
    /// When `VoiceGuard.isEnabled == false`, always returns `true`.
    func check(_ text: String) -> Bool {
        guard VoiceGuard.isEnabled else { return true }
        return find(in: text).isEmpty
    }

    /// Returns a list of banned terms found in the text (deduplicated, sorted).
    ///
    /// When `VoiceGuard.isEnabled == false`, always returns `[]`.
    func find(in text: String) -> [String] {
        guard VoiceGuard.isEnabled else { return [] }
        guard let pattern else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        let matches = pattern.matches(in: text, options: [], range: range)
        let found = matches.compactMap { match -> String? in
            guard let r = Range(match.range, in: text) else { return nil }
            return String(text[r]).lowercased()
        }
        return Array(Set(found)).sorted()
    }

    /// Replaces every banned-term occurrence with `[redacted]`.
    ///
    /// When `VoiceGuard.isEnabled == false`, returns `text` unchanged.
    func censored(_ text: String, replacement: String = "[redacted]") -> String {
        guard VoiceGuard.isEnabled else { return text }
        guard let pattern else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return pattern.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: replacement
        )
    }

    // MARK: - Helpers

    private static func compile(terms: [String]) -> NSRegularExpression? {
        guard !terms.isEmpty else { return nil }
        let escaped = terms
            .sorted(by: { $0.count > $1.count }) // longer first
            .map { NSRegularExpression.escapedPattern(for: $0) }
        let pattern = "\\b(?:" + escaped.joined(separator: "|") + ")\\b"
        return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }
}

// MARK: - Preview / Tests helpers

extension VoiceGuard {
    /// A guard seeded with a small test list for use in previews/unit tests.
    static var preview: VoiceGuard {
        VoiceGuard(terms: ["badword", "explicit", "slur"])
    }
}
