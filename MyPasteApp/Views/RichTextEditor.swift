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
            apply(command, to: textView)
            // Cleared asynchronously: mutating state during a view update is
            // what SwiftUI's "Modifying state during view update" warning is
            // about.
            DispatchQueue.main.async { self.command = nil }
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

        switch command {
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
        attributedText = updated
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
