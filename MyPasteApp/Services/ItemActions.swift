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

    /// Copies a recognised colour in the format the user picked, and files the
    /// converted string in the history.
    ///
    /// The item is built here and written **silently**, exactly like the
    /// screen sampler's own path in `AppDelegate.pickColorAction`. Letting the
    /// monitor pick the write up instead — which is what a non-silent write
    /// does — was wrong twice over: the monitor credits
    /// `NSWorkspace.frontmostApplication`, and the overlay is a
    /// `.nonactivatingPanel`, so converting a colour while Safari was in front
    /// filed an item wearing Safari's icon and header colour. Worse, with
    /// monitoring paused or an "ignore" rule on the frontmost app, the write
    /// was dropped entirely and no item was created at all, with nothing
    /// saying so.
    func copyColor(_ color: ColorCode, as format: ColorFormat) {
        let text = color.formatted(as: format)
        // Through the monitor's own rule, so converting the same colour twice
        // promotes one item rather than filing two identical ones.
        ClipboardMonitor.file(ItemActions.makeCapturedItem(text: text), in: modelContext)
        writer.writeText(text, silently: true)
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

    /// Opens an item in another application.
    ///
    /// Does nothing for an item with no openable target — the menu already
    /// won't offer it, and `⌘O` over such a card should be a no-op rather than
    /// an error nobody can act on.
    func open(_ item: ClipboardItem, with application: URL? = nil) {
        guard case .openable(let target) = OpenWith.target(for: item) else { return }
        OpenWith.open(target, with: application)
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

    /// Writes both retention fields at once.
    ///
    /// Static and free-standing because it needs nothing from an instance —
    /// and because writing the two fields together is the whole point: a
    /// caller that set only the one that changed is how the meaningless
    /// "keep forever **and** expires on Tuesday" state would be born. See
    /// `ItemRetention.fields`.
    static func setRetention(_ retention: ItemRetention, on item: ClipboardItem) {
        let fields = retention.fields
        item.keepForever = fields.keepForever
        item.expiresAt = fields.expiresAt
        try? item.modelContext?.save()
    }

    /// Files an item under a board, or lets it go with nil.
    ///
    /// Doesn't touch `createdAt` or `lastUsedAt`: filing something is not
    /// using it, and promoting it would reshuffle the history the user is
    /// looking at while they organise it.
    static func assign(_ item: ClipboardItem, to board: Pinboard?) {
        item.pinboard = board
        try? item.modelContext?.save()
    }

    /// Builds an item the app itself captured — today, a colour from the
    /// screen sampler.
    ///
    /// Separate from `makeManualItem` on one axis only: this one is **not**
    /// born `keepForever`. Something typed by hand exists nowhere else and
    /// deserves protection; a sampled colour can be sampled again, and
    /// protecting every sample would quietly grow the set the pruner may
    /// never touch.
    ///
    /// The app builds this itself rather than letting `ClipboardMonitor` pick
    /// the write up, because the monitor credits the frontmost application —
    /// and ours isn't frontmost when the system sampler closes. The item
    /// would be stamped with the icon and colour of whatever was underneath.
    static func makeCapturedItem(text: String) -> ClipboardItem {
        ClipboardItem(
            type: .text,
            preview: String(text.prefix(ClipboardMonitor.previewTextLength())),
            contentHash: ClipboardMonitor.hash(text),
            textContent: text,
            sourceAppBundleID: Bundle.main.bundleIdentifier
        )
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

/// Applies an edit to an image item, recomputing everything derived from its
/// bytes.
///
/// Recomputing `contentHash` is what makes the new bytes visible, and not only
/// to deduplication: the thumbnail cache key and `ThumbnailImage`'s `.task` id
/// both carry the hash (see `ImageThumbnailCache.key`), so a rewritten image
/// is a different key everywhere the moment this runs. There is deliberately
/// no explicit cache invalidation here — it used to be a call to
/// `ImageThumbnailCache.invalidate(id:)`, which could clear the cache but had
/// no way to reach the `@State` a long-lived card holds, so the card kept
/// drawing the un-rotated image regardless.
@MainActor
enum ImageEdit {
    static func apply(to item: ClipboardItem, imageData: Data) {
        item.imageData = imageData
        item.contentHash = ClipboardMonitor.hash(imageData)
        if let size = ImageMetadata.pixelSize(of: imageData) {
            // Same shape ClipboardMonitor writes on capture. Leaving it stale
            // would have the card describing dimensions the image no longer
            // has.
            item.preview = "Imagem \(Int(size.width))×\(Int(size.height))"
        }

        // Editing counts as use, exactly as it does for text — see
        // `ItemEdit.apply`.
        item.createdAt = .now
        item.lastUsedAt = .now

        try? item.modelContext?.save()
    }
}
