//
//  ItemPreviewPanel.swift
//  MyPasteApp
//
//  The floating panel that shows the full contents of the selected item.
//  Started as a disposable Task 19 spike to answer one question — can a
//  second floating window coexist with the overlay without stealing its
//  keyboard focus or being read as a "click outside" by
//  OverlayWindowController.installClickOutsideMonitors()? Confirmed by hand:
//  the panel opens with the overlay staying open, the arrow keys keep
//  navigating cards, clicking inside the panel closes nothing, and clicking
//  outside both closes both. This file is now that panel's shell — the real
//  content is ItemPreviewView, and OverlayWindowController owns showing it,
//  keeping it positioned, and keeping it in sync with the overlay's
//  selection.
//

import AppKit
import SwiftUI

enum ItemPreviewPanel {
    static let defaultSize = NSSize(width: 520, height: 380)

    /// Builds the panel shell. `contentView` is left unset on purpose:
    /// `OverlayWindowController.applyPreviewContent(to:item:)` is the only
    /// place that builds the `NSHostingView` and assigns it, so the rule
    /// below only has to be followed in one spot instead of two.
    static func make() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: defaultSize),
            // Not .borderless: unlike the overlay, this panel doesn't need to
            // become key — the overlay keeps the keyboard. See
            // OverlayWindowController.installClickOutsideMonitors().
            // .fullSizeContentView lets ItemPreviewView's own header sit at
            // the very top in place of a native titlebar — see below.
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
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
        // hide(). ItemPreviewView has nothing that needs keyboard input (its
        // close button is clicked, not typed to), so becomesKeyOnlyIfNeeded
        // tells AppKit a plain click has no reason to hand this panel key
        // status at all — confirmed by hand in the Task 19 spike.
        panel.becomesKeyOnlyIfNeeded = true
        // ItemPreviewView draws its own header (close button, type label,
        // footnote) — a native titlebar on top of that would just duplicate
        // it, so it's hidden. Purely cosmetic: none of this touches the
        // key/activation behaviour validated above.
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        return panel
    }
}
