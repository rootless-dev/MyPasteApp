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

    enum Kind: Equatable {
        /// Plain text, plus the formatted flavour when the item has one.
        case text(String, rtf: Data?)
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
            // can't disagree about what the item's content is.
            let rtf = RichText.payload(text: text,
                                       richTextData: item.richTextData,
                                       format: item.richTextFormat,
                                       plainOnly: false)
                .first { $0.type == .rtf }?
                .data
            return .text(text, rtf: rtf)

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
    static func imageFileName(label: String?, date: Date) -> String {
        let cleaned = (label ?? "")
            .components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>"))
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: " -\t\n"))

        let base: String
        if cleaned.isEmpty {
            base = "Image " + Self.stamp.string(from: date)
        } else {
            base = String(cleaned.prefix(60))
        }
        return base + ".png"
    }

    /// Colons are illegal in file names, so the time uses dashes.
    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        return formatter
    }()
}
