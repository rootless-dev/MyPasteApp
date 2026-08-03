//
//  PinboardActionsTests.swift
//  MyPasteAppTests
//

import Foundation
import SwiftData
import Testing

@testable import MyPasteApp

@MainActor
@Suite("Pinboard actions")
final class PinboardActionsTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: ClipboardItem.self, Pinboard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var context: ModelContext { container.mainContext }
    private var actions: PinboardActions { PinboardActions(modelContext: context) }

    @Test("A new board is untitled and takes the first free colour")
    func createTakesFirstFreeColour() throws {
        let first = actions.create()
        let second = actions.create()

        #expect(first.name == Pinboard.untitledName)
        #expect(first.colorHex == PinboardPalette.colors[0])
        #expect(second.colorHex == PinboardPalette.colors[1])
    }

    @Test("Boards come back in creation order")
    func boardsAreOrderedByCreation() throws {
        // Names picked so creation order and alphabetical order disagree —
        // otherwise this test would still pass with allBoards() sorted by name.
        let first = actions.create()
        actions.rename(first, to: "Zebra")
        let second = actions.create()
        actions.rename(second, to: "Apple")

        #expect(actions.allBoards().map(\.name) == ["Zebra", "Apple"])
    }

    @Test("Renaming trims whitespace")
    func renameTrims() {
        let board = actions.create()

        actions.rename(board, to: "  Work  ")

        #expect(board.name == "Work")
    }

    @Test("Renaming to nothing falls back to Untitled")
    func renameToEmptyFallsBack() {
        // A pill with no label is a pill nobody can aim at.
        let board = actions.create()
        actions.rename(board, to: "Work")

        actions.rename(board, to: "   ")

        #expect(board.name == Pinboard.untitledName)
    }

    @Test("Recolouring stores the new hex")
    func recolorStores() {
        let board = actions.create()

        actions.recolor(board, to: PinboardPalette.colors[4])

        #expect(board.colorHex == PinboardPalette.colors[4])
    }

    @Test("Deleting a board keeps its items and releases them")
    func deleteReleasesItems() throws {
        // The promise of item 16, at the level the user actually triggers it.
        let board = actions.create()
        let item = ClipboardItem(type: .text, preview: "kept",
                                 contentHash: "kept", textContent: "kept")
        context.insert(item)
        item.pinboard = board
        try context.save()

        actions.delete(board)

        let items = try context.fetch(FetchDescriptor<ClipboardItem>())
        #expect(items.count == 1)
        #expect(items.first?.pinboard == nil)
        #expect(actions.allBoards().isEmpty)
    }
}
