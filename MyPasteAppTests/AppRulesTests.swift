//
//  AppRulesTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing

@testable import MyPasteApp

/// Swift Testing builds a fresh instance per test, so one property here gives
/// every test its own `UserDefaults` suite — and, crucially, keeps the
/// `TestDefaults` alive for the whole test. A local `TestDefaults(...).store`
/// would deallocate the owner at the end of the expression, and its `deinit`
/// removes the domain.
@Suite("App rules")
struct AppRulesTests {
    private let defaults = TestDefaults("app-rules")
    private var store: UserDefaults { defaults.store }

    // MARK: - Storage

    @Test("Saved rules come back unchanged")
    func roundTrips() {
        let rules = [
            AppRule(bundleID: "com.apple.Passwords", allowedTypes: []),
            AppRule(bundleID: "com.tinyspeck.slackmacgap", allowedTypes: [.text, .url]),
        ]

        AppRules.save(rules, to: store)

        #expect(AppRules.load(from: store) == rules)
    }

    @Test("An empty store yields no rules")
    func emptyStoreIsEmpty() {
        #expect(AppRules.load(from: store).isEmpty)
    }

    // MARK: - Migration

    @Test("The old one-per-line format becomes ignore-everything rules")
    func migratesTheOldFormat() {
        store.set("com.apple.Passwords\ncom.apple.keychainaccess",
                  forKey: PreferenceKeys.ignoredAppsRaw)

        let rules = AppRules.load(from: store)

        #expect(rules.count == 2)
        // A keypath passed straight to `allSatisfy` inside `#expect` trips a
        // Swift 6.3 macro-expansion bug ("call can throw" on a non-throwing
        // keypath); an explicit closure sidesteps it with identical behaviour.
        #expect(rules.allSatisfy { $0.ignoresEverything })
        #expect(Set(rules.map(\.bundleID))
                == ["com.apple.Passwords", "com.apple.keychainaccess"])
    }

    @Test("Blank lines and stray spaces are dropped on migration")
    func migrationIgnoresBlankLines() {
        store.set("\n  com.apple.Passwords  \n\n\n", forKey: PreferenceKeys.ignoredAppsRaw)

        let rules = AppRules.load(from: store)

        #expect(rules.map(\.bundleID) == ["com.apple.Passwords"])
    }

    @Test("Corrupt JSON falls back to the old format, never to nothing")
    func corruptJSONFallsBackToTheOldFormat() {
        // Falling back to an empty list would silently start capturing from a
        // password manager the user excluded — the worst possible regression
        // in this feature, and the reason the old key is kept for a version.
        store.set("not json at all", forKey: PreferenceKeys.appRules)
        store.set("com.apple.Passwords", forKey: PreferenceKeys.ignoredAppsRaw)

        let rules = AppRules.load(from: store)

        #expect(rules.map(\.bundleID) == ["com.apple.Passwords"])
        #expect(rules.allSatisfy { $0.ignoresEverything })
    }

    @Test("Saved rules win over the old key")
    func savedRulesWinOverTheOldKey() {
        store.set("com.apple.Passwords", forKey: PreferenceKeys.ignoredAppsRaw)
        AppRules.save([AppRule(bundleID: "com.tinyspeck.slackmacgap",
                               allowedTypes: [.text])], to: store)

        #expect(AppRules.load(from: store).map(\.bundleID) == ["com.tinyspeck.slackmacgap"])
    }

    // MARK: - Decisions

    @Test("An app with no rule is captured in full")
    func unknownAppIsCaptured() {
        let rules = [AppRule(bundleID: "com.apple.Passwords", allowedTypes: [])]

        #expect(AppRules.ignoresEverything("com.tinyspeck.slackmacgap", rules: rules) == false)
        #expect(AppRules.allows(type: .image, from: "com.tinyspeck.slackmacgap", rules: rules))
    }

    @Test("An empty rule ignores everything from that app")
    func emptyRuleIgnoresEverything() {
        let rules = [AppRule(bundleID: "com.apple.Passwords", allowedTypes: [])]

        #expect(AppRules.ignoresEverything("com.apple.Passwords", rules: rules))
    }

    @Test("A typed rule allows only its own types")
    func typedRuleFiltersByType() {
        let rules = [AppRule(bundleID: "com.tinyspeck.slackmacgap", allowedTypes: [.text, .url])]

        #expect(AppRules.allows(type: .text, from: "com.tinyspeck.slackmacgap", rules: rules))
        #expect(AppRules.allows(type: .url, from: "com.tinyspeck.slackmacgap", rules: rules))
        #expect(AppRules.allows(type: .image, from: "com.tinyspeck.slackmacgap", rules: rules) == false)
        #expect(AppRules.allows(type: .file, from: "com.tinyspeck.slackmacgap", rules: rules) == false)
    }

    @Test("A typed rule does not ignore everything")
    func typedRuleIsNotATotalBlock() {
        // The two decisions are asked at different points in poll(): getting
        // this wrong would drop everything from an app the user only wanted
        // narrowed.
        let rules = [AppRule(bundleID: "com.tinyspeck.slackmacgap", allowedTypes: [.text])]

        #expect(AppRules.ignoresEverything("com.tinyspeck.slackmacgap", rules: rules) == false)
    }

    @Test("An item with no source app is always allowed")
    func nilBundleIDIsAllowed() {
        // Hand-written items (roadmap item 10) carry the app's own bundle ID,
        // but anything else without a source has no rule to match and must not
        // be filtered by one.
        let rules = [AppRule(bundleID: "com.apple.Passwords", allowedTypes: [])]

        #expect(AppRules.ignoresEverything(nil, rules: rules) == false)
        #expect(AppRules.allows(type: .text, from: nil, rules: rules))
    }

    @Test("The known password managers list is non-empty and includes Apple's")
    func knownPasswordManagers() {
        #expect(AppRules.knownPasswordManagers.contains("com.apple.Passwords"))
        #expect(AppRules.knownPasswordManagers.count >= 5)
    }
}
