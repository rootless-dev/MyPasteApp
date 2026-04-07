//
//  OverlayWindowController.swift
//  MyPasteApp
//

import AppKit
import SwiftData
import SwiftUI

@MainActor
final class OverlayWindowController {
    private var window: NSPanel?
    private let modelContainer: ModelContainer
    private let onPick: (ClipboardItem) -> Void

    init(modelContainer: ModelContainer, onPick: @escaping (ClipboardItem) -> Void) {
        self.modelContainer = modelContainer
        self.onPick = onPick
    }

    func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard let screen = NSScreen.main else { return }
        let height: CGFloat = 320
        let frame = NSRect(
            x: screen.frame.minX,
            y: screen.visibleFrame.minY,
            width: screen.frame.width,
            height: height
        )

        let panel: NSPanel
        if let existing = window {
            panel = existing
            panel.setFrame(frame, display: false)
        } else {
            panel = NSPanel(
                contentRect: frame,
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

            let root = OverlayView(
                onPick: { [weak self] item in
                    self?.onPick(item)
                    self?.hide()
                },
                onDismiss: { [weak self] in self?.hide() }
            )
            .modelContainer(modelContainer)

            let host = NSHostingView(rootView: root)
            host.frame = panel.contentView?.bounds ?? frame
            host.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
            panel.contentView = host
            window = panel
        }

        // Slide-up animation: começa abaixo da tela
        var startFrame = frame
        startFrame.origin.y -= height
        panel.setFrame(startFrame, display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(frame, display: true)
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel = window, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }
}
