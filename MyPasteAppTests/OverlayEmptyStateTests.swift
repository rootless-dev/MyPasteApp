//
//  OverlayEmptyStateTests.swift
//  MyPasteAppTests
//

import Testing

@testable import MyPasteApp

/// The three empties the card strip can show. The `Text` itself lives in
/// `Views/` and has no test by project rule; the rule that picks the sentence
/// is pure and lives here.
@MainActor
@Suite("Overlay empty state")
struct OverlayEmptyStateTests {
    @Test("A board nobody filled says so")
    func emptyBoard() {
        #expect(OverlayView.emptyStateMessage(isScoped: true,
                                              hasSearchContent: false,
                                              historyIsEmpty: false) == "Empty Pinboard")
    }

    @Test("A fresh install doesn't blame a search nobody made")
    func emptyHistory() {
        // "No results" names a query the user never typed, and sends them
        // looking for a filter that isn't there.
        #expect(OverlayView.emptyStateMessage(isScoped: false,
                                              hasSearchContent: false,
                                              historyIsEmpty: true) == "Nothing copied yet")
    }

    @Test("A search that matched nothing is the only real 'no results'")
    func searchFoundNothing() {
        #expect(OverlayView.emptyStateMessage(isScoped: false,
                                              hasSearchContent: true,
                                              historyIsEmpty: false) == "No results")
        #expect(OverlayView.emptyStateMessage(isScoped: true,
                                              hasSearchContent: true,
                                              historyIsEmpty: false) == "No results")
    }

    @Test("Standing inside a board wins over an empty history")
    func scopedBeatsEmptyHistory() {
        // Both are true on a fresh install where the user just pressed `+`.
        // The message is about where they are standing.
        #expect(OverlayView.emptyStateMessage(isScoped: true,
                                              hasSearchContent: false,
                                              historyIsEmpty: true) == "Empty Pinboard")
    }
}
