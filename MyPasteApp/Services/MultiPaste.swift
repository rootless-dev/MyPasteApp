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
    ///
    /// The two branches treat a trailing newline differently **on purpose** —
    /// do not "unify" them:
    ///
    /// * The decoded branch drops one. AppKit's HTML importer terminates
    ///   block-level content with a newline the source never had:
    ///   `<p>Hello world</p>` imports as `"Hello world\n"`, and
    ///   `<ul><li>one</li><li>two</li></ul>` as `"\t•\tone\n\t•\ttwo\n"`
    ///   (measured, not assumed). Left in place, `joined` inserts the
    ///   separator *after* that break — a comma alone on its own line, a
    ///   stray leading space, or a blank line between every pair.
    /// * The plain fallback keeps it. There, a trailing newline is content the
    ///   user actually copied, and dropping it would silently alter the
    ///   capture.
    @MainActor
    static func attributed(for item: ClipboardItem) -> NSAttributedString {
        let plain = item.textContent ?? ""
        guard let data = item.richTextData,
              let format = item.richTextFormat,
              let decoded = RichText.decode(data: data, format: format)
        else { return NSAttributedString(string: plain) }
        return droppingOneTrailingNewline(decoded)
    }

    /// Removes a single trailing newline, if there is one.
    ///
    /// "At most one": two trailing newlines in a decoded capture mean the
    /// source really had a blank line at the end, and only the importer's own
    /// terminator is an artefact. The empty case returns early so the delete
    /// below can never be handed an out-of-range location, and the range comes
    /// from `rangeOfComposedCharacterSequence` so a CRLF ending goes as one
    /// unit instead of leaving a bare `\r` behind.
    private static func droppingOneTrailingNewline(
        _ text: NSAttributedString
    ) -> NSAttributedString {
        guard text.length > 0, text.string.hasSuffix("\n") else { return text }
        let last = (text.string as NSString)
            .rangeOfComposedCharacterSequence(at: text.length - 1)
        let trimmed = NSMutableAttributedString(attributedString: text)
        trimmed.deleteCharacters(in: last)
        return trimmed
    }

    /// The plain-text block: every item's captured `textContent`, verbatim.
    ///
    /// Deliberately does **not** go through `attributed`. `textContent` and
    /// `richTextData` are two independent representations captured side by
    /// side, and for an HTML source they routinely disagree — rendering the
    /// rich one and taking its `.string` would hand over `"\t•\tone"` for a
    /// bullet whose plain capture was just `"one"`, which is not what ⇧↵ on
    /// that same item alone produces. Every other plain-paste path in the app
    /// writes `textContent` verbatim; so does this one. Skipping the render
    /// also avoids paying for a full HTML import per item just to discard it.
    @MainActor
    static func plainJoined(_ items: [ClipboardItem],
                            separator: MultiPasteSeparator) -> String {
        items.map { $0.textContent ?? "" }.joined(separator: separator.text)
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
