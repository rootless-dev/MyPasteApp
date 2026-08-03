//
//  PinboardScopeTests.swift
//  MyPasteAppTests
//

import Foundation
import SwiftData
import Testing

@testable import MyPasteApp

@MainActor
@Suite("Pinboard scope")
final class PinboardScopeTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: ClipboardItem.self, Pinboard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var context: ModelContext { container.mainContext }

    private func makeBoard(_ name: String) -> Pinboard {
        let board = Pinboard(name: name, colorHex: PinboardPalette.colors[0])
        context.insert(board)
        return board
    }

    private func makeItem(_ tag: String, in board: Pinboard? = nil) -> ClipboardItem {
        let item = ClipboardItem(type: .text, preview: tag, contentHash: tag, textContent: tag)
        context.insert(item)
        item.pinboard = board
        return item
    }

    @Test("The history scope contains everything")
    func historyContainsEverything() {
        let board = makeBoard("Work")
        let filed = makeItem("filed", in: board)
        let loose = makeItem("loose")

        #expect(PinboardScope.contains(item: filed, activeID: nil))
        #expect(PinboardScope.contains(item: loose, activeID: nil))
    }

    @Test("A board scope contains only its own items")
    func boardContainsOnlyItsOwn() {
        let work = makeBoard("Work")
        let links = makeBoard("Links")
        let filed = makeItem("filed", in: work)
        let elsewhere = makeItem("elsewhere", in: links)
        let loose = makeItem("loose")

        #expect(PinboardScope.contains(item: filed, activeID: work.id))
        #expect(PinboardScope.contains(item: elsewhere, activeID: work.id) == false)
        #expect(PinboardScope.contains(item: loose, activeID: work.id) == false)
    }

    @Test("Selecting a board scopes, selecting nil goes back to the history")
    func selectAndBack() {
        let scope = PinboardScope()
        let id = UUID()

        #expect(scope.activeID == nil)
        #expect(scope.isScoped == false)

        scope.select(id)
        #expect(scope.activeID == id)
        #expect(scope.isScoped)

        scope.select(nil)
        #expect(scope.activeID == nil)
        #expect(scope.isScoped == false)
    }

    @Test("Reset returns to the history")
    func resetReturnsToHistory() {
        // Called on every `show()`: reopening the drawer must never land in a
        // board, or the user copies something and doesn't see it appear.
        let scope = PinboardScope()
        scope.select(UUID())

        scope.reset()

        #expect(scope.activeID == nil)
    }

    @Test("Reset also ends an inline rename")
    func resetEndsRenaming() {
        // The rename lives here precisely so this one call covers it: as
        // `@State` in the view it outlived the drawer closing, and `+`
        // followed by a close brought the pill back as a text field on every
        // opening afterwards.
        let scope = PinboardScope()
        let id = UUID()
        scope.beginRenaming(id)
        #expect(scope.renamingBoardID == id)

        scope.reset()

        #expect(scope.renamingBoardID == nil)
    }

    @Test("Ending a rename leaves the active scope alone")
    func endRenamingKeepsScope() {
        let scope = PinboardScope()
        let id = UUID()
        scope.select(id)
        scope.beginRenaming(id)

        scope.endRenaming()

        #expect(scope.renamingBoardID == nil)
        #expect(scope.activeID == id)
    }
}
