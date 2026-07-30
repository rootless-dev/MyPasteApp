//
//  ItemEditorWindowController.swift
//  MyPasteApp
//

import AppKit
import SwiftData
import SwiftUI

/// The editor window.
///
/// A real titled window rather than something inside the overlay: the overlay
/// is `.transient` and hides on click-outside and on losing focus, none of
/// which survives an editing session.
@MainActor
final class ItemEditorWindowController: NSObject {
    private var window: NSWindow?
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        super.init()
    }

    func open(item: ClipboardItem, focus: ItemEditorFocus) {
        show(mode: .existing(item), focus: focus, title: item.label ?? "Edit Item")
    }

    /// Opens the editor with no item loaded, to write one from scratch.
    ///
    /// The `ClipboardItem` doesn't exist yet — `ItemEditorView.save()` only
    /// creates it (via `ItemActions.makeManualItem`) when Save runs, so
    /// cancelling leaves no trace in the history.
    func openForNewItem() {
        show(mode: .new, focus: .body, title: "New Item")
    }

    private func show(mode: ItemEditorMode, focus: ItemEditorFocus, title: String) {
        close()

        let root = ItemEditorView(mode: mode, initialFocus: focus) { [weak self] in
            self?.close()
        }
        .modelContainer(modelContainer)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentView = NSHostingView(rootView: root)
        window.center()
        window.isReleasedWhenClosed = false
        // The editor shows the item's contents, which is exactly the data the
        // screen-sharing preference exists to protect.
        window.sharingType = WindowPrivacy.sharingType()

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    func close() {
        window?.orderOut(nil)
        window = nil
    }
}
