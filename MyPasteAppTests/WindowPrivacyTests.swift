//
//  WindowPrivacyTests.swift
//  MyPasteAppTests
//

import AppKit
import Testing

@testable import MyPasteApp

@Suite("Window privacy")
struct WindowPrivacyTests {
    private let defaults = TestDefaults("window-privacy")

    @Test("Windows are hidden from screen sharing by default")
    func hiddenByDefault() {
        // Protection that doesn't depend on the user finding the preference.
        #expect(WindowPrivacy.showInScreenSharing(from: defaults.store) == false)
        #expect(WindowPrivacy.sharingType(from: defaults.store) == .none)
    }

    @Test("Turning the preference on restores the system default")
    func visibleWhenEnabled() {
        defaults.store.set(true, forKey: "showInScreenSharing")
        #expect(WindowPrivacy.showInScreenSharing(from: defaults.store))
        #expect(WindowPrivacy.sharingType(from: defaults.store) == .readWrite)
    }

    @Test("Turning it explicitly off hides the windows")
    func hiddenWhenDisabled() {
        defaults.store.set(false, forKey: "showInScreenSharing")
        #expect(WindowPrivacy.sharingType(from: defaults.store) == .none)
    }
}
