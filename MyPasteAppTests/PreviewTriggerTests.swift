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
        #expect(OverlayView.spaceOpensPreview(searchText: ""))
    }

    @Test("Space types normally once the search has text")
    func typesWhenSearchHasText() {
        // The search field always holds focus (OverlayView.onAppear), so Space
        // can't be claimed unconditionally. "foo bar" still works because by
        // the time the space is needed the field isn't empty.
        #expect(!OverlayView.spaceOpensPreview(searchText: "foo"))
    }

    @Test("A leading space in a search has no use")
    func leadingSpaceIsNotLost() {
        #expect(OverlayView.spaceOpensPreview(searchText: ""))
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
