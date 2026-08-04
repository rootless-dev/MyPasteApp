//
//  OverlayKeyGateTests.swift
//  MyPasteAppTests
//

import Testing

@testable import MyPasteApp

/// The rule that decides whether the overlay's sixteen `onKeyPress` handlers
/// act at all.
///
/// Nothing in `Views/` has a test, and this is the reason the *decision* was
/// pulled out of the view: the handlers themselves can only be exercised by
/// hand (steps B4d and B9 of `VERIFICACAO-FASE-5.md`), but what they ask before
/// running is a pure function, and that is what this suite holds.
@Suite("Overlay key gate")
struct OverlayKeyGateTests {
    @Test("A pinboard rename takes every key away from the overlay")
    func renamingSilencesTheOverlay() {
        // Not "the field consumes them" — the field never gets the chance,
        // because `onKeyPress` on the drawer's root runs first. Measured by
        // Carlos on the GUI: `+`, then typing, and the letters opened the
        // search and landed in it while the pill's field stayed empty.
        #expect(OverlayView.handlesKeys(isRenamingBoard: true) == false)
    }

    @Test("With no rename open the overlay keeps its shortcuts")
    func overlayKeepsItsKeysOtherwise() {
        // The other half of the rule, and the one that keeps this from being a
        // fix that simply switches the keyboard off: ⌘C, ↵, the arrows and the
        // rest have to go on working the moment the rename closes.
        #expect(OverlayView.handlesKeys(isRenamingBoard: false))
    }

    @Test("⌫ never resolves to a deletion while a board is being renamed")
    func backspaceCannotDeleteDuringRename() {
        #expect(OverlayView.backspaceAction(isRenamingBoard: true,
                                            isActive: false,
                                            textIsEmpty: true,
                                            hasTokens: false,
                                            hasMarks: false) == nil)
    }

    @Test("The same ⌫ deletes the selected card once the rename is over")
    func backspaceStillDeletesOutsideARename() {
        // This is what the test above is really about. With the search closed
        // and nothing marked, ⌫ resolves to destroying the selected history
        // item, and there is no undo — so a rename field that left this handler
        // armed meant backspacing over a mistyped board name took a card with
        // it. Pinning both answers is what keeps the gate from being read as
        // cosmetic.
        #expect(OverlayView.backspaceAction(isRenamingBoard: false,
                                            isActive: false,
                                            textIsEmpty: true,
                                            hasTokens: false,
                                            hasMarks: false) == .deleteItem)
    }

    @Test("The rename gate is asked before anything the search knows",
          arguments: [true, false])
    func renameOutranksTheSearchRules(isActive: Bool) {
        // Whatever the search is doing — open with text, closed, tokens or no
        // tokens — a live rename answers nil first. The search's own rules are
        // only reached once the gate has let the key through.
        #expect(OverlayView.backspaceAction(isRenamingBoard: true,
                                            isActive: isActive,
                                            textIsEmpty: false,
                                            hasTokens: true,
                                            hasMarks: true) == nil)
    }
}
