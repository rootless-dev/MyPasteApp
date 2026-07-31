//
//  ManualItemTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing

@testable import MyPasteApp

@MainActor
@Suite("Manually created items")
struct ManualItemTests {
    @Test("Plain text becomes a text item")
    func detectsText() {
        #expect(ItemActions.makeManualItem(text: "just a note").type == .text)
    }

    @Test("A URL becomes a url item")
    func detectsURL() {
        // Same rule the monitor uses when capturing.
        #expect(ItemActions.makeManualItem(text: "https://example.com").type == .url)
    }

    @Test("The item is pinned on creation")
    func startsPinned() {
        // isPinned is the only thing RetentionPolicy protects from pruning
        // today, in both passes. Without it a hand-written snippet unused for
        // 30 days is deleted — the one case in this phase where the app would
        // destroy authored work. Roadmap item 17 replaces this with expiresAt.
        #expect(ItemActions.makeManualItem(text: "note").isPinned)
    }

    @Test("The source app is this app")
    func sourceIsThisApp() {
        // Not nil: this is what gives the card its colour and icon through the
        // path that already exists, and it happens to be true.
        #expect(ItemActions.makeManualItem(text: "note").sourceAppBundleID
                == Bundle.main.bundleIdentifier)
    }

    @Test("The hash matches the text")
    func hashesTheText() {
        #expect(ItemActions.makeManualItem(text: "note").contentHash
                == ClipboardMonitor.hash("note"))
    }
}
