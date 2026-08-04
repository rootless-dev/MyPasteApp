//
//  ClipboardPreferencesTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing

@testable import MyPasteApp

@MainActor
@Suite("Clipboard preferences")
struct ClipboardPreferencesTests {
    private let defaults = TestDefaults("clipboard-preferences")

    // MARK: - Preview text length

    @Test("Preview length falls back to 200 when unset")
    func previewLengthDefault() {
        #expect(ClipboardMonitor.previewTextLength(from: defaults.store) == 200)
    }

    @Test("A stored preview length is used as-is", arguments: [80, 200, 320, 500])
    func previewLengthStored(length: Int) {
        defaults.store.set(length, forKey: "previewTextLength")
        #expect(ClipboardMonitor.previewTextLength(from: defaults.store) == length)
    }

    @Test("A non-positive preview length falls back to 200", arguments: [0, -1, -200])
    func previewLengthNonPositive(length: Int) {
        // A zero would truncate every preview to an empty string, so it has to
        // be treated as "unset" rather than honoured.
        defaults.store.set(length, forKey: "previewTextLength")
        #expect(ClipboardMonitor.previewTextLength(from: defaults.store) == 200)
    }

    // MARK: - Boolean toggles

    @Test("Link previews are on by default")
    func linkPreviewsDefault() {
        #expect(ClipboardMonitor.showLinkPreviews(from: defaults.store))
    }

    @Test("Link previews honour the stored flag", arguments: [true, false])
    func linkPreviewsStored(enabled: Bool) {
        defaults.store.set(enabled, forKey: "showLinkPreviews")
        #expect(ClipboardMonitor.showLinkPreviews(from: defaults.store) == enabled)
    }

    @Test("Sound feedback is on by default")
    func soundFeedbackDefault() {
        #expect(ClipboardMonitor.soundFeedbackEnabled(from: defaults.store))
    }

    @Test("Sound feedback honours the stored flag", arguments: [true, false])
    func soundFeedbackStored(enabled: Bool) {
        defaults.store.set(enabled, forKey: "enableSoundFeedback")
        #expect(ClipboardMonitor.soundFeedbackEnabled(from: defaults.store) == enabled)
    }

    // Ignored-apps list parsing used to be tested here, directly against
    // ClipboardMonitor.ignoredBundleIDs(from:). Task 10 (Phase 5) moved that
    // responsibility to AppRules.load's legacy migration path and deleted
    // the function; the equivalent coverage now lives in AppRulesTests under
    // "Migration — legacy list parsing".
}

@Suite("Content hash")
struct ContentHashTests {
    @Test("Hashes a known string to its SHA-256 digest")
    func knownVector() {
        #expect(ClipboardMonitor.hash("abc")
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test("Hashes empty input to the SHA-256 digest of nothing")
    func emptyInput() {
        #expect(ClipboardMonitor.hash("")
                == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    @Test("The String and Data overloads agree for the same bytes")
    func overloadsAgree() {
        let text = "clipboard contents 🧷"
        #expect(ClipboardMonitor.hash(text) == ClipboardMonitor.hash(Data(text.utf8)))
    }

    @Test("A digest is always 64 lowercase hex characters")
    func digestFormat() {
        // Deduplication compares these strings directly, so the formatting has
        // to be stable — an uppercase or zero-trimmed byte would break it.
        let digest = ClipboardMonitor.hash("ff\u{0}\u{1}")
        #expect(digest.count == 64)
        #expect(digest.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    @Test("Different content hashes differently")
    func distinctInputs() {
        #expect(ClipboardMonitor.hash("a") != ClipboardMonitor.hash("b"))
    }

    @Test("The same content always hashes the same way")
    func isStable() {
        #expect(ClipboardMonitor.hash("same") == ClipboardMonitor.hash("same"))
    }
}
