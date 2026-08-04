//
//  MultiPasteTests.swift
//  MyPasteAppTests
//

import AppKit
import Foundation
import SwiftData
import Testing

@testable import MyPasteApp

@MainActor
@Suite("Multi-paste")
final class MultiPasteTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: ClipboardItem.self, Pinboard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @discardableResult
    private func item(_ text: String, type: ClipboardItemType = .text) -> ClipboardItem {
        let item = ClipboardItem(type: type, preview: text, contentHash: text, textContent: text)
        container.mainContext.insert(item)
        return item
    }

    // MARK: - Type gate

    @Test("Only text and URL can be marked")
    func markableTypes() {
        #expect(MultiPaste.isMarkable(.text))
        #expect(MultiPaste.isMarkable(.url))
        #expect(!MultiPaste.isMarkable(.image))
        #expect(!MultiPaste.isMarkable(.file))
    }

    // MARK: - Resolution

    @Test("Resolves in the order marked, not the order of the list")
    func resolveFollowsMarkOrder() {
        let first = item("one")
        let second = item("two")
        let third = item("three")
        let resolved = MultiPaste.resolve(ids: [third.id, first.id],
                                          in: [first, second, third])
        #expect(resolved.map(\.id) == [third.id, first.id])
    }

    @Test("An id with no item left is dropped")
    func resolveDropsMissing() {
        // This is how an item deleted while marked leaves the block: no
        // reactive cleanup anywhere, it just isn't found.
        let present = item("here")
        let resolved = MultiPaste.resolve(ids: [UUID(), present.id], in: [present])
        #expect(resolved.map(\.id) == [present.id])
    }

    @Test("No marks and no items both resolve to nothing")
    func resolveEmptyCases() {
        let present = item("here")
        #expect(MultiPaste.resolve(ids: [], in: [present]).isEmpty)
        #expect(MultiPaste.resolve(ids: [present.id], in: []).isEmpty)
    }

    // MARK: - Joining

    @Test("Joins three pieces with the separator between them")
    func joinsThree() {
        let pieces = ["a", "b", "c"].map { NSAttributedString(string: $0) }
        #expect(MultiPaste.joined(pieces, separator: .newline).string == "a\nb\nc")
    }

    @Test("No separator before the first or after the last")
    func noTrailingSeparator() {
        let pieces = ["a", "b"].map { NSAttributedString(string: $0) }
        // The exact string already says everything a prefix/suffix check
        // could.
        #expect(MultiPaste.joined(pieces, separator: .comma).string == "a, b")
    }

    @Test("Joining is verbatim: a piece that ends in a newline keeps it")
    func joinsPiecesThatEndInNewlines() {
        // `joined` inserts exactly `separator.text` and nothing else — it must
        // not try to be clever about pieces that end in a break. Keeping the
        // pieces clean is `attributed`'s job (it drops the newline AppKit's
        // HTML importer appends); this pins the other half of that contract:
        // whatever arrives here is joined verbatim, so a piece that genuinely
        // ends in a newline keeps it and the separator still lands right
        // after.
        let pieces = ["a\n", "b\n"].map { NSAttributedString(string: $0) }
        #expect(MultiPaste.joined(pieces, separator: .comma).string == "a\n, b\n")
        #expect(MultiPaste.joined(pieces, separator: .newline).string == "a\n\nb\n")
    }

    @Test("One piece comes back untouched, zero pieces come back empty")
    func degenerateCases() {
        let single = [NSAttributedString(string: "only")]
        #expect(MultiPaste.joined(single, separator: .blankLine).string == "only")
        #expect(MultiPaste.joined([], separator: .newline).string == "")
    }

    @Test("Each separator produces its own text")
    func everySeparator() {
        let pieces = ["a", "b"].map { NSAttributedString(string: $0) }
        #expect(MultiPaste.joined(pieces, separator: .newline).string == "a\nb")
        #expect(MultiPaste.joined(pieces, separator: .blankLine).string == "a\n\nb")
        #expect(MultiPaste.joined(pieces, separator: .space).string == "a b")
        #expect(MultiPaste.joined(pieces, separator: .comma).string == "a, b")
    }

    @Test("The separator carries no attributes of its own")
    func separatorIsUnstyled() {
        // Inheriting the previous piece's attributes would make the break
        // carry the font and colour of the text above it, so the block would
        // change appearance depending on the order things were marked.
        // Both sides styled, and differently: with only the leading piece
        // styled, the separator inheriting from the piece *after* it would go
        // unnoticed.
        let leading = NSAttributedString(string: "a",
                                         attributes: [.foregroundColor: NSColor.red])
        let trailing = NSAttributedString(string: "b",
                                          attributes: [.foregroundColor: NSColor.blue])
        let joined = MultiPaste.joined([leading, trailing], separator: .newline)
        var range = NSRange(location: 0, length: 0)
        #expect(joined.attributes(at: 1, effectiveRange: &range)[.foregroundColor] == nil)
        // And the pieces themselves keep what they came with.
        #expect(joined.attributes(at: 0, effectiveRange: &range)[.foregroundColor] as? NSColor == .red)
        #expect(joined.attributes(at: 2, effectiveRange: &range)[.foregroundColor] as? NSColor == .blue)
    }
}
