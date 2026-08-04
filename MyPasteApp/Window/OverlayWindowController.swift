//
//  OverlayWindowController.swift
//  MyPasteApp
//

import AppKit
import SwiftData
import SwiftUI

@MainActor
final class OverlayWindowController: NSObject, NSWindowDelegate {
    private var window: NSPanel?
    private let modelContainer: ModelContainer
    private let writer: ClipboardWriter
    private let onPick: (ClipboardItem, Bool) -> Void
    private let onPickMultiple: ([ClipboardItem], Bool) -> Void
    private let itemEditor: ItemEditorWindowController
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var previousApp: NSRunningApplication?
    /// The overlay's search, owned here rather than by `OverlayView`.
    ///
    /// `prepare()` builds one `OverlayView` for the life of the process, so
    /// anything the view held in `@State` would survive the drawer closing:
    /// dismissing with the field open (⌘F then Escape) or pasting mid-query
    /// would bring the next opening back mid-search instead of at rest. Held
    /// here, `show()` can reset it on every opening — the one place that
    /// covers Escape, paste and click-outside alike.
    private let searchState = SearchState()
    /// Owned here, not by `OverlayView`, for the same reason `searchState` is:
    /// the overlay is built once and reused for the life of the process.
    private let markedSelection = MarkedSelection()
    /// Owned here, not by the view, and reset on every opening — the same rule
    /// as `searchState` and `markedSelection`. Reopening the drawer inside a
    /// pinboard would mean copying something and not seeing it appear, which
    /// is the invisible-state failure the roadmap treats as the worst kind.
    /// It also holds the inline rename (`renamingBoardID`), so that too is
    /// covered by the single `reset()` below instead of a parallel path.
    private let pinboardScope = PinboardScope()
    // Task 19 spike: a second window of our own, so the click-outside
    // monitors below need to know about it too. See ItemPreviewPanel.
    private var previewPanel: NSPanel?
    /// The item the preview panel would show right now, and where it sits
    /// on screen — kept up to date by `OverlayView.onPreviewSelectionChange`
    /// on every selection or layout change, whether or not the panel is
    /// actually open. See `updatePreviewSelection(item:anchor:)`.
    private var previewItem: ClipboardItem?
    private var previewAnchorFrame: CGRect?
    /// The id of the item whose content is currently loaded into the preview
    /// panel's `contentView`, or nil when nothing has been built yet.
    ///
    /// Guards `applyPreviewContent` against rebuilding on every card-frame
    /// change `updatePreviewSelection` reports — scrolling the card strip
    /// reports a new frame for the selected card on every animation tick,
    /// and rebuilding on each one threw away the panel's own scroll position
    /// and text selection, and allocated a fresh `NSHostingView` per frame.
    /// The item's own content still updates live when it changes underneath
    /// an unchanged id: `ClipboardItem` is a SwiftData `@Model`, so the
    /// already-hosted `ItemPreviewView` observes its properties on its own.
    private var previewDisplayedItemID: UUID?

