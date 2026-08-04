//
//  DragPayload.swift
//  MyPasteApp
//

import AppKit
import Foundation

/// What dragging a card hands over.
///
/// Pure and free-standing: deciding *what* to give is separable from the
/// AppKit machinery that gives it (`DragItemProvider`), and only this half can
/// be tested.
enum DragPayload {

    /// A rich representation carried alongside the plain text — RTF or HTML,
    /// whichever the source actually offered. Never assume one: a browser
    /// copy that never put RTF on the pasteboard falls back to HTML (see
    /// `RichText.preferredFormat`), and the drag has to be able to carry that
    /// too or it silently loses formatting that ⌘V would have delivered.
    struct FormattedText: Equatable {
        let format: RichTextFormat
        let data: Data
    }

    enum Kind: Equatable {
        /// Plain text, plus the formatted flavour when the item has one.
        case text(String, formatted: FormattedText?)
        case files([URL])
        case image(png: Data, fileName: String)
        /// Nothing worth dragging — an image with no data, or a file item
        /// whose paths are all gone.
        case none
    }

    static func kind(for item: ClipboardItem,
                     fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) })
    -> Kind {
        switch item.type {
        case .text, .url:
            guard let text = item.textContent else { return .none }
            // The same payload the paste path builds — dragging and pasting
            // can't disagree about what the item's content is. Pick out
            // whichever entry isn't the plain-text one, whatever format that
            // turned out to be; never hardcode a single format here.
            let formatted = RichText.payload(text: text,
                                             richTextData: item.richTextData,
                                             format: item.richTextFormat,
                                             plainOnly: false)
                .first { $0.type != .string }
                .flatMap { entry -> FormattedText? in
                    guard let format = richTextFormat(for: entry.type) else { return nil }
                    return FormattedText(format: format, data: entry.data)
                }
            return .text(text, formatted: formatted)

        case .file:
            let existing = (item.fileURLStrings ?? [])
                .filter(fileExists)
                .map { URL(fileURLWithPath: $0) }
            return existing.isEmpty ? .none : .files(existing)

        case .image:
            guard let data = item.imageData else { return .none }
            return .image(png: data,
                          fileName: imageFileName(label: item.label, date: item.createdAt))
        }
    }

    /// A file name a destination will accept.
    ///
    /// The Finder rejects a promised file whose name it can't use, and the
    /// failure looks like "the drag didn't work" with nothing explaining why —
    /// which is the exact failure the roadmap item exists to avoid.
    ///
    /// - Parameter timeZone: the zone the fallback timestamp is rendered in.
    ///   Defaults to the device's own — the name follows the user's clock, so
    ///   someone who drags a file at 8pm sees 8pm in the name, not an hour
    ///   shifted by however far their zone sits from UTC. Injected only so a
    ///   test can pin a zone and get a deterministic string; production code
    ///   never passes anything but the default.
    static func imageFileName(label: String?, date: Date, timeZone: TimeZone = .current) -> String {
        let cleaned = (label ?? "")
            .components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>"))
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: " -\t\n"))

        let base: String
        if cleaned.isEmpty {
            base = "Image " + Self.stamp(timeZone: timeZone).string(from: date)
        } else {
            base = String(cleaned.prefix(60))
        }
        return base + ".png"
    }

    /// Maps a pasteboard type back to the `RichTextFormat` it came from.
    ///
    /// The reverse of `RichTextFormat.pasteboardType`, kept private and
    /// narrow: `RichText.payload` is the only source of the types this ever
    /// sees, so there is no case here for anything else.
    private static func richTextFormat(for type: NSPasteboard.PasteboardType) -> RichTextFormat? {
        switch type {
        case .rtf:  return .rtf
        case .html: return .html
        default:    return nil
        }
    }

    /// Colons are illegal in file names, so the time uses dashes.
    ///
    /// Locale and calendar are pinned: a file name must not depend on the
    /// user's calendar. Left unpinned, a device set to a non-Gregorian
    /// calendar (Thai Buddhist, Japanese era) would emit that calendar's
    /// year — e.g. "Image 2569-...png" — with nothing explaining why.
    ///
    /// Built fresh per call rather than cached: a `DateFormatter` mutated in
    /// place isn't safe to share if this is ever called off the main actor,
    /// and a fallback name is rare enough that building one is not hot.
    private static func stamp(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        return formatter
    }
}
