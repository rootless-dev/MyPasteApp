//
//  TestDefaults.swift
//  MyPasteAppTests
//

import Foundation

/// An isolated `UserDefaults` domain for a single test.
///
/// Each instance gets a unique suite name, so tests never read or write the
/// user's real preferences and can run in parallel without stepping on each
/// other.
///
/// **The files these leave behind, and why the sweep is where it is.**
/// `removePersistentDomain(forName:)` empties a domain but does not delete
/// the plist `cfprefsd` wrote for it: the file stays on disk holding `{}`.
/// Deleting it from `deinit` doesn't hold either — `cfprefsd` is a separate
/// process that writes lazily, so a pending write lands after the delete and
/// recreates the file. Measured: ~60 files per run of the suite either way,
/// and 9,944 files (39 MB) had accumulated in `~/Library/Preferences` before
/// anyone looked. Nothing ever read them; their names carry a fresh UUID and
/// can't be guessed twice.
///
/// So the sweep runs **once at the start of a test process** instead, when
/// the previous run's writes have long since settled. Accumulation is bounded
/// to a single run rather than growing forever, and no timing has to be won.
final class TestDefaults {
    let suiteName: String
    let store: UserDefaults

    init(_ label: String) {
        _ = Self.sweptOnce
        suiteName = "com.alvessolutions.MyPasteApp.tests.\(label).\(UUID().uuidString)"
        guard let store = UserDefaults(suiteName: suiteName) else {
            fatalError("Could not create a UserDefaults suite named \(suiteName)")
        }
        self.store = store
    }

    deinit {
        // Still worth doing: it releases the keys immediately, so a domain
        // can't outlive its test in memory. The file is the sweep's problem.
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Sweep

    /// Runs the sweep exactly once per process, on the first `TestDefaults`
    /// built. A `static let` is the language's own once-only guarantee — no
    /// flag to check, no lock to take.
    private static let sweptOnce: Void = sweepLeftovers()

    private static let prefix = "com.alvessolutions.MyPasteApp.tests."

    /// Deletes every test suite's plist left by earlier runs.
    ///
    /// Scoped by the `tests.` prefix, which the app's own domain
    /// (`com.alvessolutions.MyPasteApp.plist`) does not carry — the user's
    /// real preferences live there and must never be touched.
    private static func sweepLeftovers() {
        let manager = FileManager.default
        for library in manager.urls(for: .libraryDirectory, in: .userDomainMask) {
            let preferences = library.appendingPathComponent("Preferences", isDirectory: true)
            guard let entries = try? manager.contentsOfDirectory(
                at: preferences,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]) else { continue }

            for url in entries
            where url.lastPathComponent.hasPrefix(prefix)
                && url.pathExtension == "plist" {
                try? manager.removeItem(at: url)
            }
        }
    }
}
