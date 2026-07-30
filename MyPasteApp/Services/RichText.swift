//
//  RichText.swift
//  MyPasteApp
//
//  Decides which rich representation of a copied text to keep, and what to
//  hand back when pasting.
//
//  Both decisions are pure functions over types and stored data rather than
//  over an NSPasteboard, so they can be tested without touching the system
//  one — the same shape as `ClipboardMonitor.shouldCapture`.
//

import AppKit
import Foundation

enum RichTextFormat: String {
    case rtf
    case html

    var pasteboardType: NSPasteboard.PasteboardType {
        switch self {
        case .rtf:  return .rtf
        case .html: return .html
        }
    }
}

enum RichText {
    /// The best rich representation available among `types`, or nil when the
    /// pasteboard only carries plain text.
    ///
    /// RTF wins over HTML: `NSAttributedString` round-trips it without WebKit,
    /// whereas the HTML a browser puts on the pasteboard usually carries layout
    /// markup and external stylesheet references that paste back unpredictably.
    static func preferredFormat(in types: [NSPasteboard.PasteboardType]) -> RichTextFormat? {
        if types.contains(.rtf) { return .rtf }
        if types.contains(.html) { return .html }
        return nil
    }

    /// What to put on the pasteboard for a text item, in order of preference.
    ///
    /// Plain text is always included, even alongside a rich representation: a
    /// pasteboard carrying only RTF breaks pasting into any plain text field.
    /// The order matters — the first type declared is the one a destination
    /// app prefers.
    static func payload(text: String,
                        richTextData: Data?,
                        format: RichTextFormat?,
                        plainOnly: Bool) -> [(type: NSPasteboard.PasteboardType, data: Data)] {
        let plain = (type: NSPasteboard.PasteboardType.string, data: Data(text.utf8))
        guard !plainOnly, let richTextData, let format else { return [plain] }
        return [(type: format.pasteboardType, data: richTextData), plain]
    }
}
