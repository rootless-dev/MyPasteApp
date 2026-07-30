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
    private let onPick: (ClipboardItem) -> Void
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var previousApp: NSRunningApplication?

    init(modelContainer: ModelContainer, onPick: @escaping (ClipboardItem) -> Void) {
        self.modelContainer = modelContainer
        self.onPick = onPick
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
            onPick: { [weak self] item in
                guard let self else { return }
                self.onPick(item)
                let target = self.previousApp
                // Not `hide()`: its fade runs for 0.18s and only orders the
                // panel out at the end, while the synthetic ⌘V is posted after
                // `pasteDelayMs` (50ms by default). The panel would still be
                // key and would receive the paste itself — the text landing in
                // the search field instead of the target app.
                self.hideImmediately()
                let autoPaste = UserDefaults.standard.object(forKey: "autoPasteEnabled") as? Bool ?? true
                if autoPaste {
                    let delayMs = UserDefaults.standard.object(forKey: "pasteDelayMs") as? Int ?? 50
                    PasteSimulator.paste(activating: target, delay: Double(delayMs) / 1000.0)
                }
            },
            onDismiss: { [weak self] in self?.hide() }
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
        hostLayer.removeAnimation(forKey: "slideUp")
        hostLayer.removeAnimation(forKey: "fadeIn")
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
        guard let panel = window, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
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
        guard let panel = window, panel.isVisible else { return }
        panel.alphaValue = 0
        panel.orderOut(nil)
    }

    private func installClickOutsideMonitors() {
        removeClickOutsideMonitors()
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self else { return event }
            if event.window !== self.window {
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
