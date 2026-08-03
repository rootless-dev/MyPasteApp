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
    private let onPreview: (ClipboardItem) -> Void
    private let onJump: (ClipboardItem) -> Void

    init(modelContext: ModelContext,
         writer: ClipboardWriter,
         onPaste: @escaping (ClipboardItem, Bool) -> Void,
         editorWindow: ItemEditorWindowController,
         onPreview: @escaping (ClipboardItem) -> Void = { _ in },
         onJump: @escaping (ClipboardItem) -> Void = { _ in }) {
        self.modelContext = modelContext
        self.writer = writer
        self.onPaste = onPaste
        self.editorWindow = editorWindow
        self.onPreview = onPreview
        self.onJump = onJump
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

    /// Opens the item editor window, focused on the label field.
    ///
    /// Unlike `edit`, this applies to every type: an image or a file benefits
    /// from a name just as much as a piece of text does.
    func rename(_ item: ClipboardItem) {
        editorWindow.open(item: item, focus: .label)
    }

    /// Opens the item editor with nothing loaded, to write an item from
    /// scratch.
    ///
    /// No `ClipboardItem` exists yet at this point — `ItemEditorView` only
    /// calls `makeManualItem(text:)` and inserts the result when its Save
    /// button runs. Dismissing the editor without saving is "nothing
    /// happened": no half-written item is left behind in the history.
    func newItem() {
        editorWindow.openForNewItem()
    }

    /// Opens the item in the preview panel — the "Preview" context menu
    /// entry, mirroring Finder's Quick Look (␣) convention.
    ///
    /// Just forwards to whatever `OverlayWindowController` wired in: the
    /// panel itself is an imperative `NSPanel` this class has no reference
    /// to, so it can't open it directly. See `OverlayView.preview(_:)` for
    /// why the selection is updated synchronously before this fires.
    func preview(_ item: ClipboardItem) {
        onPreview(item)
    }

    /// Clears the search and reveals the item in the full history.
    ///
    /// Forwarded like `preview`: clearing the query and moving the selection
    /// are view state, which this type has no business holding.
    func jumpToHistory(_ item: ClipboardItem) {
        onJump(item)
    }
}

/// Builds an item the user wrote by hand.
///
/// Born with `keepForever` rather than `isPinned`: hand-written items should
/// survive the pruner — that was always the intent — but pinning also sorts
/// them to the front of the history, which nobody asked for. Roadmap item 17
/// gave the app the field that says exactly what was meant.
extension ItemActions {
    /// Resolves whether a paste should hand over plain text.
    ///
    /// Pure so the rule — "⇧ means plain, and the preference never inverts,
    /// only forces" — is a single, testable place instead of being copied at
    /// every call site. Shared by `OverlayView`'s click/`↵` paths and
    /// `ItemContextMenu`'s "Paste" entry. Quick paste (⌘1–⌘9) is the one path
    /// that never calls this: it discards ⇧ on purpose, for keyboard-layout
    /// reasons — see the comment at that call site in `OverlayView`.
    static func resolvePastePlainText(alwaysPlainText: Bool, shiftHeld: Bool) -> Bool {
        alwaysPlainText || shiftHeld
    }

    static func makeManualItem(text: String) -> ClipboardItem {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let isURL = URL(string: trimmed).map { $0.scheme != nil } ?? false
        return ClipboardItem(
            type: isURL ? .url : .text,
            preview: String(text.prefix(ClipboardMonitor.previewTextLength())),
            contentHash: ClipboardMonitor.hash(text),
            textContent: text,
            // This app really is where the item came from, which is also what
            // gives the card its colour and icon with no extra code.
            sourceAppBundleID: Bundle.main.bundleIdentifier,
            keepForever: true
        )
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

    /// Applies a label-only rename, for item types with no editable body
    /// (image, file).
    ///
    /// Renaming those must not go through `apply`: its `attributed` parameter
    /// would come from an editor bound to an empty string for these types, and
    /// writing that back would blank out `textContent`, `preview` and
    /// `contentHash` — the same fields that hold the actual image/file
    /// identity. See the type gate in `ItemEditorView`.
    static func applyLabel(to item: ClipboardItem, label: String?) {
        let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        item.label = (trimmed?.isEmpty ?? true) ? nil : trimmed

        item.createdAt = .now
        item.lastUsedAt = .now

        try? item.modelContext?.save()
    }
}
