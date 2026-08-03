//
//  SearchStateTests.swift
//  MyPasteAppTests
//

import Foundation
import SwiftUI
import Testing

@testable import MyPasteApp

@MainActor
@Suite("Search state")
struct SearchStateTests {
    // MARK: - Activation

    @Test("A plain letter opens the search and is kept")
    func letterOpensSearch() {
        // Losing the first character is the failure mode this rule exists to
        // prevent: the user types "gh" and the field shows "h".
        #expect(SearchState.activationCharacter("g", modifiers: [], isActive: false) == "g")
    }

    @Test("A digit opens the search too")
    func digitOpensSearch() {
        #expect(SearchState.activationCharacter("3", modifiers: [], isActive: false) == "3")
    }

    @Test("Command, control and option never open the search")
    func modifiersDoNotOpenSearch() {
        // Without this guard ⌘E would both open the editor and seed the field
        // with an "e".
        #expect(SearchState.activationCharacter("e", modifiers: .command, isActive: false) == nil)
        #expect(SearchState.activationCharacter("e", modifiers: .control, isActive: false) == nil)
        #expect(SearchState.activationCharacter("e", modifiers: .option, isActive: false) == nil)
    }

    @Test("Shift is fine — an uppercase letter still opens the search")
    func shiftIsAllowed() {
        // Phase 2's lesson: with ⇧ held, the character arrives uppercased.
        #expect(SearchState.activationCharacter("G", modifiers: .shift, isActive: false) == "G")
    }

    @Test("Space never opens the search")
    func spaceDoesNotOpenSearch() {
        // Space is the preview toggle; a leading space in a query is useless.
        #expect(SearchState.activationCharacter(" ", modifiers: [], isActive: false) == nil)
    }

    @Test("Nothing opens an already open search")
    func noReopening() {
        #expect(SearchState.activationCharacter("g", modifiers: [], isActive: true) == nil)
    }

    @Test("Activating opens the search without touching the query")
    func activateLeavesTextAlone() {
        // The seed character is applied by `OverlayView.activateSearch`, in the
        // same turn as the focus write — never here. This type owns the rule
        // (`activationCharacter`), not the writing: what makes a seed survive
        // is where the caret lands, which only `SearchTextField` can decide.
        let state = SearchState()
        state.activate()
        #expect(state.isActive)
        #expect(state.text.isEmpty)
    }

    @Test("Closing clears text, filter and panel")
    func closeClears() {
        let state = SearchState()
        state.activate()
        state.text = "g"
        state.filter.types = [.image]
        state.isFilterPanelOpen = true
        state.close()
        #expect(!state.isActive)
        #expect(state.text.isEmpty)
        #expect(state.filter.isEmpty)
        #expect(!state.isFilterPanelOpen)
    }

    // MARK: - Escape

