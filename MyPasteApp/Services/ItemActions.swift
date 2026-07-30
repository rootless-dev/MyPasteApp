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

    init(modelContext: ModelContext,
         writer: ClipboardWriter,
         onPaste: @escaping (ClipboardItem, Bool) -> Void) {
        self.modelContext = modelContext
        self.writer = writer
        self.onPaste = onPaste
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
}
