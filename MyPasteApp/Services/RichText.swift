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

    /// Decodes stored rich text bytes back into an `NSAttributedString`,
    /// dispatching on `format` instead of guessing.
    ///
    /// `NSAttributedString(rtf:)` returns nil — silently, with no way to tell
    /// "corrupted bytes" apart from "wrong format" — when handed HTML data.
    /// Decoding without first checking `richTextFormat` (as `ItemEditorView`
    /// used to) turned an HTML-only capture into empty formatting the moment
    /// the editor opened, and Save then wrote that loss back over the
    /// original bytes. See `ItemEditorView.init`.
    ///
    /// Must run on the main thread: AppKit's HTML importer requires it.
    /// `ItemEditorView.init` already does, since SwiftUI builds the view
    /// there.
    static func decode(data: Data, format: RichTextFormat) -> NSAttributedString? {
        switch format {
        case .rtf:
            return NSAttributedString(rtf: data, documentAttributes: nil)
        case .html:
            return try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html],
                documentAttributes: nil
            )
        }
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

/// The formatting commands the editor's toolbar issues.
///
/// A value rather than a closure so `RichTextEditor` can take it as a binding:
/// SwiftUI has no handle on the `NSTextView` inside, and the view's own
/// coordinator is the only thing that knows the current selection.
///
/// A struct instead of a bare enum: each press needs its own identity, not
/// just its kind. Two presses can land before the same run-loop turn (a fast
/// double-click, or `⌘B` autorepeat) — the deferred hop in
/// `RichTextEditor.updateNSView` that applies a command checks `id` against
/// whatever is still parked in the binding to tell "this is still the
/// command I was scheduled for" from "something newer replaced me", which a
/// value that only carries `.bold`/`.italic`/... can't express.
struct RichTextCommand {
    enum Kind {
        case bold
        case italic
        case underline
        case strikethrough
        case clear
    }

    let kind: Kind
    let id = UUID()

    static var bold: RichTextCommand { RichTextCommand(kind: .bold) }
    static var italic: RichTextCommand { RichTextCommand(kind: .italic) }
    static var underline: RichTextCommand { RichTextCommand(kind: .underline) }
    static var strikethrough: RichTextCommand { RichTextCommand(kind: .strikethrough) }
    static var clear: RichTextCommand { RichTextCommand(kind: .clear) }
}

extension RichText {

