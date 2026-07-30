//
//  TestDefaults.swift
//  MyPasteAppTests
//

import Foundation

/// An isolated `UserDefaults` domain for a single test.
///
/// Each instance gets a unique suite name, so tests never read or write the
/// user's real preferences and can run in parallel without stepping on each
/// other. `deinit` removes the domain so nothing is left behind on disk.
final class TestDefaults {
    let suiteName: String
    let store: UserDefaults

    init(_ label: String) {
        suiteName = "com.alvessolutions.MyPasteApp.tests.\(label).\(UUID().uuidString)"
        guard let store = UserDefaults(suiteName: suiteName) else {
            fatalError("Could not create a UserDefaults suite named \(suiteName)")
        }
        self.store = store
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }
}
