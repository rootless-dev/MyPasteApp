//
//  MultiPaste.swift
//  MyPasteApp
//
//  The rules behind pasting several items as one block: which types qualify,
//  which marked ids still have an item, and how the pieces are joined.
//
//  Everything that doesn't touch a `ClipboardItem` or AppKit is left without
//  actor isolation, which is what keeps the bulk of this testable without a
//  view — the same shape as `ItemSearch` and `RichText`.
//

import AppKit
import Foundation
import SwiftData

enum MultiPaste {
    /// The types that can go into a block. Same gate `⌘E` uses to decide what
    /// is editable as text.
    static func isMarkable(_ type: ClipboardItemType) -> Bool {
        type == .text || type == .url
    }

    /// Resolves marked ids against the current list, **in the order marked**.
    ///
    /// Ids with no matching item are dropped silently: that's how an item
    /// deleted while marked leaves the block without any reactive cleanup in
    /// `MarkedSelection`. Indexes `items` once instead of scanning it per id.
    static func resolve(ids: [UUID], in items: [ClipboardItem]) -> [ClipboardItem] {
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }
    }

    /// Joins the pieces, with an unstyled separator between them.
    ///
    /// The separator deliberately carries no attributes: inheriting the
    /// previous piece's would make the break take on the font and colour of
    /// the text above it, and the block would look different depending on the
    /// order things were marked in.
    static func joined(_ pieces: [NSAttributedString],
                       separator: MultiPasteSeparator) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, piece) in pieces.enumerated() {
            if index > 0 { result.append(NSAttributedString(string: separator.text)) }
            result.append(piece)
        }
        return result
    }

    /// The rich representation of an item, ready to go into a block.
    ///
    /// Dispatches on the stored `richTextFormat` and **never guesses**:
    /// decoding an HTML-only capture as RTF returns nil in silence, which is
    /// how Phase 2 lost formatting in the editor. A decode failure falls back
    /// to the plain text — never to empty, which would drop the item out of
    /// the block with nothing to show for it.
    ///
    /// Main-actor bound because AppKit's HTML importer requires it, which
    /// `RichText.decode` documents.
    @MainActor
    static func attributed(for item: ClipboardItem) -> NSAttributedString {
        let plain = item.textContent ?? ""
        guard let data = item.richTextData,
              let format = item.richTextFormat,
              let decoded = RichText.decode(data: data, format: format)
        else { return NSAttributedString(string: plain) }
        return decoded
    }

    /// Records that these items were used, **without promoting them**.
    ///
    /// This is the one paste path in the app that doesn't rewrite `createdAt`.
    /// Doing so for N items at once would throw the whole block to the front
    /// of the history and shift the ⌘1–⌘9 numbering along with it. `lastUsedAt`
    /// exists to record use without touching order — see the note at the top
    /// of ROADMAP.md about the two fields.
    ///
    /// Takes `now` rather than reading the clock so the rule can be tested
    /// against a fixed instant.
    @MainActor
    static func markUsed(_ items: [ClipboardItem], now: Date) {
        guard !items.isEmpty else { return }
        for item in items { item.lastUsedAt = now }
        try? items.first?.modelContext?.save()
    }
}