    /// Adds or removes a font trait across a range.
    ///
    /// Applies uniformly: if any part of the range lacks the trait, the whole
    /// range gains it. Flipping each run independently would make one press on
    /// a half-bold selection leave it half-bold the other way round.
    static func toggling(_ trait: NSFontDescriptor.SymbolicTraits,
                         in attributed: NSAttributedString,
                         range: NSRange) -> NSAttributedString {
        guard range.length > 0 else { return attributed }
        let result = NSMutableAttributedString(attributedString: attributed)

        var everyRunHasIt = true
        result.enumerateAttribute(.font, in: range) { value, _, stop in
            let font = value as? NSFont
            if font?.fontDescriptor.symbolicTraits.contains(trait) != true {
                everyRunHasIt = false
                stop.pointee = true
            }
        }

        result.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let font = (value as? NSFont) ?? .systemFont(ofSize: NSFont.systemFontSize)
            var traits = font.fontDescriptor.symbolicTraits
            if everyRunHasIt { traits.remove(trait) } else { traits.insert(trait) }
            let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
            if let updated = NSFont(descriptor: descriptor, size: font.pointSize) {
                result.addAttribute(.font, value: updated, range: subrange)
            }
        }
        return result
    }

    static func togglingUnderline(in attributed: NSAttributedString,
                                  range: NSRange) -> NSAttributedString {
        toggling(attribute: .underlineStyle, in: attributed, range: range)
    }

    static func togglingStrikethrough(in attributed: NSAttributedString,
                                      range: NSRange) -> NSAttributedString {
        toggling(attribute: .strikethroughStyle, in: attributed, range: range)
    }

    /// Adds or removes an underline-style attribute (underline or
    /// strikethrough — both store an `NSUnderlineStyle` raw value) across a
    /// range.
    ///
    /// Applies uniformly, the same rule as `toggling(_:in:range:)`: if any run
    /// in the range lacks the style, the whole range gains it. Reading only
    /// the first character (as an earlier version of this did) would let a
    /// selection that starts underlined but isn't throughout *remove*
    /// underline from the whole range on one press — the opposite of the
    /// bold/italic rule.
    ///
    /// A run can carry the attribute with an explicit value of `0`
    /// (`NSUnderlineStyle.none`), which reads as "present" under a bare
    /// `attribute(_:at:effectiveRange:) != nil` check. `isPresent` treats
    /// that as absent instead, so such a run doesn't block the whole range
    /// from being seen as "not yet styled".
    private static func toggling(attribute key: NSAttributedString.Key,
                                 in attributed: NSAttributedString,
                                 range: NSRange) -> NSAttributedString {
        guard range.length > 0 else { return attributed }
        let result = NSMutableAttributedString(attributedString: attributed)

        func isPresent(_ value: Any?) -> Bool {
            guard let number = value as? NSNumber else { return false }
            return number.intValue != 0
        }

        var everyRunHasIt = true
        result.enumerateAttribute(key, in: range) { value, _, stop in
            if !isPresent(value) {
                everyRunHasIt = false
                stop.pointee = true
            }
        }

        if everyRunHasIt {
            result.removeAttribute(key, range: range)
        } else {
            result.addAttribute(key, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        return result
    }

    /// Drops every attribute, keeping the characters.
    ///
    /// The whole string, not the selection: "clear formatting" that left half
    /// the item styled would be a worse surprise than not offering it.
    ///
    /// Attachments go with the attributes. `attributed.string` renders every
    /// `NSTextAttachment` as U+FFFC (object replacement character), and the
    /// attachment itself lives in an attribute this drops — so keeping the
    /// placeholder left a visible `￼` glyph where an inline image used to be,
    /// which Save then wrote into `textContent` for search and pasting to
    /// carry around forever.
    static func stripped(_ attributed: NSAttributedString, font: NSFont) -> NSAttributedString {
        NSAttributedString(string: withoutAttachmentPlaceholders(attributed.string),
                           attributes: [.font: font])
    }

    /// A selection range made valid against a document of `length`.
    ///
    /// `stripped` can *shorten* the text — it deletes the U+FFFC placeholder
    /// of every attachment — so a selection captured before the edit may point
    /// past the end of what's left. Replaying it unclamped raises
    /// `NSRangeException`, and the caret sitting at the end of the document
    /// (`location == oldLength`) with a single inline image is enough to do
    /// it: an HTML capture turns every `<img>` into an `NSTextAttachment`,
    /// which is exactly the case "clear formatting" exists for.
    ///
    /// Collapses to the caret rather than guessing: a range whose start
    /// survived but whose end didn't keeps its start, and one that starts past
    /// the end lands at the end.
    static func clamped(_ range: NSRange, toLength length: Int) -> NSRange {
        let location = max(0, min(range.location, length))
        return NSRange(location: location,
                       length: max(0, min(range.length, length - location)))
    }

    /// `text` with every object-replacement character removed.
    ///
    /// Separate and internal so the rule is testable without building an
    /// `NSTextAttachment`, which needs a file wrapper or an image to be
    /// meaningful.
    static func withoutAttachmentPlaceholders(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{FFFC}", with: "")
    }

    /// Fills in `color` wherever `attributed` has no foreground colour of its
    /// own, leaving every run that already specifies one exactly as authored.
    ///
    /// Exists for panels that draw on a background the source text never
    /// anticipated. HTML captured from a web page routinely carries an
    /// explicit dark foreground meant for a white page; drawn unchanged on a
    /// dark preview background (`drawsBackground = false`) it's nearly
    /// invisible. Overwriting every run's colour would fix that case but
    /// flatten every other one — a deliberately red heading would come back
    /// the same colour as the body. Only the runs that never had an opinion
    /// get one.
    static func applyingDefaultForegroundColor(_ attributed: NSAttributedString,
                                                default color: NSColor) -> NSAttributedString {
        guard attributed.length > 0 else { return attributed }
        let result = NSMutableAttributedString(attributedString: attributed)
        let whole = NSRange(location: 0, length: result.length)
        result.enumerateAttribute(.foregroundColor, in: whole, options: []) { value, range, _ in
            guard value == nil else { return }
            result.addAttribute(.foregroundColor, value: color, range: range)
        }
        return result
    }
}
