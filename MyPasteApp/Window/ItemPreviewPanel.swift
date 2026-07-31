//
//  ItemPreviewPanel.swift
//  MyPasteApp
//
//  Task 19 spike scaffolding — NOT the real preview panel (that's Task 20).
//
//  The only question this file exists to help answer: can a second floating
//  window coexist with the overlay without stealing its keyboard focus and
//  without being read as a "click outside" by
//  OverlayWindowController.installClickOutsideMonitors()? So the panel here
//  is deliberately bare: no real content, no chrome beyond what's needed to
//  open and close it by hand. If the spike succeeds this file is replaced by
//  the real preview panel; if it fails, it's deleted along with the wiring
//  in OverlayWindowController.
//

import AppKit
import SwiftUI

enum ItemPreviewPanel {
    static let defaultSize = NSSize(width: 520, height: 380)

    /// Builds the minimal panel described in the Task 19 brief.
    static func make() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: defaultSize),
            // Not .borderless: unlike the overlay, this panel doesn't need to
            // become key — the overlay keeps the keyboard. See
            // OverlayWindowController.installClickOutsideMonitors().
            styleMask: [.nonactivatingPanel, .titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        // Above the overlay, which is already .floating.
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.sharingType = WindowPrivacy.sharingType()
        // .nonactivatingPanel only keeps a click here from activating the
        // app — by itself it does NOT stop the panel from becoming key, and
        // a panel that becomes key sends windowDidResignKey to whichever
        // panel was key before it (the overlay), which is wired to call
        // hide(). Since this content is a static Text with nothing that
        // needs keyboard input, becomesKeyOnlyIfNeeded tells AppKit a plain
        // click has no reason to hand this panel key status at all, so the
        // overlay should keep it. Unconfirmed without running the app — see
        // the Task 19 report.
        panel.becomesKeyOnlyIfNeeded = true
        panel.title = "Preview spike"
        // Give the hosting view an explicit frame and autoresizing mask, the
        // same way OverlayWindowController.prepare() does. Handing NSHostingView
        // straight to contentView lets it drive the window from its content's
        // intrinsic size instead — which shrank this panel to the width of the
        // Text, ignoring the 520x380 setFrame applied moments earlier.
        let host = NSHostingView(rootView: Text("preview spike"))
        host.frame = NSRect(origin: .zero, size: defaultSize)
        host.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
        panel.contentView = host
        return panel
    }
}
