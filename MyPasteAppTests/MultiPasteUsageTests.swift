//
//  MultiPasteUsageTests.swift
//  MyPasteAppTests
//

import AppKit
import Foundation
import SwiftData
import Testing

@testable import MyPasteApp

@MainActor
@Suite("Multi-paste item reading and usage")
final class MultiPasteUsageTests {
    private let container: ModelContainer
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        container = try ModelContainer(
            for: ClipboardItem.self, Pinboard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @discardableResult
    private func item(_ text: String,
                      richTextData: Data? = nil,
                      richTextFormat: RichTextFormat? = nil,
                      createdAt: Date? = nil) -> ClipboardItem {
        let item = ClipboardItem(
            type: .text, preview: text, contentHash: text,
            textContent: text, richTextData: richTextData, richTextFormat: richTextFormat
        )
        if let createdAt { item.createdAt = createdAt }
        container.mainContext.insert(item)
        return item
    }

    /// An item captured as HTML, with a `textContent` that can deliberately
    /// differ from what the markup renders to — which is what a real browser
    /// capture looks like.
    @discardableResult
    private func html(_ markup: String, plain: String) -> ClipboardItem {
        let item = ClipboardItem(
            type: .text, preview: plain, contentHash: markup,
            textContent: plain,
            richTextData: Data(markup.utf8), richTextFormat: .html
        )
        container.mainContext.insert(item)
        return item
    }

    /// RTF bytes for a piece of text, produced the same way `ItemEdit.apply`
    /// produces them.
    private func rtf(_ text: String) throws -> Data {
        let attributed = NSAttributedString(string: text)
        return try attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    // MARK: - Reading

    @Test("An item with no rich text comes back as its plain text")
    func plainItem() {
        #expect(MultiPaste.attributed(for: item("hello")).string == "hello")
    }

    @Test("An item with RTF comes back decoded")
    func richItem() throws {
        let subject = item("styled", richTextData: try rtf("styled"), richTextFormat: .rtf)
        #expect(MultiPaste.attributed(for: subject).string == "styled")
    }

    @Test("An item captured as HTML is decoded as HTML, not as RTF")
    func htmlItem() {
        // The format is dispatched on, never guessed. Decoding HTML bytes as
        // RTF returns nil in silence — the Phase 2 bug — and this item would
        // quietly lose its markup on the way into the block.
        // Use a different textContent than the HTML payload to ensure the test
        // fails if the dispatch regresses to always RTF: decoding HTML as RTF
        // returns nil, falling back to textContent.
        let subject = ClipboardItem(
            type: .text,
            preview: "html_payload",
            contentHash: "html_payload",
            textContent: "fallback_plain"
        )
        subject.richTextData = Data("<b>bold</b>".utf8)
        subject.richTextFormat = .html
        container.mainContext.insert(subject)

        let result = MultiPaste.attributed(for: subject)
        #expect(result.string == "bold")
    }

    @Test("Undecodable rich text falls back to the plain text, never to empty")
    func brokenRichTextFallsBack() {
        // Claiming RTF while holding bytes that aren't RTF is exactly the shape
        // of the Phase 2 bug where a HTML-only capture was decoded as RTF,
        // returned nil in silence, and the empty result was written back over
        // the original. Falling back to empty here would drop the item out of
        // the block with no error.
        let subject = item("fallback",
                           richTextData: Data([0x00, 0x01, 0x02]),
                           richTextFormat: .rtf)
        #expect(MultiPaste.attributed(for: subject).string == "fallback")
    }

    @Test("An item with neither rich text nor plain text comes back empty")
    func emptyItem() {
        let subject = ClipboardItem(type: .text, preview: "", contentHash: "x")
        container.mainContext.insert(subject)
        #expect(MultiPaste.attributed(for: subject).string == "")
    }

    // MARK: - Trailing newlines

    @Test("Block-level HTML loses the newline the importer appends")
    func htmlBlockLosesTrailingNewline() {
        // AppKit's HTML importer terminates block content with a newline the
        // source never had: `<p>Hello world</p>` renders as "Hello world\n".
        // Left in, `joined` puts the separator *after* that break — a comma
        // alone on its own line.
        let subject = html("<p>Hello world</p>", plain: "Hello world")
        #expect(MultiPaste.attributed(for: subject).string == "Hello world")
    }

    @Test("Two HTML paragraphs join with the separator between them, not after a break")
    func htmlBlockJoinsCleanly() {
        // The end-to-end shape of the bug: two paragraphs copied from a
        // browser (captured as HTML — no browser offers RTF) marked and pasted
        // with the Comma separator.
        let first = html("<p>Hello world</p>", plain: "Hello world")
        let second = html("<p>Second one</p>", plain: "Second one")
        let block = MultiPaste.joined([MultiPaste.attributed(for: first),
                                       MultiPaste.attributed(for: second)],
                                      separator: .comma)
        #expect(block.string == "Hello world, Second one")
    }

    @Test("Only one trailing newline goes, never two")
    func stripsAtMostOneNewline() throws {
        // Two of them mean the source really did end with a blank line; only
        // the importer's own terminator is an artefact.
        let subject = item("x", richTextData: try rtf("x\n\n"), richTextFormat: .rtf)
        #expect(MultiPaste.attributed(for: subject).string == "x\n")
    }

    @Test("A plain item keeps a trailing newline it actually captured")
    func plainKeepsTrailingNewline() {
        // The fallback branch must NOT strip: with no rich data there is no
        // importer to blame, so the newline is content the user copied and
        // dropping it would silently alter the capture.
        #expect(MultiPaste.attributed(for: item("line\n")).string == "line\n")
    }

    // MARK: - The plain block

    @Test("The plain block uses textContent, not the rendered rich text")
    func plainBlockUsesTextContent() {
        // `textContent` and `richTextData` are captured side by side and for
        // HTML they routinely disagree: a bullet renders as "\t•\tone" while
        // the plain capture is just "one". ⇧↵ on the block has to hand over
        // what ⇧↵ on each item alone would.
        let first = html("<ul><li>one</li></ul>", plain: "one")
        let second = html("<ul><li>two</li></ul>", plain: "two")
        #expect(MultiPaste.plainJoined([first, second], separator: .newline) == "one\ntwo")
        // And the rendered representation really is different, so the
        // expectation above isn't accidentally satisfied by both paths
        // agreeing.
        #expect(MultiPaste.attributed(for: first).string != "one")
    }

    @Test("An item with no plain text contributes an empty piece to the plain block")
    func plainBlockWithMissingTextContent() {
        // Nothing to write, but the item must not disappear silently: its slot
        // and the separators around it stay, the same way the rich path never
        // drops an item.
        let blank = ClipboardItem(type: .text, preview: "", contentHash: "blank")
        container.mainContext.insert(blank)
        #expect(MultiPaste.plainJoined([item("a"), blank, item("b")],
                                       separator: .comma) == "a, , b")
    }

    // MARK: - Usage

    @Test("Marking used writes lastUsedAt and leaves createdAt alone")
    func markUsedDoesNotPromote() throws {
        // The whole point of the multi-paste path: pasting five items must not
        // reorder the history, and must not shift the ⌘1–⌘9 numbering with it.
        let old = Date(timeIntervalSince1970: 1_700_000_000)
        let first = item("one", createdAt: old)
        let second = item("two", createdAt: old)

        MultiPaste.markUsed([first, second], now: now)

        // Read back through a *separate* context on the same container, not
        // off the objects in memory: `mainContext` would hand back the very
        // instances just mutated, so the assertions would hold with the
        // `save()` inside `markUsed` deleted and the paste would be forgotten
        // on the next launch. A fresh context sees only what reached the
        // store.
        let stored = try ModelContext(container)
            .fetch(FetchDescriptor<ClipboardItem>())
        #expect(stored.count == 2)
        #expect(stored.allSatisfy { $0.createdAt == old })
        #expect(stored.allSatisfy { $0.lastUsedAt == now })
    }

    @Test("Marking an empty list used does nothing and doesn't crash")
    func markUsedEmpty() {
        MultiPaste.markUsed([], now: now)
    }
}
