//
//  ItemEditorView.swift
//  MyPasteApp
//

import AppKit
import SwiftUI

/// Which field the editor starts focused on.
///
/// One window serves ⌘E, ⌘R and ⌘N; only the initial focus differs. A separate
/// rename screen would duplicate the same form to move one focus ring.
enum ItemEditorFocus {
    case body
    case label
}

struct ItemEditorView: View {
    let item: ClipboardItem
    let initialFocus: ItemEditorFocus
    let onClose: () -> Void

    @AppStorage(PreferenceKeys.previewTextLength) private var previewTextLength: Int = 200
    @State private var attributed: NSAttributedString
    @State private var label: String
    @FocusState private var labelFocused: Bool

    init(item: ClipboardItem,
         initialFocus: ItemEditorFocus,
         onClose: @escaping () -> Void) {
        self.item = item
        self.initialFocus = initialFocus
        self.onClose = onClose
        // Prefer the stored formatting; fall back to the plain text for an
        // item captured before rich text existed, or written by hand.
        let initial: NSAttributedString
        if let data = item.richTextData,
           let restored = NSAttributedString(rtf: data, documentAttributes: nil) {
            initial = restored
        } else {
            initial = NSAttributedString(string: item.textContent ?? "")
        }
        _attributed = State(initialValue: initial)
        _label = State(initialValue: item.label ?? "")
    }

    /// Whether this item has an editable text body.
    ///
    /// Image and file items have no body to show here — see `ItemEdit.applyLabel`.
    private var hasEditableBody: Bool {
        item.type == .text || item.type == .url
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Label", text: $label)
                .textFieldStyle(.roundedBorder)
                .focused($labelFocused)
                .padding(12)

            if hasEditableBody {
                Divider()

                RichTextEditor(attributedText: $attributed)
                    .frame(minWidth: 480, minHeight: 280)
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { onClose() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .onAppear { labelFocused = (initialFocus == .label) }
    }

    private func save() {
        if hasEditableBody {
            ItemEdit.apply(to: item,
                           attributed: attributed,
                           label: label,
                           previewLength: previewTextLength)
        } else {
            ItemEdit.applyLabel(to: item, label: label)
        }
        onClose()
    }
}
