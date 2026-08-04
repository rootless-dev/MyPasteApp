//
//  PreviewPanelController.swift
//  MyPasteApp
//
//  Owns the preview panel's life cycle: showing and hiding it, keeping it in
//  sync with the overlay's selection, and positioning it above the selected
//  card. Extracted from `OverlayWindowController` (Task 3 of the Fase 6.5
//  plan) as a pure move — nothing about how the panel behaves changed here.
//  Later tasks give it a detached mode and allow several panels at once,
//  which is why it earns its own type.
//

import AppKit
import SwiftData
import SwiftUI

@MainActor
final class PreviewPanelController: NSObject, NSWindowDelegate {
    private let modelContainer: ModelContainer
    private let writer: ClipboardWriter
    private let itemEditor: ItemEditorWindowController

    // Task 19 spike: a second window of our own, so the click-outside
    // monitors in OverlayWindowController need to know about it too. See
    // ItemPreviewPanel.
    private var previewPanel: PreviewPanel?
    /// The one `PreviewChrome` for `previewPanel`, created alongside it in
    /// `showAnchored()` and never cleared afterwards — so whenever
    /// `previewPanel` is non-nil, this is too. Passed to `ItemPreviewView`
    /// once when the content is built, then mutated by
    /// `positionPreviewPanel(_:chrome:)` on every reposition; see
    /// `PreviewChrome`'s doc comment for why that indirection exists at all.
    private var previewChrome: PreviewChrome?
    /// The item the preview panel would show right now, and where it sits
    /// on screen — kept up to date by `OverlayView.onPreviewSelectionChange`
    /// on every selection or layout change, whether or not the panel is
    /// actually open. See `updateSelection(item:anchor:)`.
    private var previewItem: ClipboardItem?
    private var previewAnchorFrame: CGRect?
    /// The id of the item whose content is currently loaded into the preview
    /// panel's `contentView`, or nil when nothing has been built yet.
    ///
    /// Guards `applyPreviewContent` against rebuilding on every card-frame
    /// change `updateSelection` reports — scrolling the card strip reports a
    /// new frame for the selected card on every animation tick, and
    /// rebuilding on each one threw away the panel's own scroll position
    /// and text selection, and allocated a fresh `NSHostingView` per frame.
    /// The item's own content still updates live when it changes underneath
    /// an unchanged id: `ClipboardItem` is a SwiftData `@Model`, so the
    /// already-hosted `ItemPreviewView` observes its properties on its own.
    private var previewDisplayedItemID: UUID?

    /// The last frame `positionPreviewPanel(_:chrome:)` handed to the anchored
    /// panel, and so the frame a `windowDidMove` has to be measured against to
    /// tell "the user is dragging this" from "the strip scrolled and we moved
    /// it ourselves".
    ///
    /// A stored field rather than a fresh `PreviewPlacement.solve` inside the
    /// observer on purpose: the anchored panel is repositioned on every scroll
    /// tick, and recomputing from the anchor there would race the
    /// repositioning against the drag measurement. `nil` while no panel is
    /// anchored.
    private var lastAnchoredFrame: CGRect?

    /// A preview panel the user dragged off the drawer.
    ///
    /// The item travels with the panel because a detached panel is frozen on
    /// what it was showing: `previewItem` goes on tracking the drawer's
    /// selection, and this one deliberately stops following it.
    private struct DetachedPreview {
        let panel: PreviewPanel
        let chrome: PreviewChrome
        let item: ClipboardItem
    }

    /// Panels that have left the drawer. Each one is an independent window
    /// from here on; nothing in this file repositions or rebuilds them.
    private var detachedPreviews: [DetachedPreview] = []

    /// How far the anchored panel has to move before the move reads as the
    /// user dragging it rather than a stray pixel of jitter.
    private static let detachThreshold: CGFloat = 10

    /// Called once, at the moment the anchored panel becomes a detached one,
    /// so whoever owns the drawer can close it.
    ///
    /// A closure rather than a reference to `OverlayWindowController`: this
    /// controller has never known the drawer exists, and the ordering trap in
    /// `detachAnchored()` is much easier to hold onto when the drawer is one
    /// opaque call at the end instead of a collaborator with its own methods.
    var onDetach: (() -> Void)?

    /// The overlay window, needed to convert the card's frame to screen
    /// coordinates. Set by OverlayWindowController.prepare().
    var overlayWindow: NSPanel?

    init(modelContainer: ModelContainer, writer: ClipboardWriter, itemEditor: ItemEditorWindowController) {
        self.modelContainer = modelContainer
        self.writer = writer
        self.itemEditor = itemEditor
        super.init()
    }

    var isAnchoredOpen: Bool {
        previewPanel?.isVisible == true
    }

