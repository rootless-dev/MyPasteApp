//
//  DragItemProvider.swift
//  MyPasteApp
//

import AppKit
import Foundation
import UniformTypeIdentifiers

/// Turns a `DragPayload.Kind` into the thing AppKit drags.
///
/// The image case registers a **lazy** file representation: nothing is written
/// until a destination actually asks for the file, so a drag the user abandons
/// costs nothing on disk. A `NSFilePromiseProvider` would let the file be born
/// directly in the destination folder, but it requires replacing SwiftUI's
/// `.onDrag` with an `NSView` of our own as the dragging source — see the
/// spec's decision table.
enum DragItemProvider {

    static func make(for item: ClipboardItem) -> NSItemProvider {
        let provider = NSItemProvider()

        switch DragPayload.kind(for: item) {
        case .text(let string, let formatted):
            if let formatted {
                provider.registerDataRepresentation(forTypeIdentifier: uti(for: formatted.format),
                                                    visibility: .all) { completion in
                    completion(formatted.data, nil)
                    return nil
                }
            }
            provider.registerDataRepresentation(forTypeIdentifier: UTType.utf8PlainText.identifier,
                                                visibility: .all) { completion in
                completion(Data(string.utf8), nil)
                return nil
            }

        case .files(let urls):
            // File URLs the system already knows how to hand over — no copy,
            // no temporary, nothing to clean up.
            for url in urls {
                provider.registerFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier,
                                                    fileOptions: [.openInPlace],
                                                    visibility: .all) { completion in
                    completion(url, true, nil)
                    return nil
                }
            }

        case .image(let png, let fileName):
            provider.suggestedName = fileName
            provider.registerFileRepresentation(forTypeIdentifier: UTType.png.identifier,
                                                fileOptions: [],
                                                visibility: .all) { completion in
                do {
                    let url = try writeTemporary(png: png, fileName: fileName)
                    completion(url, false, nil)
                } catch {
                    completion(nil, false, error)
                }
                return nil
            }

        case .none:
            break
        }

        return provider
    }

    // MARK: - Format mapping

    /// The UTI identifier a drag registers a formatted text flavour under.
    ///
    /// Kept in one place, on purpose: `RichTextFormat` only ever grows a case
    /// when a source app hands us a rich representation we don't already
    /// carry, and the whole reason `DragPayload.Kind.text` stopped being
    /// RTF-only is that a hardcoded single format silently dropped whatever
    /// it didn't expect (see `DragPayload.swift`). Routing through a switch
    /// here — instead of a lookup table with a fallback — means a third
    /// format fails to compile instead of falling back to plain text.
    private static func uti(for format: RichTextFormat) -> String {
        switch format {
        case .rtf:  return UTType.rtf.identifier
        case .html: return UTType.html.identifier
        }
    }

    // MARK: - Temporaries

    private static var directory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("MyPasteApp-drags",
                                                                      isDirectory: true)
    }

    private static func writeTemporary(png: Data, fileName: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName)
        try png.write(to: url)
        return url
    }

    /// Deletes leftovers from earlier sessions. Called once at launch.
    static func cleanUpTemporaries(now: Date = .now) {
        let manager = FileManager.default
        guard let entries = try? manager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]) else { return }

        let dated: [(url: URL, modified: Date)] = entries.compactMap { url in
            guard let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate else { return nil }
            return (url, modified)
        }

        for url in TempFileCleanup.expired(dated, now: now) {
            try? manager.removeItem(at: url)
        }
    }
}
