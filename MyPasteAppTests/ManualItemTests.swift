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

    @Test("The item is kept forever on creation, but not pinned")
    func startsKeptButNotPinned() {
        // Hand-written items have to survive the pruner: they were never on a
        // pasteboard, so there's nothing to copy again if they're lost.
        // `keepForever` says that without also promoting them to the top of
        // the list, which is what `isPinned` did before Phase 5.
        #expect(ItemActions.makeManualItem(text: "note").keepForever)
        #expect(ItemActions.makeManualItem(text: "note").isPinned == false)
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
