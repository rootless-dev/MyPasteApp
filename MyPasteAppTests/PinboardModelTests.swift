//
//  PinboardModelTests.swift
//  MyPasteAppTests
//

import Foundation
import SwiftData
import Testing

@testable import MyPasteApp

/// A class suite so the in-memory `ModelContainer` stays owned — and therefore
/// alive — for the whole test, as `RetentionPolicyTests` documents.
@MainActor
@Suite("Pinboard model")
final class PinboardModelTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: ClipboardItem.self, Pinboard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var context: ModelContext { container.mainContext }

    private func makeItem(_ tag: String) -> ClipboardItem {
        let item = ClipboardItem(type: .text, preview: tag, contentHash: tag, textContent: tag)
        context.insert(item)
        return item
    }

    @Test("Assigning an item to a pinboard fills the inverse relationship")
    func assigningFillsTheInverse() throws {
        let board = Pinboard(name: "Work", colorHex: PinboardPalette.colors[0])
        context.insert(board)
        let item = makeItem("a")

        item.pinboard = board
        try context.save()

        #expect(board.items.count == 1)
        #expect(board.items.first?.preview == "a")
    }

    @Test("Deleting a pinboard keeps its items and clears their board")
    func deletingABoardKeepsItsItems() throws {
        // The central promise of roadmap item 16: a pinboard is a collection,
        // not a container. Deleting it must never delete history.
        let board = Pinboard(name: "Work", colorHex: PinboardPalette.colors[0])
        context.insert(board)
        let kept = makeItem("kept")
        kept.pinboard = board
        try context.save()

        context.delete(board)
        try context.save()

        let items = try context.fetch(FetchDescriptor<ClipboardItem>())
        #expect(items.count == 1)
        #expect(items.first?.pinboard == nil)
    }

    @Test("A new item follows the global policy and belongs to no board")
    func defaultsAreNeutral() {
        let item = makeItem("fresh")

        #expect(item.pinboard == nil)
        #expect(item.expiresAt == nil)
        #expect(item.keepForever == false)
    }
}