    func owns(_ window: NSWindow?) -> Bool {
        window === previewPanel
    }

    /// Re-reads the screen-sharing preference and applies it. The panel is
    /// private, so the AppDelegate can't do this itself.
    func refreshPrivacy() {
        previewPanel?.sharingType = WindowPrivacy.sharingType()
    }

    /// Shows the preview panel with whatever `previewItem` currently holds.
    ///
    /// A no-op when there's nothing selected to show (e.g. the history is
    /// empty) — there's nothing meaningful to open the panel onto. Reused by
    /// both `␣` and `onShowPreview` (the "Preview" context menu entry), which
    /// is why it never closes the panel itself: that decision belongs to the
    /// caller.
    func showAnchored() {
        guard let item = previewItem else { return }
        let panel = previewPanel ?? ItemPreviewPanel.make()
        previewPanel = panel
        // The delegate *is* the `NSWindow.didMoveNotification` observation the
        // plan calls for — AppKit registers the delegate for it. Cheaper than
        // a token to keep and cancel, and it fires synchronously on the drag,
        // which a `queue:`-based block observer would not.
        panel.delegate = self
        let chrome = previewChrome ?? PreviewChrome()
        previewChrome = chrome
        panel.sharingType = WindowPrivacy.sharingType()
        // Reopening on the same item the panel already had loaded (e.g. ␣ was
        // pressed again after Escape closed it) doesn't need a rebuild — see
        // `previewDisplayedItemID`.
        if previewDisplayedItemID != item.id {
            applyPreviewContent(to: panel, item: item, chrome: chrome)
        }
        positionPreviewPanel(panel, chrome: chrome)
        // orderFrontRegardless, not makeKeyAndOrderFront: the panel must
        // never take key status away from the overlay. See the brief's Step 3.
        panel.orderFrontRegardless()
    }

    /// Closes just the preview panel, leaving the overlay itself open.
    ///
    /// Used by Escape's "dismiss what's on top" rule (see
    /// `OverlayView.escapeClosesPreview`), by `ItemPreviewView`'s own close
    /// button, and by every other path that hides the panel — this is the only
    /// place that does it.
    ///
    /// Dropping `contentView` is not housekeeping: `orderOut` alone leaves the
    /// `NSHostingView` and every Core Animation layer behind it alive, and a
    /// long text preview measured 240 MB of CoreAnimation that never came back
    /// until the app quit. Clearing `previewDisplayedItemID` is what makes the
    /// next open rebuild the content — `showAnchored()` skips the rebuild
    /// when the id already matches.
    func hideAnchored() {
        guard let panel = previewPanel else { return }
        panel.orderOut(nil)
        panel.contentView = NSView(
            frame: NSRect(origin: .zero, size: ItemPreviewPanel.windowSize)
        )
        previewDisplayedItemID = nil
        // Nothing to measure a drag against while the panel is closed, and
        // leaving a stale frame here would make the first `didMove` of the
        // next opening look like a 500pt drag.
        lastAnchoredFrame = nil
    }

    // MARK: - Detaching

    /// Watches the anchored panel for the user dragging it.
    ///
    /// Every reposition this controller performs writes `lastAnchoredFrame`
    /// *before* calling `setFrame`, so the notification that reposition itself
    /// posts measures zero. Anything left over is the user.
    func windowDidMove(_ notification: Notification) {
        guard let panel = previewPanel,
              notification.object as? NSWindow === panel,
              let last = lastAnchoredFrame else { return }
        let moved = hypot(panel.frame.origin.x - last.origin.x,
                          panel.frame.origin.y - last.origin.y)
        guard moved >= Self.detachThreshold else { return }
        detachAnchored()
    }

