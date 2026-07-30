//
//  ItemActions.swift
//  MyPasteApp
//

import AppKit
import SwiftData

/// Everything that can be done to a single history item, with no interface
/// attached.
///
/// The context menu and the keyboard shortcuts are two callers of this same
/// set. Keeping the behaviour here is what stops the menu entry and the
/// shortcut from drifting apart as the roadmap adds more of both.
@MainActor
final class ItemActions {
    private let modelContext: ModelContext
    private let writer: ClipboardWriter
    private let onPaste: (ClipboardItem, Bool) -> Void
    private let editorWindow: ItemEditorWindowController

    init(modelContext: ModelContext,
         writer: ClipboardWriter,
         onPaste: @escaping (ClipboardItem, Bool) -> Void,
         editorWindow: ItemEditorWindowController) {
        self.modelContext = modelContext
        self.writer = writer
        self.onPaste = onPaste
        self.editorWindow = editorWindow
    }

    func paste(_ item: ClipboardItem, plainText: Bool) {
        item.lastUsedAt = .now
        try? modelContext.save()
        onPaste(item, plainText)
    }

    /// Puts the item on the pasteboard without simulating ⌘V.
    ///
    /// Goes through `ClipboardWriter` like pasting does, so it inherits both
    /// the `ignoreNextChange` that keeps the monitor from recapturing our own
    /// write, and the promotion to the top of the history. Copying counts as
    /// use, the same way pasting does.
    func copy(_ item: ClipboardItem, plainText: Bool = false) {
        writer.write(item, plainText: plainText)
    }

    func togglePin(_ item: ClipboardItem) {
        item.isPinned.toggle()
        try? modelContext.save()
    }

    func delete(_ item: ClipboardItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }

    /// Opens the item editor window, focused on the given field.
    ///
    /// Only text and URL items are editable this way — see
    /// `ItemContextMenu`'s gating of the "Edit" entry.
    func edit(_ item: ClipboardItem, focus: ItemEditorFocus = .body) {
        editorWindow.open(item: item, focus: focus)
    }
}

/// Applies an edit to an item, recomputing everything derived from its text.
///
/// Pure and free-standing so the recalculation is testable without a window:
/// each of these five fields, left stale, produces a different bug.
enum ItemEdit {
    static func apply(to item: ClipboardItem,
                      attributed: NSAttributedString,
                      label: String?,
                      previewLength: Int) {
        let plain = attributed.string

        item.textContent = plain
        // Derived from the plain text, never from the RTF — see the comment in
        // ClipboardMonitor.readCurrentItem.
        item.preview = String(plain.prefix(previewLength))
        item.contentHash = ClipboardMonitor.hash(plain)

        let range = NSRange(location: 0, length: attributed.length)
        item.richTextData = try? attributed.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        item.richTextFormat = item.richTextData == nil ? nil : .rtf

        let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        item.label = (trimmed?.isEmpty ?? true) ? nil : trimmed

        // Editing counts as use, the same way pasting does. `createdAt` is
        // already "last used" rather than "captured at" — see the note at the
        // top of ROADMAP.md.
        item.createdAt = .now
        item.lastUsedAt = .now

        try? item.modelContext?.save()
    }
}
