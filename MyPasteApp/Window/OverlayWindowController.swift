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
    // Task 3 (Fase 6.5): its management moved into PreviewPanelController;
    // this window controller only reaches it through that type now.
    private let previewController: PreviewPanelController

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
        self.previewController = PreviewPanelController(
            modelContainer: modelContainer,
            writer: writer,
            itemEditor: itemEditor
        )
        super.init()
        // Dragging the preview panel off the drawer closes the drawer behind
        // it. The controller doesn't know the drawer exists; this closure is
        // the whole of what it knows. Safe against the obvious re-entrancy
        // worry — `hide()` calls `hideAnchored()`, but by the time this runs
        // the panel has already left the anchored slot, which is exactly the
        // ordering `detachAnchored()` is written around.
        previewController.onDetach = { [weak self] in self?.hide() }
    }

    /// Losing key status closes the drawer. This is what makes ⌘-Tab, the
    /// Dock, and anything else that moves the keyboard elsewhere dismiss it —
    /// a separate mechanism from `installClickOutsideMonitors()`, and the one
    /// that actually fires first on most dismissals.
    ///
    /// **Why the hide is deferred by one runloop turn.** A *detached* preview
    /// panel is deliberately key-capable: `PreviewPanelController
    /// .detachAnchored()` drops `.nonactivatingPanel` and
    /// `becomesKeyOnlyIfNeeded` so ⌘C, ⌘W and Escape reach it. Clicking one
    /// therefore takes key status away from the drawer — and unguarded, that
    /// click slid the drawer shut *and* ordered out and gutted the anchored
    /// preview with it (`hide()` calls `hideAnchored()` unconditionally):
    /// detach a panel, reopen the drawer, press `␣`, click the detached panel,
    /// and everything closed. `owns(_:)` is the test that says "this window is
    /// one of ours"; it was wired into the click-outside monitor only, while
    /// key status is the layer that actually does the closing.
    ///
    /// The check cannot be made here and now: at resign time the outgoing
    /// window has already dropped key status and the incoming one has not yet
    /// taken it, so `NSApp.keyWindow` is `nil` inside this callback no matter
    /// who is about to become key. One turn later it answers. Nothing else in
    /// AppKit reports the incoming window synchronously — `NSApp.currentEvent`
    /// looks like it would, but it also holds a *stale* event when the resign
    /// wasn't caused by one (⌘-Tab delivers no event to this app), and a stale
    /// click inside a detached panel would then keep the drawer open forever.
    ///
    /// The two guards, in order:
    ///
    /// 1. `isKeyWindow` — anything that re-showed the drawer inside the turn
    ///    made it key again (`show()` ends in `makeKey()`), and a hide queued
    ///    before that opening must not close it.
    /// 2. `owns(_:)` — the incoming key window is the anchored panel or a
    ///    detached one, so nothing closes. Note `owns(nil)` is false by
    ///    construction (see its doc comment): with `NSApp.keyWindow` nil —
    ///    which is exactly what ⌘-Tab leaves behind — a true answer here would
    ///    mean the drawer never closes again.
    ///
    /// The deferral itself is safe against the paths that hide the drawer
    /// synchronously: `hideImmediately()` orders the panel out (posting this
    /// very notification) before the synthetic ⌘V, and the queued `hide()`
    /// finds `panel.isVisible == false` and returns without touching the
    /// layer, well before the 50ms paste delay elapses.
    func windowDidResignKey(_ notification: Notification) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard self.window?.isKeyWindow != true else { return }
            guard !self.previewController.owns(NSApp.keyWindow) else { return }
            self.hide()
        }
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
                self?.previewController.updateSelection(item: item, anchor: anchor)
            },
            onShowPreview: { [weak self] in self?.previewController.showAnchored() },
            onHidePreview: { [weak self] in self?.previewController.hideAnchored() },
            isPreviewOpen: { [weak self] in self?.previewController.isAnchoredOpen == true }
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
        previewController.overlayWindow = panel

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
        previewController.refreshPrivacy()
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
        previewController.hideAnchored()
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
        previewController.hideAnchored()
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
            if event.window !== self.window && !self.previewController.owns(event.window) {
                self.hide()
            }
            return event
        }
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
