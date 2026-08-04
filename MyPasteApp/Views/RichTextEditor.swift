//
//  RichTextEditor.swift
//  MyPasteApp
//

import AppKit
import SwiftUI

/// An `NSTextView` wrapped for SwiftUI, editing rich text.
///
/// Not `TextEditor`: that one is plain-text only, and the whole point here is
/// to stop destroying the formatting the app now captures. `NSTextView` also
/// brings ⌘B, ⌘I, the Format menu and macOS 15+ Writing Tools for free.
struct RichTextEditor: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString
    /// A command the toolbar asked for, consumed and cleared on arrival.
    ///
    /// The selection lives in the `NSTextView`, which SwiftUI can't reach —
    /// so the command travels down instead of the selection travelling up.
    @Binding var command: RichTextCommand?
    var isRichText: Bool = true

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }
        textView.delegate = context.coordinator
        textView.isRichText = isRichText
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 8, height: 8)
        if !isRichText {
            textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        }
        textView.textStorage?.setAttributedString(attributedText)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if let command {
            // The whole apply — reading the selection, computing the new
            // text, writing it back to storage, restoring the caret, and
            // publishing `attributedText` — happens inside this deferred
            // hop, not here. Doing any of it synchronously during this
            // view-update pass mutates `ItemEditorView`'s @State (the
            // "modifying state during a view update" hazard) and, worse,
            // lets a second command land and apply itself against the same
            // pre-mutation storage before this one's publish reaches
            // `attributedText` — corrupting one or both edits. Reading
            // `command.id` here is safe: it writes nothing.
            let id = command.id
            DispatchQueue.main.async { [weak textView] in
                // Act only if this is still the command that was scheduled.
                // A different command replacing it in the meantime means
                // that one now owns the apply-and-publish; running this one
                // anyway would either double-apply on top of the newer
                // command's edit or publish a stale snapshot over it. A
                // superseded hop just no-ops.
                guard self.command?.id == id, let textView else { return }
                self.apply(command, to: textView)
                self.command = nil
            }
            return
        }
        // Only push back when the model actually diverged. Rewriting the
        // storage on every SwiftUI update would reset the insertion point to
        // the start of the document on each keystroke.
        guard textView.textStorage?.isEqual(to: attributedText) == false else { return }
        textView.textStorage?.setAttributedString(attributedText)
    }

    private func apply(_ command: RichTextCommand, to textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let current = NSAttributedString(attributedString: storage)
        let range = textView.selectedRange()
        let updated: NSAttributedString

        switch command.kind {
        case .bold:          updated = RichText.toggling(.bold, in: current, range: range)
        case .italic:        updated = RichText.toggling(.italic, in: current, range: range)
        case .underline:     updated = RichText.togglingUnderline(in: current, range: range)
        case .strikethrough: updated = RichText.togglingStrikethrough(in: current, range: range)
        case .clear:
            updated = RichText.stripped(current,
                                        font: textView.font ?? .systemFont(ofSize: 13))
        }

        storage.setAttributedString(updated)
        textView.setSelectedRange(range)
        // Publish from the storage that was just written, not `updated` or
        // any other snapshot taken earlier: a value computed before this hop
        // ran can already be stale by the time it lands here — e.g. the user
        // typed a character while the hop was pending — and publishing it
        // would silently erase that edit. Storage is the source of truth at
        // the moment of publish.
        attributedText = NSAttributedString(attributedString: storage)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $attributedText)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let text: Binding<NSAttributedString>

        init(text: Binding<NSAttributedString>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let storage = textView.textStorage else { return }
            text.wrappedValue = NSAttributedString(attributedString: storage)
        }
    }
}
