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

    // MARK: - Migration — legacy list parsing
    //
    // These mirror, case for case, what used to live in
    // `ClipboardPreferencesTests`'s "Ignored apps" section against
    // `ClipboardMonitor.ignoredBundleIDs(from:)`. That function and its old
    // caller in `poll()` were only safe to delete once this suite proved
    // `AppRules.migratedFromLegacy` parses a legacy list exactly the same
    // way — comma and any newline as separators, CRLF included, trimmed and
    // deduplicated. Losing any one of these cases silently un-bans an app
    // for anyone whose legacy list used that separator.

    @Test("Blank input migrates to no rules", arguments: ["", "   ", "\n", "\n\n  \n", ",", ",,"])
    func migrationBlankInputYieldsNoRules(raw: String) {
        store.set(raw, forKey: PreferenceKeys.ignoredAppsRaw)
        #expect(AppRules.load(from: store).isEmpty)
    }

    @Test("A single bundle ID migrates on its own")
    func migrationSingleBundleID() {
        store.set("com.agilebits.onepassword7", forKey: PreferenceKeys.ignoredAppsRaw)
        #expect(AppRules.load(from: store).map(\.bundleID) == ["com.agilebits.onepassword7"])
    }

    @Test("Newline-separated IDs migrate in order")
    func migrationNewlineSeparated() {
        store.set("com.apple.keychainaccess\ncom.1password.1password",
                  forKey: PreferenceKeys.ignoredAppsRaw)
        #expect(AppRules.load(from: store).map(\.bundleID)
                == ["com.apple.keychainaccess", "com.1password.1password"])
    }

    @Test("Comma-separated IDs migrate in order")
    func migrationCommaSeparated() {
        store.set("com.apple.keychainaccess,com.1password.1password",
                  forKey: PreferenceKeys.ignoredAppsRaw)
        #expect(AppRules.load(from: store).map(\.bundleID)
                == ["com.apple.keychainaccess", "com.1password.1password"])
    }

    @Test("Mixed separators migrate with surrounding spaces trimmed")
    func migrationMixedAndTrimmed() {
        store.set("  com.a  ,\n  com.b\n\ncom.c ,, ", forKey: PreferenceKeys.ignoredAppsRaw)
        #expect(AppRules.load(from: store).map(\.bundleID) == ["com.a", "com.b", "com.c"])
    }

    @Test("A list pasted from a CRLF file migrates with no stray carriage returns")
    func migrationCRLF() {
        // Regression guard carried over from the pre-Task-10 parser:
        // splitting on "\n" alone left a trailing "\r" glued to each ID, so
        // no bundle ID ever matched after migration.
        store.set("com.a\r\ncom.b\r\n", forKey: PreferenceKeys.ignoredAppsRaw)
        #expect(AppRules.load(from: store).map(\.bundleID) == ["com.a", "com.b"])
    }

    @Test("Repeating an ID migrates to a single rule")
    func migrationDeduplicates() {
        store.set("com.a\ncom.a\ncom.a", forKey: PreferenceKeys.ignoredAppsRaw)
        #expect(AppRules.load(from: store).map(\.bundleID) == ["com.a"])
    }

    @Test("Migrated matching is exact, so a prefix doesn't ignore a different app")
    func migrationExactMatch() {
        store.set("com.apple.Safari", forKey: PreferenceKeys.ignoredAppsRaw)
        let rules = AppRules.load(from: store)
        #expect(AppRules.ignoresEverything("com.apple.Safari", rules: rules))
        #expect(AppRules.ignoresEverything("com.apple.SafariTechnologyPreview", rules: rules) == false)
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
