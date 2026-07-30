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
        close()

        let root = ItemEditorView(item: item, initialFocus: focus) { [weak self] in
            self?.close()
        }
        .modelContainer(modelContainer)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = item.label ?? "Edit Item"
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