    @Test("Escape closes the filter panel first")
    func escapeClosesPanelFirst() {
        #expect(SearchState.escapeAction(isFilterPanelOpen: true, isPreviewOpen: true,
                                         isActive: true, hasContent: true,
                                         hasMarks: false) == .closeFilterPanel)
    }

    @Test("Then the preview")
    func escapeClosesPreviewSecond() {
        #expect(SearchState.escapeAction(isFilterPanelOpen: false, isPreviewOpen: true,
                                         isActive: true, hasContent: true,
                                         hasMarks: false) == .hidePreview)
    }

    @Test("Then the search, when it has something in it")
    func escapeClosesSearchThird() {
        #expect(SearchState.escapeAction(isFilterPanelOpen: false, isPreviewOpen: false,
                                         isActive: true, hasContent: true,
                                         hasMarks: false) == .closeSearch)
    }

    @Test("An empty search doesn't cost a second escape")
    func escapeOnEmptySearchDismisses() {
        // Requiring two presses to close an empty field would be a tax on the
        // common case.
        #expect(SearchState.escapeAction(isFilterPanelOpen: false, isPreviewOpen: false,
                                         isActive: true, hasContent: false,
                                         hasMarks: false) == .dismissOverlay)
    }

    @Test("With nothing open, escape closes the overlay")
    func escapeDismisses() {
        #expect(SearchState.escapeAction(isFilterPanelOpen: false, isPreviewOpen: false,
                                         isActive: false, hasContent: false,
                                         hasMarks: false) == .dismissOverlay)
    }

    @Test("Marks are cleared before the drawer closes")
    func escapeClearsMarksBeforeDismissing() {
        #expect(SearchState.escapeAction(isFilterPanelOpen: false,
                                         isPreviewOpen: false,
                                         isActive: false,
                                         hasContent: false,
                                         hasMarks: true) == .clearMarks)
    }

    @Test("An empty search doesn't outrank the marks")
    func escapeClearsMarksWithAnEmptySearchOpen() {
        // The one combination the ordering test above doesn't reach: the field
        // is open but empty, so `isActive, hasContent` doesn't fire and the
        // marks are the most volatile thing left. Escape has to clear them
        // before it dismisses the drawer.
        #expect(SearchState.escapeAction(isFilterPanelOpen: false,
                                         isPreviewOpen: false,
                                         isActive: true,
                                         hasContent: false,
                                         hasMarks: true) == .clearMarks)
    }

    @Test("Marks wait their turn behind the filter panel, the preview and the search")
    func escapeOrderingWithMarks() {
        // Always the most volatile thing first — the rule this function
        // already followed before marks existed.
        #expect(SearchState.escapeAction(isFilterPanelOpen: true,
                                         isPreviewOpen: false,
                                         isActive: false,
                                         hasContent: false,
                                         hasMarks: true) == .closeFilterPanel)
        #expect(SearchState.escapeAction(isFilterPanelOpen: false,
                                         isPreviewOpen: true,
                                         isActive: false,
                                         hasContent: false,
                                         hasMarks: true) == .hidePreview)
        #expect(SearchState.escapeAction(isFilterPanelOpen: false,
                                         isPreviewOpen: false,
                                         isActive: true,
                                         hasContent: true,
                                         hasMarks: true) == .closeSearch)
    }

    // MARK: - Backspace

    @Test("With the search closed, backspace deletes the selected item")
    func backspaceDeletes() {
        #expect(SearchState.backspaceAction(isActive: false, textIsEmpty: true,
                                            hasTokens: false) == .deleteItem)
    }

    @Test("An empty field with tokens drops the last token")
    func backspaceRemovesToken() {
        #expect(SearchState.backspaceAction(isActive: true, textIsEmpty: true,
                                            hasTokens: true) == .removeLastToken)
    }

    @Test("With the search open, backspace never deletes an item")
    func backspaceNeverDeletesWhileSearching() {
        // Otherwise deleting a letter that isn't there destroys an item.
        #expect(SearchState.backspaceAction(isActive: true, textIsEmpty: true,
                                            hasTokens: false) == .passThrough)
        #expect(SearchState.backspaceAction(isActive: true, textIsEmpty: false,
                                            hasTokens: true) == .passThrough)
    }

    // MARK: - Tokens

    @Test("Tokens are derived from the filter, in a stable order")
    func tokenOrder() {
        var filter = SearchFilter()
        filter.types = [.image, .text]
        filter.apps = [.bundle("com.apple.Safari")]
        filter.dateWindow = .today
        #expect(SearchToken.tokens(from: filter) == [
            .type(.text), .type(.image), .app(.bundle("com.apple.Safari")), .date(.today),
        ])
    }

    @Test("Removing a token removes only that one")
    func removeToken() {
        var filter = SearchFilter()
        filter.types = [.image, .text]
        filter.dateWindow = .today
        let reduced = SearchToken.type(.image).removed(from: filter)
        #expect(reduced.types == [.text])
        #expect(reduced.dateWindow == .today)
    }

    @Test("An empty filter has no tokens")
    func noTokens() {
        #expect(SearchToken.tokens(from: SearchFilter()).isEmpty)
    }
}
