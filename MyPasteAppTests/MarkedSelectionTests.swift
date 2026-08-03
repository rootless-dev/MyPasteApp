//
//  MarkedSelectionTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing

@testable import MyPasteApp

@MainActor
@Suite("Marked selection")
struct MarkedSelectionTests {
    private let a = UUID()
    private let b = UUID()
    private let c = UUID()

    @Test("Marking accumulates in the order it happened")
    func marksInOrder() {
        let selection = MarkedSelection()
        selection.toggle(c)
        selection.toggle(a)
        selection.toggle(b)
        // The order marked is the contract: it's what the pasted block
        // respects, not the order the cards sit in.
        #expect(selection.ids == [c, a, b])
    }

    @Test("Marking the same id twice unmarks it")
    func togglesOff() {
        let selection = MarkedSelection()
        selection.toggle(a)
        selection.toggle(a)
        #expect(selection.isEmpty)
    }

    @Test("Unmarking from the middle renumbers what follows")
    func renumbersAfterRemoval() {
        let selection = MarkedSelection()
        selection.toggle(a)
        selection.toggle(b)
        selection.toggle(c)
        selection.toggle(b)
        // Position 2 must always be the second item that will be pasted.
        #expect(selection.order(of: c) == 2)
        #expect(selection.order(of: b) == nil)
    }

    @Test("Order is 1-based, and nil for an unmarked id")
    func orderIsOneBased() {
        let selection = MarkedSelection()
        selection.toggle(a)
        #expect(selection.order(of: a) == 1)
        #expect(selection.order(of: b) == nil)
    }

    @Test("Contains and count follow the marks")
    func containsAndCount() {
        let selection = MarkedSelection()
        #expect(selection.count == 0)
        selection.toggle(a)
        selection.toggle(b)
        #expect(selection.count == 2)
        #expect(selection.contains(a))
        #expect(!selection.contains(c))
    }

    @Test("Clear empties everything")
    func clearEmpties() {
        let selection = MarkedSelection()
        selection.toggle(a)
        selection.toggle(b)
        selection.clear()
        #expect(selection.isEmpty)
    }

    // MARK: - Removal

    @Test("Removing drops the id and renumbers what follows")
    func removeRenumbers() {
        // What `OverlayView.delete` calls. Without it the deleted id stays
        // marked: the count pill keeps counting it, and with every marked item
        // deleted ↵ takes the mark branch, resolves to nothing and does
        // nothing at all.
        let selection = MarkedSelection()
        selection.toggle(a)
        selection.toggle(b)
        selection.toggle(c)
        selection.remove(a)
        #expect(selection.ids == [b, c])
        #expect(selection.count == 2)
        #expect(selection.order(of: c) == 2)
    }

    @Test("Removing an id that was never marked changes nothing")
    func removeUnmarkedIsNoOp() {
        // Deleting an unmarked card must not mark it — the difference between
        // `remove` and `toggle`, and the reason `delete` can call this
        // unconditionally.
        let selection = MarkedSelection()
        selection.toggle(a)
        selection.remove(b)
        #expect(selection.ids == [a])
    }

    @Test("Removing the last mark empties the selection")
    func removeLastEmpties() {
        // The dead-key case: the only marked card is deleted, so ↵ has to go
        // back to pasting the selected card instead of taking the mark branch.
        let selection = MarkedSelection()
        selection.toggle(a)
        selection.remove(a)
        #expect(selection.isEmpty)
    }
}