    init(modelContainer: ModelContainer,
         writer: ClipboardWriter,
         itemEditor: ItemEditorWindowController,
         onPick: @escaping (ClipboardItem, Bool) -> Void,
         onPickMultiple: @escaping ([ClipboardItem], Bool) -> Void) {
        self.modelContainer = modelContainer
        self.writer = writer
        self.itemEditor = itemEditor
        self.onPick = onPick
        self.onPickMultiple = onPickMultiple
        super.init()
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    private static let overlayHeight: CGFloat = 320

    /// Creates the `NSPanel` and performs SwiftUI's initial layout up front,
    /// so the first hotkey invocation doesn't pay the layout cost during the
    /// open animation. Idempotent.
    func prepare() {
        guard window == nil else { return }
        let height = Self.overlayHeight
        let initial = NSRect(x: 0, y: 0, width: 800, height: height)

        // OverlayPanel, not NSPanel: a plain borderless panel can't become key,
        // so `makeKey()` below would be a no-op and the overlay would never
        // receive a keystroke. See OverlayPanel for the full explanation.
        let panel = OverlayPanel(
            contentRect: initial,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.alphaValue = 0
        panel.sharingType = WindowPrivacy.sharingType()

        let root = OverlayView(
            writer: writer,
            itemEditor: itemEditor,
            search: searchState,
            marked: markedSelection,
            scope: pinboardScope,
            onPick: { [weak self] item, plainText in
                guard let self else { return }
                self.onPick(item, plainText)
                self.dismissAndPaste()
            },
            onPickMultiple: { [weak self] items, plainText in
                guard let self else { return }
                self.onPickMultiple(items, plainText)
                self.dismissAndPaste()
            },
            onDismiss: { [weak self] in self?.hide() },
            destinationAppName: { [weak self] in self?.previousApp?.localizedName },
            onPreviewSelectionChange: { [weak self] item, anchor in
                self?.updatePreviewSelection(item: item, anchor: anchor)
            },
            onShowPreview: { [weak self] in self?.showPreviewPanel() },
            onHidePreview: { [weak self] in self?.hidePreviewPanel() },
            isPreviewOpen: { [weak self] in self?.previewPanel?.isVisible == true }
        )
        .modelContainer(modelContainer)

        let host = NSHostingView(rootView: root)
        host.frame = panel.contentView?.bounds ?? initial
        host.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
        host.wantsLayer = true
        panel.contentView = host
        // Force the initial layout now, outside the hotkey hot path.
        host.layoutSubtreeIfNeeded()
        window = panel

        // "Real" pre-warm: briefly show the panel off-screen and order it out
        // on the next runloop. This forces SwiftUI to run onAppear and the
        // preview loaders once at startup, so the first real animation
        // doesn't have to compete with that async work.
        let warmupFrame = NSRect(x: -10_000, y: -10_000, width: 800, height: height)
        panel.setFrame(warmupFrame, display: false)
        panel.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        DispatchQueue.main.async {
            panel.orderOut(nil)
        }
    }

    /// Re-reads the screen-sharing preference and applies it. The panel is
    /// private, so the AppDelegate can't do this itself.
    func applySharingPolicy() {
        window?.sharingType = WindowPrivacy.sharingType()
        previewPanel?.sharingType = WindowPrivacy.sharingType()
    }

    func show() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = frontmost
        }
        guard let screen = targetScreen(for: frontmost) else { return }
        prepare()
        applySharingPolicy()
        guard let panel = window else { return }

        // Every opening starts at rest: magnifier, no query, no filters,
        // nothing marked, the history in view and no pill mid-rename. Done
        // before the panel is ordered front so the
        // collapsed top bar is already laid out by the
        // `layoutSubtreeIfNeeded()` below, and the slide-up never shows a
        // stale field. These two lines are the single place that covers all
        // three ways the drawer goes away — Escape, a paste
        // (`hideImmediately`) and a click outside — none of which run any
        // teardown inside `OverlayView`.
        searchState.close()
        markedSelection.clear()
        pinboardScope.reset()
        // Separate from `close()` on purpose: `close()` only changes anything
        // when there was a search to close, so it can't be what tells the view
        // to re-take the keyboard on an opening that follows an untouched one.
        // `openCount` changes every time, and `OverlayView` re-focuses the
        // card strip off it.
        searchState.markOpened()

        let height = Self.overlayHeight
        let frame = NSRect(
            x: screen.frame.minX,
            y: screen.visibleFrame.minY,
            width: screen.frame.width,
            height: height
        )

        // The window is placed DIRECTLY at its final frame (no window-level
        // slide). The slide-up is performed internally by translating the
        // contentView's layer. This prevents the animation from crossing
        // monitor boundaries in multi-display setups, which previously
        // caused the "teleport" glitch.
        panel.alphaValue = 0
        panel.setFrame(frame, display: false)
        panel.orderFrontRegardless()
        panel.makeKey()

        guard let hostLayer = panel.contentView?.layer else {
            panel.alphaValue = 1
            installClickOutsideMonitors()
            return
        }

        // Initial state: translated below the window itself.
        //
        // The closing pair is removed too, not just the opening one: `hide()`
        // adds them with `fillMode: .forwards`, so reopening the drawer while
        // it is still sliding out would leave the layer pinned off-screen and
        // transparent — an opening animation running on content nobody can
        // see.
        hostLayer.removeAnimation(forKey: "slideUp")
        hostLayer.removeAnimation(forKey: "fadeIn")
        hostLayer.removeAnimation(forKey: "slideDown")
        hostLayer.removeAnimation(forKey: "fadeOut")
        hostLayer.setAffineTransform(CGAffineTransform(translationX: 0, y: -height))
        panel.alphaValue = 1

        // Rasterization during the animation: Core Animation snapshots the
        // hierarchy as a bitmap once and just translates that snapshot each
        // frame, instead of recomposing the SwiftUI tree. We turn it off in
        // the completion block so sharpness isn't degraded while idle.
        hostLayer.shouldRasterize = true
        hostLayer.rasterizationScale = panel.backingScaleFactor
        // Make sure the content is already rendered BEFORE the animation
        // starts, so the first slide-up frame doesn't pay the layout/draw
        // cost of the SwiftUI tree.
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.contentView?.displayIfNeeded()
        hostLayer.displayIfNeeded()

        let slide = CASpringAnimation(keyPath: "transform")
        slide.fromValue = CATransform3DMakeTranslation(0, -height, 0)
        slide.toValue = CATransform3DIdentity
        slide.damping = 18
        slide.stiffness = 220
        slide.mass = 1
        slide.initialVelocity = 0
        slide.duration = slide.settlingDuration
        slide.fillMode = .forwards
        slide.isRemovedOnCompletion = false

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.18
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            hostLayer.setAffineTransform(.identity)
            hostLayer.opacity = 1
            hostLayer.shouldRasterize = false
            hostLayer.removeAnimation(forKey: "slideUp")
            hostLayer.removeAnimation(forKey: "fadeIn")
        }
        hostLayer.add(slide, forKey: "slideUp")
        hostLayer.add(fade, forKey: "fadeIn")
        CATransaction.commit()

