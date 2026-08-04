//
//  CapturedItemTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing
@testable import MyPasteApp

@Suite("Captured items")
@MainActor
struct CapturedItemTests {

    @Test("a captured colour is an ordinary text item")
    func capturedColourIsText() {
        let item = ItemActions.makeCapturedItem(text: "#3A86FF")
        #expect(item.type == .text)
        #expect(item.textContent == "#3A86FF")
        #expect(item.preview == "#3A86FF")
    }

    @Test("a captured item is not permanent")
    func capturedItemFollowsGlobalPolicy() {
        // Unlike `makeManualItem`, which is born `keepForever` because someone
        // typed it out by hand. A sampled colour is cheap to sample again, and
        // pinning every sample would silently fill the protected set.
        let item = ItemActions.makeCapturedItem(text: "#3A86FF")
        #expect(item.keepForever == false)
        #expect(item.isPinned == false)
    }

    @Test("a captured item is credited to this app")
    func capturedItemComesFromUs() {
        // This is the whole reason the app creates the item itself instead of
        // letting the monitor pick it up: the monitor credits the frontmost
        // app, and ours is not frontmost when the system sampler closes.
        let item = ItemActions.makeCapturedItem(text: "#3A86FF")
        #expect(item.sourceAppBundleID == Bundle.main.bundleIdentifier)
    }

    @Test("the hash matches what the monitor would compute")
    func capturedItemHashesLikeACopy() {
        // A colour sampled twice must deduplicate against itself, and against
        // the same string arriving through the pasteboard.
        let item = ItemActions.makeCapturedItem(text: "#3A86FF")
        #expect(item.contentHash == ClipboardMonitor.hash("#3A86FF"))
    }
}