    /// Turns the anchored panel into an independent window and closes the
    /// drawer behind it.
    ///
    /// **The order below is the whole point of this method.** `onDetach` is
    /// wired to `OverlayWindowController.hide()`, and `hide()` calls
    /// `hideAnchored()` unconditionally — so if the drawer were told to close
    /// while `previewPanel` still pointed at this panel, `hideAnchored()`
    /// would order out and gut the very window the user just dragged loose.
    /// The panel therefore leaves the anchored slot in step 1, and the drawer
    /// is only told anything in the last line.
    func detachAnchored() {
        guard let panel = previewPanel,
              let chrome = previewChrome,
              let item = previewItem else { return }

        // 1. Out of the anchored slot, into the detached list. First, for the
        //    reason spelled out above.
        previewPanel = nil
        previewChrome = nil
        lastAnchoredFrame = nil
        detachedPreviews.append(DetachedPreview(panel: panel, chrome: chrome, item: item))

        // 2. The view stops drawing a beak and starts filling the whole
        //    window — see `ItemPreviewView.body`.
        chrome.isDetached = true
        chrome.beakOffset = nil

        // 3. Shed the strip the beak occupied, keeping the top edge still —
        //    see `PreviewPlacement.detachedFrame`.
        panel.setFrame(PreviewPlacement.detachedFrame(from: panel.frame,
                                                      losing: ItemPreviewPanel.beakHeight),
                       display: true)

        // 4. Keyboard. `becomesKeyOnlyIfNeeded = false` alone is not enough:
        //    keystrokes go to the *active* app, and `.nonactivatingPanel`
        //    exists precisely so that a click here never activates this one.
        //    A panel that can become key but can never activate the app is a
        //    panel that receives keys only for as long as the app happens to
        //    already be active — ⌘C working right after the detach and
        //    silently dying the first time the user visits another app and
        //    comes back. Dropping the flag is what makes the keyboard stay.
        //    The *anchored* panel keeps both settings untouched: they are
        //    what stops it taking key status from the drawer, which is wired
        //    to close on `windowDidResignKey`.
        panel.becomesKeyOnlyIfNeeded = false
        panel.styleMask.remove(.nonactivatingPanel)
        ItemPreviewPanel.applyAppearance(to: panel)
        panel.onCloseCommand = { [weak self, weak panel] in
            guard let panel else { return }
            self?.closeDetached(panel)
        }

        // 5. `.transient` is right for a panel that dies with the drawer and
        //    wrong for one that outlives it — it would take this window away
        //    with the rest of the app in situations the user never asked for.
        //    `.canJoinAllSpaces` and `.fullScreenAuxiliary` stay.
        panel.collectionBehavior.remove(.transient)

        // 6. Stop watching for moves: a detached panel moves all the time, on
        //    purpose. (Step 1 already made `windowDidMove` a no-op for this
        //    panel; this is the explicit half.)
        panel.delegate = nil

        // 7. So the next `showAnchored()` builds fresh content instead of
        //    believing the item it wants is already loaded — the panel that
        //    had it loaded just left.
        previewDisplayedItemID = nil

        // 8. Only now: this closes the drawer.
        onDetach?()
    }

    /// Closes a detached panel.
    ///
    /// Deliberately minimal — Task 6 owns the detached panels' life cycle
    /// (items being deleted underneath them, `refreshPrivacy`, `owns(_:)`).
    /// This exists so `⌘W` and `Escape` have something to call.
    ///
    /// Dropping `contentView` for the same reason `hideAnchored()` does: the
    /// `NSHostingView` and every Core Animation layer behind it survive an
    /// `orderOut` on their own.
    private func closeDetached(_ panel: PreviewPanel) {
        guard let index = detachedPreviews.firstIndex(where: { $0.panel === panel }) else { return }
        detachedPreviews.remove(at: index)
        // Also breaks panel → closure → panel.
        panel.onCloseCommand = nil
        panel.orderOut(nil)
        panel.contentView = NSView()
    }

    /// Keeps the preview panel in sync with the overlay's selection.
    ///
    /// Called on every selection or layout change reported by `OverlayView`,
    /// whether or not the panel is currently open — see the doc comment on
    /// `previewItem`. Only rebuilds/repositions the visible panel; while it's
    /// closed, this just records the latest values so the next `show`
    /// reflects whatever is selected right now, with no stale first frame.
    func updateSelection(item: ClipboardItem?, anchor: CGRect?) {
        previewItem = item
        previewAnchorFrame = anchor
        guard let panel = previewPanel, panel.isVisible else { return }
        // previewChrome is created alongside previewPanel in showAnchored()
        // and never cleared, so panel existing guarantees this does too.
        guard let chrome = previewChrome else { return }
        guard let item else {
            // Nothing left to preview (e.g. the last item was deleted, or a
            // search filtered everything out) — closing is the least
            // surprising option, matching what happens when the overlay
            // itself runs out of cards to select.
            hideAnchored()
            return
        }
        // Only rebuild the panel's content when the selection actually
        // changed. This fires on every card-frame update too — scrolling the
        // strip alone would otherwise tear down and rebuild the panel's
        // content on every animation frame, losing the user's scroll
        // position and text selection inside it. Repositioning stays
        // unconditional below: the panel must keep tracking the card as it
        // moves regardless of whether its content changed, and the beak with
        // it — `positionPreviewPanel` is what writes the new `beakOffset`
        // into `chrome`.
        if previewDisplayedItemID != item.id {
            applyPreviewContent(to: panel, item: item, chrome: chrome)
        }
        positionPreviewPanel(panel, chrome: chrome)
    }

