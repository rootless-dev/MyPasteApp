//
//  ClipboardWriter.swift
//  MyPasteApp
//

import AppKit
import Foundation
import SwiftData

@MainActor
final class ClipboardWriter {
    private weak var monitor: ClipboardMonitor?

    init(monitor: ClipboardMonitor) {
        self.monitor = monitor
    }

    /// Writes the item to the pasteboard.
    ///
    /// `plainText` drops any formatting for this paste only; the item keeps
    /// what it captured. The caller resolves it from the preference and the ⇧
    /// modifier together.
    func write(_ item: ClipboardItem, plainText: Bool = false) {
        let pb = NSPasteboard.general
        monitor?.ignoreNextChange = true
        pb.clearContents()

        item.createdAt = .now
        item.lastUsedAt = .now
        try? item.modelContext?.save()

        switch item.type {
        case .text, .url:
            guard let text = item.textContent else { break }
            for entry in RichText.payload(text: text,
                                          richTextData: item.richTextData,
                                          format: item.richTextFormat,
                                          plainOnly: plainText) {
                pb.setData(entry.data, forType: entry.type)
            }
        case .image:
            if let data = item.imageData, let img = NSImage(data: data) {
                pb.writeObjects([img])
            }
        case .file:
            if let strings = item.fileURLStrings {
                let urls = strings.map { URL(fileURLWithPath: $0) as NSURL }
                pb.writeObjects(urls)
            }
        }
    }

    /// Writes several items to the pasteboard as a single block.
    ///
    /// Deliberately **not** a parameter on `write(_:plainText:)`. The two
    /// diverge on exactly what they save: `write` promotes to the top by
    /// rewriting `createdAt`, this one doesn't touch `createdAt` at all. Phase
    /// 2 already paid once for folding two saves with different semantics into
    /// one routine — that was the near-miss corruption that split
    /// `ItemEdit.apply` from `ItemEdit.applyLabel`.
    ///
    /// `ignoreNextChange` still suffices: this is one write, not a loop. It's
    /// also why there's no `pasteDelayMs` between items — there's a single ⌘V.
    func writeJoined(_ items: [ClipboardItem],
                     separator: MultiPasteSeparator,
                     plainText: Bool) {
        guard !items.isEmpty else { return }

        // Everything the pasteboard will receive is computed here, *before*
        // `clearContents()` below: clearing first is only safe as long as
        // nothing in the computation can fail, and an RTF encode can.
        let plain: String
        let rtf: Data?
        if plainText {
            // `textContent`, never the rendered rich text — see
            // `MultiPaste.plainJoined`. ⇧↵ on a block has to hand over what
            // ⇧↵ on each of its items alone would.
            plain = MultiPaste.plainJoined(items, separator: separator)
            rtf = nil
        } else {
            // Closure rather than `items.map(MultiPaste.attributed(for:))`:
            // passing a `@MainActor` method as a function value drops the
            // global actor and fails to compile. A closure inherits the
            // isolation instead.
            let joined = MultiPaste.joined(items.map { MultiPaste.attributed(for: $0) },
                                           separator: separator)
            // The `.string` flavour of the rich block stays derived from the
            // joined attributed string on purpose: the two flavours on the
            // pasteboard have to describe the same content.
            plain = joined.string
            // Always RTF for the block, even when the sources were HTML: it's
            // the format `ItemEdit.apply` already writes, and it avoids having
            // to pick a winner between heterogeneous sources.
            rtf = try? joined.data(
                from: NSRange(location: 0, length: joined.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        }

        let pb = NSPasteboard.general
        monitor?.ignoreNextChange = true
        pb.clearContents()

        MultiPaste.markUsed(items, now: .now)

        if let rtf { pb.setData(rtf, forType: .rtf) }
        // Always present, even alongside RTF: a pasteboard carrying only RTF
        // breaks pasting into any plain text field. Same rule as
        // `RichText.payload`.
        pb.setData(Data(plain.utf8), forType: .string)
    }
}
