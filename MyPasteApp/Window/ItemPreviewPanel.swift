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

/// The preview panel's window.
///
/// A subclass for one reason: once the panel is dragged off the drawer
/// (`PreviewPanelController.detachAnchored()`) it becomes a real key window
/// with nothing above it, and `⌘W` and `Escape` have to land *somewhere*.
/// Both are wired to `onCloseCommand`, which the controller sets at detach
/// time and leaves `nil` for as long as the panel is anchored — anchored, the
/// overlay owns the keyboard and this window never becomes key, so every
/// override below falls straight through to `super`.
///
/// Deliberately not a global event monitor: `OverlayWindowController`
/// already installs two, and a third competing for `Escape` is the bug class
/// Phase 5 documented with the drawer. Everything here rides the responder
/// chain of a window that is key, so it can only fire when this panel is the
/// one the user is looking at.
final class PreviewPanel: NSPanel {
    /// Set at detach; `nil` while anchored. Doubles as the "am I detached?"
    /// test for the overrides below, so they can't fire on the anchored panel
    /// even if something unexpected made it key.
    var onCloseCommand: (() -> Void)?

    /// `Escape`, path one: the first responder interpreted the key and sent
    /// `cancelOperation:` up the responder chain, which ends here. This is
    /// what happens when a text preview's `NSTextView` has the focus.
    override func cancelOperation(_ sender: Any?) {
        guard let onCloseCommand else { return super.cancelOperation(sender) }
        onCloseCommand()
    }

    /// `Escape`, path two: nothing in the chain interpreted the key, so no
    /// `cancelOperation:` was ever synthesised and the raw event walks up to
    /// the window instead. Which of the two paths fires depends on what
    /// happens to be first responder — an image preview and a text preview
    /// differ here — so both exist. Closing twice is harmless: the controller
    /// drops the panel from its list on the first call, and the second finds
    /// nothing to remove.
    override func keyDown(with event: NSEvent) {
        guard let onCloseCommand, event.keyCode == Self.escapeKeyCode else {
            return super.keyDown(with: event)
        }
        onCloseCommand()
    }

    /// `⌘W`, path one: the main menu's Close item targets `performClose:` on
    /// the key window. Overridden rather than left to AppKit because the
    /// default would `close()` the window without telling the controller,
    /// leaving a dead panel in its detached list.
    override func performClose(_ sender: Any?) {
        guard let onCloseCommand else { return super.performClose(sender) }
        onCloseCommand()
    }

    /// `⌘W`, path two: the app is `LSUIElement` and builds its own menus, so
    /// there is no guarantee a File ▸ Close item exists to route the shortcut.
    /// When none does, the key window gets its own crack at the equivalent —
    /// this is it.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let onCloseCommand,
           event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "w" {
            onCloseCommand()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    private static let escapeKeyCode: UInt16 = 53
}

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
    static func make() -> PreviewPanel {
        let panel = PreviewPanel(
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
        // Nothing here ever calls `close()` — `PreviewPanel.performClose` is
        // overridden and every other path uses `orderOut` — but `.closable`
        // plus a window AppKit could decide to close on its own is one
        // over-release away from a crash under ARC, since the controller
        // holds this panel strongly.
        panel.isReleasedWhenClosed = false
        // The window itself draws nothing — PreviewPanelShape, filled in
        // ItemPreviewView's background, is the only thing visible. Without
        // this, .titled's own opaque background and corner mask would sit
        // behind (and inside) the beak, defeating the point of drawing it.
        // Grouped into `applyAppearance` because Task 5's detach mutates
        // `styleMask` on the live panel, and AppKit is documented to rebuild
        // the window's frame view for some style changes — everything that
        // survives only because we set it has to be settable again.
        applyAppearance(to: panel)
        // Lets the user drag the window from anywhere the SwiftUI tree
        // didn't claim the click. On its own this is not enough to satisfy
        // "drag by the header or an empty part of the body" — see
        // `ItemPreviewView.windowDragSurface` for what actually carries the
        // gesture and why. Kept as the fallback underneath it.
        panel.isMovableByWindowBackground = true
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
        return panel
    }

    /// Everything about the panel that is pure appearance, in one place so
    /// `PreviewPanelController.detachAnchored()` can re-apply it after it
    /// changes `styleMask`.
    ///
    /// `NSWindow.styleMask` is documented as settable after creation, with
    /// the caveat that "some styleMask changes will cause the view hierarchy
    /// to be rebuilt". The detach only drops `.nonactivatingPanel` and keeps
    /// `.titled`, so the frame view's class doesn't change — but a rebuilt
    /// titlebar bringing back the standard buttons and an opaque background
    /// is a cheap thing to guard against and an expensive one to discover on
    /// screen.
    static func applyAppearance(to panel: NSPanel) {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // The system shadow is what gives the panel its elevation, and it is
        // the *only* thing that can: a SwiftUI `.shadow` inside the window has
        // nowhere to render, because the window frame is exactly the shape's
        // bounding box (`windowSize` == body + beak strip, no margin) and
        // `ItemPreviewView`'s `.clipShape` clips the composite — background and
        // shadow alike — to that same outline. See `ItemPreviewView.body`.
        //
        // Task 1 set this to `false` on the assumption that the system shadow
        // follows the window's *rectangle*, which on a transparent window
        // would ring the empty region beside the beak. That assumption was
        // never checked against a running app, and it does not hold: with
        // `isOpaque = false` and a clear `backgroundColor`, AppKit derives the
        // shadow from the alpha channel of the rendered content, so it hugs
        // whatever `PreviewPanelShape` drew — beak included. The drawer proves
        // it in production: `OverlayPanel` is the same configuration, and
        // `OverlayView` clips itself to a rounded rect and then insets it 8pt
        // from every window edge (`OverlayView.swift`, `.clipShape` then
        // `.padding(8)`). Its shadow follows those rounded corners; a
        // rectangle-derived shadow would instead run square-cornered across
        // the full width of the screen, 8pt out from the visible body.
        //
        // The catch is staleness, not shape: AppKit does not re-derive the
        // shadow when content alpha changes underneath a window that stays the
        // same size, so every place that changes the drawn outline has to say
        // so — see `invalidateShadow()`'s three call sites in
        // `PreviewPanelController`.
        panel.hasShadow = true
        // ItemPreviewView draws its own header (close button, type label,
        // footnote) — a native titlebar on top of that would just duplicate
        // it, so it's hidden. Purely cosmetic: none of this touches the
        // key/activation behaviour validated in `make()`.
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
    }
}
