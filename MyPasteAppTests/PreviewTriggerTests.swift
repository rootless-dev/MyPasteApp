//
//  PreviewTriggerTests.swift
//  MyPasteAppTests
//

import Testing

@testable import MyPasteApp

@Suite("Preview trigger")
struct PreviewTriggerTests {
    @Test("Space opens the preview when the search is empty")
    func opensWithEmptySearch() {
        #expect(OverlayView.spaceAction(searchText: "", isPreviewOpen: false)
                == .showPreview)
    }

    @Test("Space closes the preview it opened")
    func closesWhatItOpened() {
        // The key that opens the panel closes it. Anything else would make the
        // user reach for Escape to undo what Space just did.
        #expect(OverlayView.spaceAction(searchText: "", isPreviewOpen: true)
                == .hidePreview)
    }

    @Test("Space types normally once the search has text", arguments: [false, true])
    func typesWhenSearchHasText(isPreviewOpen: Bool) {
        // The search field always holds focus (OverlayView.onAppear), so Space
        // can't be claimed unconditionally. "foo bar" still works because by
        // the time the space is needed the field isn't empty — and that holds
        // whether or not the panel happens to be open.
        #expect(OverlayView.spaceAction(searchText: "foo", isPreviewOpen: isPreviewOpen)
                == .type)
    }

    @Test("Escape closes the preview first")
    func escapeClosesPreviewBeforeOverlay() {
        // Convention: dismiss what's on top. Without this the user loses the
        // whole drawer while trying to close the panel over it.
        #expect(OverlayView.escapeClosesPreview(isPreviewOpen: true))
    }

    @Test("Escape closes the overlay when no preview is open")
    func escapeClosesOverlayOtherwise() {
        #expect(!OverlayView.escapeClosesPreview(isPreviewOpen: false))
    }
}
