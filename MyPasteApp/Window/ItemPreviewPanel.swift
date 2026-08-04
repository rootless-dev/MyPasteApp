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
//  content is ItemPreviewView, and PreviewPanelController owns showing it,
//  keeping it positioned, and keeping it in sync with the overlay's
//  selection.
//

import AppKit
import SwiftUI

enum ItemPreviewPanel {
    /// What the content area measures — the panel's SwiftUI body, and
    /// nothing else. Kept separate from `windowSize` because
    /// `ItemPreviewView` also hands this to `ImageThumbnailCache.pixels(for:)`
    /// to size decoded thumbnails; folding the beak into it would silently
    /// change decode resolution for every image the preview shows.
    static let contentSize = NSSize(width: 520, height: 380)
    static let beakHeight: CGFloat = 12
    static let cornerRadius: CGFloat = 12
    /// What the window itself measures — `contentSize` plus the strip the
    /// beak occupies below it. Everything that sizes or positions the
    /// `NSPanel` uses this; everything that measures content uses
    /// `contentSize`.
    static var windowSize: NSSize {
        NSSize(width: contentSize.width, height: contentSize.height + beakHeight)
    }

    /// Builds the panel shell. `contentView` is left unset on purpose:
    /// `PreviewPanelController.applyPreviewContent(to:item:)` is the only
    /// place that builds the `NSHostingView` and assigns it, so the rule
    /// below only has to be followed in one spot instead of two.
    static func make() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: windowSize),
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
        // The window itself draws nothing — PreviewPanelShape, filled in
        // ItemPreviewView's background, is the only thing visible. Without
        // this, .titled's own opaque background and corner mask would sit
        // behind (and inside) the beak, defeating the point of drawing it.
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // The system shadow follows the window's rectangle, not the shape
        // drawn inside it — left on, it would draw a rectangular shadow
        // around the transparent margin next to the beak. ItemPreviewView's
        // .shadow on PreviewPanelShape itself replaces it.
        panel.hasShadow = false
        // .nonactivatingPanel only keeps a click here from activating the
        // app — by itself it does NOT stop the panel from becoming key, and
        // a panel that becomes key sends windowDidResignKey to whichever
        // panel was key before it (the overlay), which is wired to call
        // hide(). ItemPreviewView now hosts an NSTextView (TextPreviewView,
        // added in Phase 2.5), but it's `isEditable = false`, so AppKit still
        // has no reason to hand this panel key status for a plain click —
        // `needsPanelToBecomeKey` stays false, same as when the only content
        // was a clicked-not-typed-to close button. becomesKeyOnlyIfNeeded
        // relies on that to keep click-dragging a text selection from
        // stealing key status (and with it, closing the overlay) — confirmed
        // by hand in the Task 19 spike and rechecked in Phase 2.5.
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
