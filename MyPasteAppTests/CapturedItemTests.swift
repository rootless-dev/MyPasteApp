//
//  CapturedItemTests.swift
//  MyPasteAppTests
//

import Foundation
import SwiftData
import Testing
@testable import MyPasteApp

@Suite("Captured items")
@MainActor
struct CapturedItemTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: ClipboardItem.self, Pinboard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

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

    @Test("sampling the same colour twice files one item")
    func capturedItemDeduplicates() throws {
        // The matching hash above only pays off if the captured paths actually
        // go through the monitor's rule. They used to `insert` directly, so
        // five samples of #FFFFFF made five identical items.
        let context = try makeContext()

        let first = ClipboardMonitor.file(ItemActions.makeCapturedItem(text: "#FFFFFF"),
                                          in: context)
        let second = ClipboardMonitor.file(ItemActions.makeCapturedItem(text: "#FFFFFF"),
                                           in: context)

        #expect(first === second)
        let all = try context.fetch(FetchDescriptor<ClipboardItem>())
        #expect(all.count == 1)
    }

    @Test("a colour that isn't in the history yet is filed")
    func capturedItemIsFiledWhenNew() throws {
        let context = try makeContext()

        ClipboardMonitor.file(ItemActions.makeCapturedItem(text: "#FFFFFF"), in: context)
        ClipboardMonitor.file(ItemActions.makeCapturedItem(text: "#000000"), in: context)

        let all = try context.fetch(FetchDescriptor<ClipboardItem>())
        #expect(all.count == 2)
    }

    @Test("re-filing an existing colour promotes it instead of duplicating")
    func refilingPromotes() throws {
        let context = try makeContext()
        let original = ItemActions.makeCapturedItem(text: "#FFFFFF")
        original.createdAt = .distantPast
        context.insert(original)
        try context.save()

        let stored = ClipboardMonitor.file(ItemActions.makeCapturedItem(text: "#FFFFFF"),
                                           in: context)

        #expect(stored === original)
        #expect(stored.createdAt.timeIntervalSinceNow > -5)
    }
}
