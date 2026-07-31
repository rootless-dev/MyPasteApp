//
//  TextPreviewView.swift
//  MyPasteApp
//

import AppKit
import SwiftUI

/// Read-only text, scrollable, for the preview panel.
///
/// Not `ScrollView { Text(...) }`: SwiftUI lays out and rasterizes the *whole*
/// string, not just the visible part. Core Animation can't back a layer that
/// tall, so it splits it into tiles — a long clipboard item measured 240 MB of
/// CoreAnimation across eight of them, for a panel showing 380 points at a
/// time. See docs/superpowers/specs/2026-07-31-fase-2-5-memoria-design.md.
///
/// `NSTextView` has come up in TextKit 2 since macOS 12, which lays out by
/// viewport: only what's on screen is rasterized, so the cost stops depending
/// on the document's length.
///
/// IMPORTANT: never touch `textView.layoutManager` here. Reading that property
/// drops the view back to TextKit 1, which lays out the entire document and
/// reintroduces exactly the bug this file exists to fix. Content goes in
/// through `textView.string`; `textView.textLayoutManager != nil` is how you
/// check which engine is live.
struct TextPreviewView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }
        textView.isEditable = false
        // Keeps the selection the previous `.textSelection(.enabled)` gave.
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 13)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.string = text
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // Only rewrite when the model actually diverged: reassigning on every
        // SwiftUI update would throw away the scroll position and whatever the
        // user had selected. Same guard RichTextEditor uses.
        guard textView.string != text else { return }
        textView.string = text
    }
}
