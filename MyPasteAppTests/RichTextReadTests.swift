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

// @MainActor: the HTML branch of `RichText.decode` goes through AppKit's
// HTML importer, which requires the main thread — see the caution in
// `RichText.decode`'s doc comment.
@MainActor
@Suite("Rich text — decoding")
struct RichTextDecodeTests {
    /// The bug this suite exists to catch: `ItemEditorView` used to decode
    /// `richTextData` as RTF unconditionally, regardless of `richTextFormat`.
    /// `NSAttributedString(rtf:)` fails silently on HTML bytes, so an
    /// HTML-only capture opened as empty plain text, and Save then wrote
    /// that emptiness back over the original formatting — a data-loss bug
    /// with no error and no test. See RichText.decode.
    @Test("Decodes RTF bytes")
    func decodesRTF() throws {
        let original = NSAttributedString(
            string: "hello",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
        )
        let data = try original.data(
            from: NSRange(location: 0, length: original.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        let decoded = RichText.decode(data: data, format: .rtf)
        #expect(decoded?.string == "hello")
    }

    @Test("Decodes HTML bytes")
    func decodesHTML() {
        let html = Data("<b>hello</b>".utf8)
        let decoded = RichText.decode(data: html, format: .html)
        #expect(decoded?.string == "hello")
    }

    @Test("Decoding HTML bytes as RTF fails instead of silently emptying")
    func htmlBytesAsRTFFail() {
        // The exact failure mode the bug relied on: feed HTML bytes to the
        // RTF path and confirm it comes back nil rather than an
        // empty-but-non-nil string that would masquerade as "no formatting".
        let html = Data("<b>hello</b>".utf8)
        #expect(RichText.decode(data: html, format: .rtf) == nil)
    }

    @Test("Corrupted bytes decode to nil instead of crashing")
    func corruptedBytesReturnNil() {
        let garbage = Data([0xFF, 0x00, 0xDE, 0xAD, 0xBE, 0xEF])
        #expect(RichText.decode(data: garbage, format: .rtf) == nil)
    }
}
