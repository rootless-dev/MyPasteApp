//
//  HotkeyRecorderView.swift
//  MyPasteApp
//
//  SwiftUI wrapper around an NSView that captures a single key combination.
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var combo: KeyCombo

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.combo = combo
        view.onChange = { newValue in
            combo = newValue
        }
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.combo = combo
        nsView.refreshTitle()
    }

    final class RecorderNSView: NSView {
        var combo: KeyCombo = .default
        var onChange: ((KeyCombo) -> Void)?
        private var isRecording = false
        private let label = NSTextField(labelWithString: "")

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.cornerRadius = 6
            layer?.borderWidth = 1
            layer?.borderColor = NSColor.separatorColor.cgColor
            label.alignment = .center
            label.font = .systemFont(ofSize: NSFont.systemFontSize)
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: centerXAnchor),
                label.centerYAnchor.constraint(equalTo: centerYAnchor),
                widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
                heightAnchor.constraint(equalToConstant: 24),
            ])
            refreshTitle()
        }

        required init?(coder: NSCoder) { fatalError() }

        override var acceptsFirstResponder: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            isRecording = true
            refreshTitle()
        }

        override func becomeFirstResponder() -> Bool {
            let ok = super.becomeFirstResponder()
            if ok {
                isRecording = true
                refreshTitle()
            }
            return ok
        }

        override func resignFirstResponder() -> Bool {
            isRecording = false
            refreshTitle()
            return super.resignFirstResponder()
        }

        override func keyDown(with event: NSEvent) {
            guard isRecording else { return super.keyDown(with: event) }
            // Cancel on Escape with no modifiers
            if event.keyCode == kVK_Escape && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                isRecording = false
                window?.makeFirstResponder(nil)
                refreshTitle()
                return
            }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // Require at least one modifier to avoid trapping plain letters.
            let hasMod = flags.contains(.command) || flags.contains(.option)
                || flags.contains(.control) || flags.contains(.shift)
            guard hasMod else {
                NSSound.beep()
                return
            }
            let newCombo = KeyCombo(nsKeyCode: event.keyCode, nsFlags: flags)
            combo = newCombo
            onChange?(newCombo)
            isRecording = false
            window?.makeFirstResponder(nil)
            refreshTitle()
        }

        func refreshTitle() {
            if isRecording {
                label.stringValue = "Type shortcut…"
                label.textColor = .secondaryLabelColor
                layer?.borderColor = NSColor.controlAccentColor.cgColor
            } else {
                label.stringValue = combo.displayString
                label.textColor = .labelColor
                layer?.borderColor = NSColor.separatorColor.cgColor
            }
        }
    }
}