    /// Builds `ItemPreviewView` for `item` and assigns it as the panel's
    /// content.
    ///
    /// The one place in this file that hands a hosting view to
    /// `contentView` — see the comment on `ItemPreviewPanel.make()` for why
    /// the explicit `frame`/`autoresizingMask` here matters: without them,
    /// the window would be resized to the content's intrinsic size instead
    /// of the frame `positionPreviewPanel(_:chrome:)` sets, the same bug the
    /// Task 19 spike ran into.
    private func applyPreviewContent(to panel: NSPanel, item: ClipboardItem, chrome: PreviewChrome) {
        let host = NSHostingView(rootView: ItemPreviewView(
            item: item,
            chrome: chrome,
            onClose: { [weak self] in self?.hideAnchored() },
            onCopyColor: { [weak self] color in
                guard let self else { return }
                let text = color.formatted(as: .hex)
                // Files the item, exactly like the screen sampler and "Copy
                // Color as" do. The phase's design said this one should copy
                // *without* filing — the reasoning being that clicking
                // through several pixels would fill the history with items
                // nobody asked for. Using it proved the opposite: a colour
                // you went looking for inside an image is a colour you want
                // back, and having two of the three colour paths file while
                // the third silently didn't was impossible to explain.
                //
                // `ClipboardMonitor.file`, not a bare insert: sampling the
                // same colour twice promotes the item already in the history
                // rather than filing a duplicate — which is most of what the
                // original worry was about.
                ClipboardMonitor.file(ItemActions.makeCapturedItem(text: text),
                                      in: self.modelContainer.mainContext)
                self.writer.writeText(text, silently: true)
            },
            onEdit: { [weak self] in self?.itemEditor.open(item: item, focus: .label) }
        ))
        host.frame = NSRect(origin: .zero, size: ItemPreviewPanel.windowSize)
        host.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
        panel.contentView = host
        previewDisplayedItemID = item.id
    }

    /// Positions the panel above the selected card, horizontally centered on
    /// it, and points `chrome`'s beak at it.
    ///
    /// `previewAnchorFrame` arrives from `OverlayView` in the `.global`
    /// coordinate space of its SwiftUI tree, which — since `OverlayView` is
    /// the direct `rootView` of the overlay's own `NSHostingView` (see
    /// `OverlayWindowController.prepare()`) — is equivalent to that hosting
    /// view's bounds. `NSView.convert(_:to:)` turns that into window
    /// coordinates (handling the flip from SwiftUI's top-left origin
    /// automatically), and `convertToScreen` turns those into what
    /// `setFrame` needs. Falls back to centering on screen, beak-less, when
    /// there's no anchor yet (the panel was asked to open before any card
    /// reported its frame) or no overlay window to convert against.
    ///
    /// `PreviewPlacement.solve` returns `beakOffset` already measured from
    /// `result.frame`'s left edge — the same origin `PreviewPanelShape` draws
    /// against inside the panel's content — so it's written into `chrome`
    /// as-is, with no conversion. Drawing the beak itself, and hiding it near
    /// a screen edge or a rounded corner where it wouldn't legally point at
    /// the card (design-refs/03-preview-web.png), is `PreviewPlacement` and
    /// `PreviewPanelShape`'s job; this method only wires the two together.
    private func positionPreviewPanel(_ panel: NSPanel, chrome: PreviewChrome) {
        let size = ItemPreviewPanel.windowSize
        guard let screen = overlayWindow?.screen ?? NSScreen.main else { return }
        guard let anchor = previewAnchorFrame,
              let overlayWindow = overlayWindow,
              let contentView = overlayWindow.contentView else {
            let centered = NSRect(
                x: screen.frame.midX - size.width / 2,
                y: screen.frame.midY - size.height / 2,
                width: size.width,
                height: size.height
            )
            // Before `setFrame`, always: `setFrame` posts
            // `windowDidMove` synchronously, and `windowDidMove` compares
            // against this field. Written afterwards, a reposition that moved
            // the panel more than `detachThreshold` — every scroll tick of the
            // card strip, in other words — would read as the user dragging it
            // and detach the panel on its own.
            lastAnchoredFrame = centered
            panel.setFrame(centered, display: false)
            chrome.beakOffset = nil
            return
        }
        let windowRect = contentView.convert(anchor, to: nil)
        let screenRect = overlayWindow.convertToScreen(windowRect)

        let result = PreviewPlacement.solve(anchor: screenRect,
                                            panelSize: size,
                                            visibleFrame: screen.visibleFrame,
                                            cornerRadius: ItemPreviewPanel.cornerRadius,
                                            beakWidth: PreviewPlacement.beakWidth)

        // Before `setFrame` — see the comment on the fallback path above.
        lastAnchoredFrame = result.frame
        panel.setFrame(result.frame, display: false)
        chrome.beakOffset = result.beakOffset
    }
}
