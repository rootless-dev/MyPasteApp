//
//  AppRules.swift
//  MyPasteApp
//

import Foundation

/// What the app is allowed to capture from one source app.
///
/// An empty `allowedTypes` means "ignore everything from this app" — the
/// all-or-nothing behaviour that `ignoredAppsRaw` used to provide on its own,
/// kept as the simple case because it covers most of the real use and must not
/// get harder to reach.
struct AppRule: Codable, Equatable, Identifiable {
    let bundleID: String
    var allowedTypes: Set<ClipboardItemType>

    var id: String { bundleID }
    var ignoresEverything: Bool { allowedTypes.isEmpty }

    init(bundleID: String, allowedTypes: Set<ClipboardItemType>) {
        self.bundleID = bundleID
        self.allowedTypes = allowedTypes
    }
}

/// Reading, writing and applying the per-app capture rules.
///
/// Stored as JSON in `UserDefaults` rather than in SwiftData: `ClipboardMonitor`
/// reads its settings without a `ModelContext` and should keep doing so, and a
/// privacy rule has no business inside the store that roadmap item 24 will
/// export.
enum AppRules {
    /// Every rule, migrating the pre-Phase-5 format when needed.
    ///
    /// Reading never falls back to "capture everything": a corrupt payload
    /// re-reads the old key instead of returning nothing, and the old key is
    /// left in place for a version so a decoding failure on any machine is
    /// still recoverable.
    static func load(from defaults: UserDefaults) -> [AppRule] {
        if let data = defaults.data(forKey: PreferenceKeys.appRules),
           let decoded = try? JSONDecoder().decode([AppRule].self, from: data) {
            return decoded
        }
        return migratedFromLegacy(defaults)
    }

    static func save(_ rules: [AppRule], to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        defaults.set(data, forKey: PreferenceKeys.appRules)
    }

    /// Whether nothing at all should be read from this app.
    ///
    /// Takes only a bundle ID — no pasteboard types — on purpose: this is the
    /// decision made *before* the pasteboard is read, and a signature that
    /// can't express content is a signature that can't accidentally start
    /// depending on it.
    static func ignoresEverything(_ bundleID: String?, rules: [AppRule]) -> Bool {
        guard let bundleID, let rule = rules.first(where: { $0.bundleID == bundleID })
        else { return false }
        return rule.ignoresEverything
    }

    /// Whether an item of this type, from this app, may be stored.
    static func allows(type: ClipboardItemType, from bundleID: String?, rules: [AppRule]) -> Bool {
        guard let bundleID, let rule = rules.first(where: { $0.bundleID == bundleID })
        else { return true }
        return rule.allowedTypes.contains(type)
    }

    /// Offered by a button in Settings, closing the gap Phase 1 left open: the
    /// system-level markers many of these don't set, including Apple's own
    /// Passwords app.
    static let knownPasswordManagers: [String] = [
        "com.apple.Passwords",
        "com.apple.keychainaccess",
        "com.1password.1password",
        "com.bitwarden.desktop",
        "com.dashlane.Dashlane",
    ]

    private static func migratedFromLegacy(_ defaults: UserDefaults) -> [AppRule] {
        let raw = defaults.string(forKey: PreferenceKeys.ignoredAppsRaw) ?? ""
        return raw
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { AppRule(bundleID: $0, allowedTypes: []) }
    }
}
