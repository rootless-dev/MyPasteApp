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
            for: ClipboardItem.self,
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

    // MARK: - Usage

    @Test("Marking used writes lastUsedAt and leaves createdAt alone")
    func markUsedDoesNotPromote() {
        // The whole point of the multi-paste path: pasting five items must not
        // reorder the history, and must not shift the ⌘1–⌘9 numbering with it.
        let old = Date(timeIntervalSince1970: 1_700_000_000)
        let first = item("one", createdAt: old)
        let second = item("two", createdAt: old)

        MultiPaste.markUsed([first, second], now: now)

        #expect(first.createdAt == old)
        #expect(second.createdAt == old)
        #expect(first.lastUsedAt == now)
        #expect(second.lastUsedAt == now)
    }

    @Test("Marking an empty list used does nothing and doesn't crash")
    func markUsedEmpty() {
        MultiPaste.markUsed([], now: now)
    }
}
