//
//  PasteSimulator.swift
//  MyPasteApp
//

import AppKit
import ApplicationServices
import Foundation

@MainActor
enum PasteSimulator {
    private static let vKeyCode: CGKeyCode = 9

    static func paste(activating app: NSRunningApplication?) {
        ensureAccessibilityPermission()

        if let app {
            if #available(macOS 14.0, *) {
                app.activate()
            } else {
                app.activate(options: [])
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            postCommandV()
        }
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)

        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        else { return }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
    }

    private static func ensureAccessibilityPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}
