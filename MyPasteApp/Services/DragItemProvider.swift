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
            // Known limitation: only the first still-existing file drags.
            //
            // An `NSItemProvider` keeps at most one load handler per type
            // identifier. Registering `.fileURL` once per URL — one call per
            // loop iteration — doesn't add N handlers for N files; it adds N
            // competing handlers for the *same* flavour, and only the last
            // registration survives. A card built from 3 files copied
            // together used to drag to the Finder and drop only 1 file,
            // silently, because the loop looked correct.
            //
            // Carrying every file for real needs an AppKit dragging source
            // with a list of `NSDraggingItem`s — SwiftUI's `.onDrag` hands
            // back exactly one `NSItemProvider`, so there's no way to do it
            // from here. That's the same territory already ruled out of
            // scope for `NSFilePromiseProvider` (see the type doc above).
            // So: one registration, deliberately, for the first URL only —
            // not the loop this replaced.
            if let first = urls.first {
                provider.registerFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier,
                                                    fileOptions: [.openInPlace],
                                                    visibility: .all) { completion in
                    completion(first, true, nil)
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

    /// Writes into a fresh, UUID-named subdirectory per call rather than
    /// straight into `directory`.
    ///
    /// The previous version wrote to a path derived only from the sanitised
    /// file name, which is deterministic: dragging the same image card to
    /// app A, then again to app B before A finished reading, resolved both
    /// writes to the identical path. `Data.write(to:)` isn't atomic, so the
    /// second write could truncate the file mid-read by the first,
    /// delivering a corrupt or empty PNG to whichever destination read it
    /// first. A UUID subdirectory per call means two drags — even of the
    /// same card, even concurrent — never share a path, while the file
    /// inside still has the name the destination expects.
    private static func writeTemporary(png: Data, fileName: String) throws -> URL {
        let dragDirectory = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dragDirectory, withIntermediateDirectories: true)
        let url = dragDirectory.appendingPathComponent(fileName)
        try png.write(to: url)
        return url
    }

    /// Deletes leftovers from earlier sessions. Called once at launch.
    ///
    /// Each drag now writes into its own UUID subdirectory (see
    /// `writeTemporary`), so the immediate children of `directory` are
    /// directories, not files. `TempFileCleanup.expired` doesn't care either
    /// way — it only looks at a modification date per URL — and
    /// `removeItem(at:)` deletes a directory and its contents in one call,
    /// so no change was needed on either side of this method.
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
