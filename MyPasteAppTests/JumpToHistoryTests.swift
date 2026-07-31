//
//  JumpToHistoryTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing

@testable import MyPasteApp

@Suite("Jump to history")
struct JumpToHistoryTests {
    @Test("Without a pending jump, the first card takes the selection")
    func withoutPending() {
        // The existing behaviour: when the list changes, selection follows the
        // top card.
        let first = UUID()
        #expect(OverlayView.selectionAfterListChange(pending: nil, newFirstID: first) == first)
    }

    @Test("A pending jump wins over the first card")
    func pendingWins() {
        // Clearing the search makes the list change, which is exactly what
        // would otherwise steal the selection away from the item the jump was
        // asked to reveal.
        let target = UUID(), first = UUID()
        #expect(OverlayView.selectionAfterListChange(pending: target, newFirstID: first) == target)
    }

    @Test("An empty list with a pending jump still resolves to the target")
    func pendingWithEmptyList() {
        let target = UUID()
        #expect(OverlayView.selectionAfterListChange(pending: target, newFirstID: nil) == target)
    }

    @Test("An empty list with no pending jump clears the selection")
    func nothingSelected() {
        #expect(OverlayView.selectionAfterListChange(pending: nil, newFirstID: nil) == nil)
    }
}
