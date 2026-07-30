//
//  RichTextReadTests.swift
//  MyPasteAppTests
//

import AppKit
import Testing

@testable import MyPasteApp

@Suite("Rich text — reading")
struct RichTextReadTests {
    @Test("Picks RTF when both are present")
    func prefersRTFOverHTML() {
        // Browsers offer both. RTF converts through NSAttributedString without
        // WebKit, while pasteboard HTML tends to carry layout markup and
        // external CSS that pastes back unpredictably.
        #expect(RichText.preferredFormat(in: [.html, .rtf, .string]) == .rtf)
    }

    @Test("Falls back to HTML when there is no RTF")
    func usesHTMLWhenAlone() {
        #expect(RichText.preferredFormat(in: [.html, .string]) == .html)
    }

    @Test("Plain text alone has no rich format")
    func plainTextHasNoRichFormat() {
        #expect(RichText.preferredFormat(in: [.string]) == nil)
    }

    @Test("An empty pasteboard has no rich format")
    func emptyHasNoRichFormat() {
        #expect(RichText.preferredFormat(in: []) == nil)
    }

    @Test("Unrelated types are ignored")
    func ignoresUnrelatedTypes() {
        #expect(RichText.preferredFormat(in: [.tiff, .fileURL]) == nil)
    }
}
