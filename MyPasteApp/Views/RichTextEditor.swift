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
        // Only push back when the model actually diverged. Rewriting the
        // storage on every SwiftUI update would reset the insertion point to
        // the start of the document on each keystroke.
        guard textView.textStorage?.isEqual(to: attributedText) == false else { return }
        textView.textStorage?.setAttributedString(attributedText)
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
