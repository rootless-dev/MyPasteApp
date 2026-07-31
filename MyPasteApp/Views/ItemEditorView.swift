//
//  ItemEditorView.swift
//  MyPasteApp
//

import AppKit
import SwiftData
import SwiftUI

/// Which field the editor starts focused on.
///
/// One window serves ⌘E, ⌘R and ⌘N; only the initial focus differs. A separate
/// rename screen would duplicate the same form to move one focus ring.
enum ItemEditorFocus {
    case body
    case label
}

/// What the editor is working on.
///
/// `.new` has no `ClipboardItem` yet — see `ItemEditorView.save()`. Creating
/// one up front (e.g. at window-open time) would leave an empty, pinned item
/// in the history the instant the user hits Cancel; building it only on Save
/// makes Cancel mean "nothing happened", same as for an existing item.
enum ItemEditorMode {
    case existing(ClipboardItem)
    case new
}

struct ItemEditorView: View {
    let mode: ItemEditorMode
    let initialFocus: ItemEditorFocus
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage(PreferenceKeys.previewTextLength) private var previewTextLength: Int = 200
    @State private var attributed: NSAttributedString
    @State private var label: String
    @FocusState private var labelFocused: Bool

    init(mode: ItemEditorMode,
         initialFocus: ItemEditorFocus,
         onClose: @escaping () -> Void) {
        self.mode = mode
        self.initialFocus = initialFocus
        self.onClose = onClose
        switch mode {
        case .existing(let item):
            // Prefer the stored formatting; fall back to the plain text for
            // an item captured before rich text existed, or written by hand.
            // Decoding goes through `RichText.decode`, keyed on
            // `richTextFormat` — trying RTF unconditionally would silently
            // fail on an HTML-only capture and fall through to plain text,
            // and Save would then persist that loss. See RichText.decode.
            let initial: NSAttributedString
            if let data = item.richTextData,
               let format = item.richTextFormat,
               let restored = RichText.decode(data: data, format: format) {
                initial = restored
            } else {
                initial = NSAttributedString(string: item.textContent ?? "")
            }
            _attributed = State(initialValue: initial)
            _label = State(initialValue: item.label ?? "")
        case .new:
            _attributed = State(initialValue: NSAttributedString(string: ""))
            _label = State(initialValue: "")
        }
    }

    /// Whether this item has an editable text body.
    ///
    /// Image and file items have no body to show here — see
    /// `ItemEdit.applyLabel`. A brand-new item is always text or url (see
    /// `ItemActions.makeManualItem`), so it always has one.
    private var hasEditableBody: Bool {
        switch mode {
        case .existing(let item):
            return item.type == .text || item.type == .url
        case .new:
            return true
        }
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
        switch mode {
        case .existing(let item):
            if hasEditableBody {
                ItemEdit.apply(to: item,
                               attributed: attributed,
                               label: label,
                               previewLength: previewTextLength)
            } else {
                ItemEdit.applyLabel(to: item, label: label)
            }
        case .new:
            // An empty body plus an empty label is nothing worth keeping —
            // treated the same as Cancel rather than creating a blank,
            // permanently-pinned item.
            let plain = attributed.string
            let trimmedBody = plain.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedBody.isEmpty || !trimmedLabel.isEmpty else {
                onClose()
                return
            }
            let item = ItemActions.makeManualItem(text: plain)
            modelContext.insert(item)
            ItemEdit.apply(to: item,
                           attributed: attributed,
                           label: label,
                           previewLength: previewTextLength)
        }
        onClose()
    }
}