        installClickOutsideMonitors()
    }

    func hide() {
        removeClickOutsideMonitors()
        // Spike rule for Step 3: a click outside both windows closes both.
        // Unconditional (not gated on the overlay's own visibility) so this
        // also covers the "preview open, overlay already gone" edge case.
        hidePreviewPanel()
        guard let panel = window, panel.isVisible else { return }

        // The drawer leaves the way it arrived: by translating the content
        // view's layer, never the window. `show()` explains why — a
        // window-level slide crosses monitor boundaries in multi-display
        // setups and produces a "teleport" glitch. The window stays put at
        // its final frame and the content slides out of it.
        guard let hostLayer = panel.contentView?.layer else {
            panel.alphaValue = 0
            panel.orderOut(nil)
            return
        }

        let height = Self.overlayHeight

        // Any in-flight opening animation has to go first, or its
        // `fillMode: .forwards` end state fights this one.
        hostLayer.removeAnimation(forKey: "slideUp")
        hostLayer.removeAnimation(forKey: "fadeIn")

        hostLayer.shouldRasterize = true
        hostLayer.rasterizationScale = panel.backingScaleFactor

        // Ease-in, not the spring `show()` uses: a spring overshoots, and
        // overshooting on the way out reads as the drawer bouncing off the
        // bottom of the screen rather than leaving.
        let slide = CABasicAnimation(keyPath: "transform")
        slide.fromValue = CATransform3DIdentity
        slide.toValue = CATransform3DMakeTranslation(0, -height, 0)
        slide.duration = 0.18
        slide.timingFunction = CAMediaTimingFunction(name: .easeIn)
        slide.fillMode = .forwards
        slide.isRemovedOnCompletion = false

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.18
        fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            panel.orderOut(nil)
            // Back to the resting state the next `show()` expects to find.
            // `show()` sets both itself, but leaving the layer parked
            // off-screen and transparent would show an empty drawer for one
            // frame if anything ever ordered the panel front without it.
            hostLayer.removeAnimation(forKey: "slideDown")
            hostLayer.removeAnimation(forKey: "fadeOut")
            hostLayer.setAffineTransform(.identity)
            hostLayer.opacity = 1
            hostLayer.shouldRasterize = false
        }
        hostLayer.add(slide, forKey: "slideDown")
        hostLayer.add(fade, forKey: "fadeOut")
        CATransaction.commit()
    }

    /// Hides without the fade, for when an item was picked.
    ///
    /// Ordering the panel out is the only reliable way to make it stop being
    /// the key window, and that has to happen *before* the synthetic ⌘V is
    /// posted — otherwise the overlay receives its own paste. The missing fade
    /// costs nothing here: the user's attention has already moved to the app
    /// the text is landing in.
    func hideImmediately() {
        removeClickOutsideMonitors()
        hidePreviewPanel()
        guard let panel = window, panel.isVisible else { return }
        // Cancel any slide in flight and put the layer back at rest. Without
        // this, picking an item while the drawer is mid-animation would leave
        // a `fillMode: .forwards` end state parked on the layer for the next
        // opening to fight.
        if let hostLayer = panel.contentView?.layer {
            hostLayer.removeAnimation(forKey: "slideUp")
            hostLayer.removeAnimation(forKey: "fadeIn")
            hostLayer.removeAnimation(forKey: "slideDown")
            hostLayer.removeAnimation(forKey: "fadeOut")
            hostLayer.setAffineTransform(.identity)
            hostLayer.opacity = 1
            hostLayer.shouldRasterize = false
        }
        panel.alphaValue = 0
        panel.orderOut(nil)
    }

    /// Everything that happens after a pick, single or multiple: get the panel
    /// out of the way, then post the synthetic ⌘V if auto-paste is on.
    ///
    /// Shared by `onPick` and `onPickMultiple`, which do not diverge here by
    /// so much as a line — unlike `ClipboardWriter.write` and `writeJoined`,
    /// which stay separate precisely because they *do* diverge on what they
    /// save.
    ///
    /// Not `hide()`: its fade runs for 0.18s and only orders the panel out at
    /// the end, while the synthetic ⌘V is posted after `pasteDelayMs` (50ms by
    /// default). The panel would still be key and would receive the paste
    /// itself — the text landing in the search field instead of the target
    /// app.
    private func dismissAndPaste() {
        let target = previousApp
        hideImmediately()
        let autoPaste = UserDefaults.standard.object(forKey: PreferenceKeys.autoPasteEnabled) as? Bool ?? true
        guard autoPaste else { return }
        let delayMs = UserDefaults.standard.object(forKey: PreferenceKeys.pasteDelayMs) as? Int ?? 50
        PasteSimulator.paste(activating: target, delay: Double(delayMs) / 1000.0)
    }

    private func installClickOutsideMonitors() {
        removeClickOutsideMonitors()
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self else { return event }
            // The preview panel is ours too: a click inside it must not read
            // as a click outside the overlay.
            if event.window !== self.window && event.window !== self.previewPanel {
                self.hide()
            }
            return event
        }
    }

    /// Shows the preview panel with whatever `previewItem` currently holds.
    ///
    /// A no-op when there's nothing selected to show (e.g. the history is
    /// empty) — there's nothing meaningful to open the panel onto. Reused by
    /// both `␣` and `onShowPreview` (the "Preview" context menu entry), which
    /// is why it never closes the panel itself: that decision belongs to the
    /// caller.
    private func showPreviewPanel() {
        guard let item = previewItem else { return }
        let panel = previewPanel ?? ItemPreviewPanel.make()
        previewPanel = panel
        panel.sharingType = WindowPrivacy.sharingType()
        // Reopening on the same item the panel already had loaded (e.g. ␣ was
        // pressed again after Escape closed it) doesn't need a rebuild — see
        // `previewDisplayedItemID`.
        if previewDisplayedItemID != item.id {
            applyPreviewContent(to: panel, item: item)
        }
        positionPreviewPanel(panel)
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
    /// next open rebuild the content — `showPreviewPanel()` skips the rebuild
    /// when the id already matches.
    private func hidePreviewPanel() {
        guard let panel = previewPanel else { return }
        panel.orderOut(nil)
        panel.contentView = NSView(
            frame: NSRect(origin: .zero, size: ItemPreviewPanel.windowSize)
        )
        previewDisplayedItemID = nil
    }

    /// Keeps the preview panel in sync with the overlay's selection.
    ///
    /// Called on every selection or layout change reported by `OverlayView`,
    /// whether or not the panel is currently open — see the doc comment on
    /// `previewItem`. Only rebuilds/repositions the visible panel; while it's
    /// closed, this just records the latest values so the next `show`
    /// reflects whatever is selected right now, with no stale first frame.
    private func updatePreviewSelection(item: ClipboardItem?, anchor: CGRect?) {
        previewItem = item
        previewAnchorFrame = anchor
        guard let panel = previewPanel, panel.isVisible else { return }
        guard let item else {
            // Nothing left to preview (e.g. the last item was deleted, or a
            // search filtered everything out) — closing is the least
            // surprising option, matching what happens when the overlay
            // itself runs out of cards to select.
            hidePreviewPanel()
            return
        }
        // Only rebuild the panel's content when the selection actually
        // changed. This fires on every card-frame update too — scrolling the
        // strip alone would otherwise tear down and rebuild the panel's
        // content on every animation frame, losing the user's scroll
        // position and text selection inside it. Repositioning stays
        // unconditional below: the panel must keep tracking the card as it
        // moves regardless of whether its content changed.
        if previewDisplayedItemID != item.id {
            applyPreviewContent(to: panel, item: item)
        }
        positionPreviewPanel(panel)
    }

    /// Builds `ItemPreviewView` for `item` and assigns it as the panel's
    /// content.
    ///
    /// The one place in this file that hands a hosting view to
    /// `contentView` — see the comment on `ItemPreviewPanel.make()` for why
    /// the explicit `frame`/`autoresizingMask` here matters: without them,
    /// the window would be resized to the content's intrinsic size instead
    /// of the frame `positionPreviewPanel(_:)` sets, the same bug the Task 19
    /// spike ran into.
    private func applyPreviewContent(to panel: NSPanel, item: ClipboardItem) {
        let host = NSHostingView(rootView: ItemPreviewView(
            item: item,
            onClose: { [weak self] in self?.hidePreviewPanel() },
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
    /// it.
    ///
    /// `previewAnchorFrame` arrives from `OverlayView` in the `.global`
    /// coordinate space of its SwiftUI tree, which — since `OverlayView` is
    /// the direct `rootView` of the overlay's own `NSHostingView` (see
    /// `prepare()`) — is equivalent to that hosting view's bounds.
    /// `NSView.convert(_:to:)` turns that into window coordinates (handling
    /// the flip from SwiftUI's top-left origin automatically), and
    /// `convertToScreen` turns those into what `setFrame` needs. Falls back
    /// to centering on screen when there's no anchor yet (the panel was
    /// asked to open before any card reported its frame) or no overlay
    /// window to convert against.
    ///
    /// Deliberately does not draw a pointer/beak connecting the panel to the
    /// card (design-refs/03-preview-web.png) — see the Task 20 report.
    private func positionPreviewPanel(_ panel: NSPanel) {
        let size = ItemPreviewPanel.windowSize
        guard let screen = window?.screen ?? NSScreen.main else { return }
        guard let anchor = previewAnchorFrame,
              let overlayWindow = window,
              let contentView = overlayWindow.contentView else {
            let centered = NSRect(
                x: screen.frame.midX - size.width / 2,
                y: screen.frame.midY - size.height / 2,
                width: size.width,
                height: size.height
            )
            panel.setFrame(centered, display: false)
            return
        }
        let windowRect = contentView.convert(anchor, to: nil)
        let screenRect = overlayWindow.convertToScreen(windowRect)

        let margin: CGFloat = 12
        let edgeInset: CGFloat = 8
        var x = screenRect.midX - size.width / 2
        var y = screenRect.maxY + margin

        x = max(screen.visibleFrame.minX + edgeInset,
                min(x, screen.visibleFrame.maxX - size.width - edgeInset))
        if y + size.height > screen.visibleFrame.maxY - edgeInset {
            y = screen.visibleFrame.maxY - size.height - edgeInset
        }
        if y < screen.visibleFrame.minY + edgeInset {
            y = screen.visibleFrame.minY + edgeInset
        }

        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: false)
    }

    /// Resolves which `NSScreen` the overlay should appear on.
    ///
    /// Strategy (in order):
    /// 1. Screen containing the frontmost window of the previously focused
    ///    app (discovered via `CGWindowListCopyWindowInfo`, no Accessibility
    ///    permission required).
    /// 2. Screen containing the mouse cursor — used when the frontmost app
    ///    has no visible windows (e.g. Finder showing only the desktop).
    /// 3. `NSScreen.main` as a last resort.
    private func targetScreen(for frontmost: NSRunningApplication?) -> NSScreen? {
        if let app = frontmost,
           app.bundleIdentifier != Bundle.main.bundleIdentifier,
           let screen = screenForFrontmostWindow(pid: app.processIdentifier) {
            return screen
        }
        if let screen = screenContainingMouse() {
            return screen
        }
        return NSScreen.main
    }

    private func screenForFrontmostWindow(pid: pid_t) -> NSScreen? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        // The list is ordered from frontmost to backmost. We pick the first
        // "normal" window (layer 0) that belongs to the process.
        for info in infoList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t, ownerPID == pid else { continue }
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let cgBounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
            // CGWindow uses top-left origin on the primary display; AppKit
            // uses bottom-left. Convert by taking the center in AppKit
            // coordinates.
            guard let primary = NSScreen.screens.first else { continue }
            let primaryHeight = primary.frame.height
            let centerCG = CGPoint(x: cgBounds.midX, y: cgBounds.midY)
            let centerAppKit = CGPoint(x: centerCG.x, y: primaryHeight - centerCG.y)
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(centerAppKit) }) {
                return screen
            }
        }
        return nil
    }

    private func screenContainingMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) }
    }

    private func removeClickOutsideMonitors() {
        if let m = globalMouseMonitor {
            NSEvent.removeMonitor(m)
            globalMouseMonitor = nil
        }
        if let m = localMouseMonitor {
            NSEvent.removeMonitor(m)
            localMouseMonitor = nil
        }
    }
}
