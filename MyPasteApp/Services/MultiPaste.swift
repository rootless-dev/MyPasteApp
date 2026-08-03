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
}
